# frozen_string_literal: true

require_relative 'spec_helper'
require_relative '../helpers/app_helper'

describe AppHepler do
  let(:fake_app) do
    # extend fake App with the AppHepler
    class FakeApp
      # make memo readable for test purposes
      attr_reader :memo
      # attr_accessor :logger

      include AppHepler
    end

    # fake a request ID (IRL would be assigned by Rack::RequestId)
    Thread.current[:request_id] = :fake

    # Instantiate an App
    fake_app = FakeApp.new

    logger = instance_double('Fake Logger')
    allow(logger).to receive(:l).and_return(true)

    Config.define_singleton_method(:il) do
      logger
    end

    fake_app
  end

  let(:fake_request) do
    request = instance_double('Fake Roda Request')
    allow(request).to receive(:halt) { |*args| args }

    request
  end

  let(:fake_response) do
    response = instance_double('Fake Roda response')
    allow(response).to receive(:headers).and_return(:headers)

    response
  end

  let(:jpeg_image_url) { 'https://httpbin.org/image/jpeg' }
  let(:jpeg_digest) { 'Zm9vYmFyZm9vYmFyZm9vYnjPh-DqPmZ58K3Oxb_CrxO7RqnKl-VsjYgCmJyOUa3F' }

  context 'Included to the App' do
    it 'renders placeholder on #render_placeholder' do
      placeholder_size = File.read(ENV['PLACEHOLDER_IMAGE']).size
      resp_code, headers, placeholder_img = fake_app.render_placeholder(fake_request, fake_response)

      expect(resp_code).to eq(200)
      expect(headers).to eq(:headers)
      expect(placeholder_img.size).to eq(placeholder_size)
    end

    it 'decrypts original_uri from provided digest' do
      expect(fake_app.original_uri(jpeg_digest)).to eq(jpeg_image_url)
    end

    it 'returns digest for a given URI' do
      expect(fake_app.uri_digest(jpeg_image_url)).to eq(jpeg_digest)
    end

    it 'returns request_id for current request' do
      expect(fake_app.request_id).to eq(:fake)
    end
  end
end
