# frozen_string_literal: true
# encoding: UTF-8

require 'singleton'
require 'image_optim'
require 'benchmark'
require 'addressable/uri'
require 'net/http'

# A simple class to securely compress images on the fly
#
# @example
#   ImageCompressor.new(image_optim, 5, 5).compress(image_uri)
#
class ImageCompressor
  # Retrieval errors generalised
  NETWORK_ERRORS = [Net::HTTPClientError, Net::HTTPServerError].freeze

  # Create an instance of the ImageCompressor
  #
  # @see ImageOptim https://github.com/toy/image_optim
  #
  # @param [ImageOptim] image_optim ImageOptim instance to compress images with
  # @param [Integer] retrieval_timeout the timeout of retrieval attempt (default: 10)
  # @param [Integer] compression_timeout the timeout of of compression attempt (default: 5)
  #
  def initialize(image_optim:, retrieval_timeout: 10, compression_timeout: 5)
    @image_optim         = image_optim
    @compression_timeout = compression_timeout
    @retrieval_timeout   = retrieval_timeout
  end

  # Compress an image using encrypted image URI digest
  #
  # @param [String] image_uri the URI of the image to compress
  #
  # @return [Array<String,Hash>, Array<nil,Hash>] binary data, compressed or original image (in case of compression
  #                                     failure) and compression stats (% diff between original and compressed version
  #                                     and compression/retrieval time)
  #                                     When original image unavailable: returns nil + error Hash (with error info)
  def compress(image_uri)
    raw_data, retrieval_time          = retrieve_image(image_uri)
    compressed_data, compression_time = compress_image(raw_data)

    stats = {
      compression_rate: 100 - (compressed_data.length / raw_data.length.to_f * 100.0),
      compression_time: (compression_time.real * 1000).to_i,
      retrieval_time:   (retrieval_time.real * 1000).to_i
    }

    [compressed_data, stats]
  rescue RetrievalError, SocketError, Timeout::Error, ThreadError,
         Errno::EADDRNOTAVAIL, Errno::ECONNREFUSED, Errno::EHOSTUNREACH,
         Errno::ENETUNREACH, Errno::ECONNRESET, EXIFR::MalformedImage,
         HTTParty::Error, HTTParty::ResponseError => e

    [nil, { error_class: e.class.to_s, error_message: e.message }]
  end

  private

  # Retrieve the original image from the source
  #
  # @param [String] image_uri the URI of the image to download
  #
  # @raise [RetrievalError] if there was an issue with image retrieving (client/server)
  # @raise [Timeout::Error] if the retrieval took more time then we allowed with @retrieval_timeout
  #
  # @return [Array<String,Integer>] an array containing 2 elements: raw image data, retrieval_time (ms)
  def retrieve_image(image_uri)
    retrieval_time = 0
    raw_data       = nil

    Timeout.timeout(@retrieval_timeout) do
      retrieval_time = Benchmark.measure do
        image_uri     = Addressable::URI.encode(image_uri) unless image_uri.include? '%'
        response      = HTTParty.get(image_uri, timeout: @retrieval_timeout - 1)
        content_type  = response.headers&.fetch('content-type')

        if NETWORK_ERRORS.include?(response.response) || content_type.empty? || !content_type.start_with?('image')
          raise RetrievalError, error_message(image_uri, content_type, response)
        end

        raw_data = response.body
      end
    end

    [raw_data, retrieval_time]
  end

  # Compress an image using encrypted image URI digest
  #
  # @param [String] raw_data the original image data
  #
  # @raise [Timeout::Error] if the compression took more time then we allowed with @compression_timeout
  #
  # @return [Array<String,Integer>] an array containing 2 elements: compressed image data, compression_time (ms)
  def compress_image(raw_data)
    compression_time = 0
    compressed_data  = nil

    Timeout.timeout(@compression_timeout) do
      compression_time = Benchmark.measure do
        compressed_data = @image_optim.optimize_image_data(raw_data) || raw_data
      end
    end

    [compressed_data, compression_time]
  end

  # Format a retrieval error message
  #
  # @param [String] image_uri the image being requested in order to retrieve an image
  # @param [String] content_type the content_type returned by the remote server
  # @param [HTTParty::Response] response the response received from the remote server
  #
  def error_message(image_uri, content_type, response)
    error_body = (response.body.include?('<html') ? response.body : response.body[0, 300])
    error_body = error_body.lines.map(&:strip).join(' ')

    %W[
      URI: `#{image_uri}` ::
      Code: `#{response.code}` ::
      Content-Type: `#{content_type}` ::
      Body: `#{error_body}`
    ].join(' ')
  end
end

# Network (server & client) combined error
class RetrievalError < StandardError; end
