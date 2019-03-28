# frozen_string_literal: true

require 'network_utils/url_info'

require_relative 'spec_helper'
require_relative '../lib/config'
require_relative '../lib/image_compressor'

describe ImageCompressor do
  let(:image_compressor) { Config.image_compressor }
  let(:jpeg_image_url) { 'https://httpbin.org/image/jpeg' }
  let(:svg_image) { 'https://httpbin.org/image/svg' }
  let(:slow_response_url) { 'https://httpbin.org/delay/10' }
  let(:not_avail) { 'https://localhost:0000' }

  context 'ImageCompressor' do
    it 'should be instance of ImageCompressor' do
      expect(image_compressor).to be_a(ImageCompressor)
    end

    it 'returns compressed image for a given uri', vcr: true do
      original_image = NetworkUtils::UrlInfo.new(jpeg_image_url)
      compressed_img, stats = image_compressor.compress(jpeg_image_url)

      expect(compressed_img.size).to be < original_image.size

      expect(stats).to be_a(Hash)
      expect(stats[:compression_rate]).to be_a(Float)
      expect(stats[:retrieval_time]).to be_a(Integer)

      expect(stats[:compression_rate]).to be > 4
      expect(stats[:compression_time]).to be < 300
      expect(stats[:retrieval_time]).to be < 100
    end

    it 'returns original data on compression fail', vcr: true do
      original_image = NetworkUtils::UrlInfo.new(svg_image)
      compressed_img, stats = image_compressor.compress(svg_image)

      expect(compressed_img.size).to eq(original_image.size)

      expect(stats).to be_a(Hash)
      expect(stats[:compression_rate]).to be_a(Float)
      expect(stats[:retrieval_time]).to be_a(Integer)

      expect(stats[:compression_rate]).to eq(0.0)
      expect(stats[:compression_time]).to be < 300
      expect(stats[:retrieval_time]).to be < 100
    end

    it 'on exception returns nil and message', vcr: true do
      compressed_img, stats = image_compressor.compress(not_avail)

      expect(compressed_img).to be_nil
      expect(stats).to be_a(Hash)
      expect(stats[:error_class]).to eq('Errno::EADDRNOTAVAIL').or(eq('Errno::ECONNREFUSED'))
      expect(stats[:error_message]).to start_with('')
    end

    it 'returns nil and error test for given digest on error or delay', vcr: false do
      compressed_img, error = image_compressor.compress(slow_response_url)

      expect(compressed_img).to be_nil
      expect(error).to be_an(Hash)
      expect(error[:error_class]).to eq('Timeout::Error').or(eq('Net::ReadTimeout'))
      expect(error[:error_message]).to eq('execution expired')
    end
  end
end
