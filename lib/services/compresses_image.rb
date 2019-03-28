# frozen_string_literal: true

require 'light-service'
require 'base64'
require 'letters'
require 'network_utils/url_info'
require 'active_support/core_ext/numeric/time'

require_relative '../config'
require_relative '../image_compressor'
require_relative '../../helpers/app_helper'

# Light Service Orchestrator which implements service business-logic steps
class CompressesImage
  extend LightService::Organizer

  # Default static LightService::Organizer call method
  #
  # @param [String] encrypted_uri original URI to decrypt
  # @param [RodaResponse] resp Roda response object
  #
  # @return [LightService::Context] context with the result properties and status
  def self.call(encrypted_uri, resp)
    with(encrypted_uri: encrypted_uri, resp: resp).reduce(actions)
  end

  # Default static LightService::Organizer actions list
  #
  # @return [Array<LightService::Action> actions list in order
  def self.actions
    [
      DecryptsUrlAction,
      ValidatesUrlAction,
      CompressesImageAction,
      PreparesHeadersAction,
      SendsResponseAction
    ]
  end
end

# Light Service Action to decrypt incoming URL
class DecryptsUrlAction
  extend AppHelper
  extend LightService::Action

  expects  :encrypted_uri
  promises :original_uri

  executed do |ctx|
    begin
      # Validate base64 integrity as the first protection level
      encrypted_uri = ctx[:encrypted_uri].sub(/\.[^\.]*$/, '')
      Base64.urlsafe_decode64(encrypted_uri)

      Config.il.l(binding, :encrypted_uri, aggregate: true)

      # Decrypt original URI to validate resource headers
      ctx[:original_uri] = original_uri(encrypted_uri)
    rescue ArgumentError, OpenSSL::Cipher::CipherError, URI::InvalidURIError, ThreadError => e
      ctx.fail!

      Config.il.f!
      Config.il.l(binding, :origin_error)
    end
  end
end

# Light Service Action to validate decrypted original image URL
class ValidatesUrlAction
  extend AppHelper
  extend LightService::Action

  expects  :original_uri

  executed do |ctx|
    begin
      Config.il.l(binding, :hit, aggregate: true)

      original_uri = ctx[:original_uri]

      # Validate URI (online) & content-type as the second protection level
      original_image       = NetworkUtils::UrlInfo.new(original_uri)

      original_image_valid = original_image.valid?

      if Config.validate_online?
        original_image_valid &&= original_image.valid_online? &&
                                 original_image.is?([:image, ''])
      end

      original_image_type = original_image.headers&.fetch('content-type', nil) || '<INVALID IMAGE!>'

      Config.il.l(binding, :original_image, aggregate: true)
      ctx[:original_image] = original_image

      raise ArgumentError, "#{ctx[:original_uri]} is NOT VALID" unless original_image_valid
    rescue ArgumentError, ThreadError => e
      ctx.fail!

      Config.il.f!
      Config.il.l(binding, :origin_error)
    end
  end
end

# Light Service Action to compress image \w some stats
class CompressesImageAction
  extend AppHelper
  extend LightService::Action

  expects :original_uri
  promises :raw_data, :stats

  executed do |ctx|
    raw_data, stats = Config.image_compressor.compress(ctx[:original_uri])

    ctx[:raw_data] = raw_data
    ctx[:stats]    = stats

    if !raw_data
      Config.il.l(binding, :compression_error)
      ctx.fail!
    else
      Config.il.l(binding, :compression_stats, aggregate: true)
    end

    Config.il.f!
  end
end

# Light Service Action to prepare response headers
class PreparesHeadersAction
  extend LightService::Action
  expects :original_image, :raw_data, :resp

  executed do |ctx|
    # Process cases when there's no content-type and HTTParty falls back to the text/html
    content_type = ctx[:original_image].headers&.fetch('content-type', 'image/jpeg')
    content_type = 'image/jpeg' if content_type == 'text/html'

    # Form preconfigured client caching (hours.to_i)
    cache_max_age = "public, max-age=#{Config.client_cache_ttl.hours.to_i}"

    # Return proper inline image (headers, mime, etc.)
    ctx[:resp].status = 200
    ctx[:resp].headers 'Content-Type'   => content_type,
                       'Content-Length' => ctx[:raw_data].length.to_s,
                       'Cache-Control'  => cache_max_age
  end
end

# Light Service Action to send response with compressed image and headers
class SendsResponseAction
  extend LightService::Action
  expects :raw_data, :resp

  executed do |ctx|
    Config.il.f!
    ctx[:resp].body ctx[:raw_data]
  end
end
