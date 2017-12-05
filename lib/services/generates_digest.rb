# frozen_string_literal: true

require 'base64'
require 'light-service'

require_relative '../config'
require_relative '../../helpers/app_helper'

# Light Service Organiser to generate URL digest
class GeneratesDigest
  extend LightService::Organizer

  # Default static LightService::Organizer call method
  #
  # @param [RodaRequest] req Roda request object
  # @param [RodaResponse] resp Roda response object
  #
  # @return [LightService::Context] context with the result properties and status
  def self.call(req, resp)
    with(req: req, resp: resp).reduce(actions)
  end

  # Default static LightService::Organizer actions list
  #
  # @return [Array<LightService::Action> actions list in order
  def self.actions
    [EncryptsUrlAction]
  end
end

# Light Service Action to encrypt original URL
class EncryptsUrlAction
  extend AppHepler
  extend LightService::Action

  expects :req, :resp

  executed do |ctx|
    image_uri = ctx[:req].params&.fetch('image_uri', nil)
    image_uri = image_uri&.strip&.empty? ? nil : image_uri

    secret_token = ctx[:req].params&.fetch('secret_token', nil)
    secret_token = secret_token&.strip&.empty? ? nil : secret_token

    Config.il.l(binding, :secret)

    if !image_uri || !secret_token || secret_token != Config.secret_token
      ctx[:req].halt 400
      ctx.fail_and_return! # this line would be executed in test env only
    end

    ctx[:resp].headers 'Content-Type' => 'text/html'
    ctx[:resp].body "<a href='#{Config.site}/#{uri_digest(CGI.unescape(image_uri))}'>image</a>"
  end
end
