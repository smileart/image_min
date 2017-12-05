# frozen_string_literal: true

require 'roda'
require 'active_support/core_ext/numeric/time'

require_relative './lib/services/compresses_image'
require_relative './lib/services/generates_digest'

# REST interface for image compression service
class ImageMin < Roda
  include AppHepler

  plugin :heartbeat, path: '/status'
  plugin :halt
  plugin :sinatra_helpers
  plugin :default_headers,
         'Content-Security-Policy'     => "default-src 'self'",
         'Strict-Transport-Security'   => 'max-age=16070400;',
         'X-Frame-Options'             => 'deny',
         'X-Content-Type-Options'      => 'nosniff',
         'X-XSS-Protection'            => '1; mode=block',
         'Access-Control-Allow-Origin' => '*',
         'Content-Disposition'         => 'inline',
         'Content-Type'                => 'image/jpeg'

  route do |r|
    r.on 'secret' do
      # POST /secret request
      r.post do
        GeneratesDigest.call(r, response)
      end
    end

    # GET /:origin request
    r.get do
      r.is String do |origin|
        render_placeholder(r, response) if CompressesImage.call(origin, response).failure?
      end
    end
  end
end
