# frozen_string_literal: true

require 'light-service'
require 'light-service/testing'

require_relative '../spec_helper'
require_relative '../../lib/services/compresses_image'

describe CompressesImage do
  let(:original_uri) { 'https://httpbin.org/image/jpeg' }
  let(:invalid_uri) { 'https:///httpbin' }
  let(:non_image_uri) { 'https://www.wikipedia.org' }
  let(:invalid_encrypted_uri) { 'Zm9vYmFyZm9vYmFyZm9vYjYxgMsqfK1jJZ1RlO_adbCLsdUivGs8Zwmf1VKhc88g' }
  let(:non_image_encrypted_uri) { 'Zm9vYmFyZm9vYmFyZm9vYlK6zoCbR0SrFDMagg8gEsq4B5CaSn-AwdVRADuDuaUd' }
  let(:encrypted_uri) { 'Zm9vYmFyZm9vYmFyZm9vYnjPh-DqPmZ58K3Oxb_CrxO7RqnKl-VsjYgCmJyOUa3F' }
  let(:encrypted_uri_with_extension) { 'Zm9vYmFyZm9vYmFyZm9vYnjPh-DqPmZ58K3Oxb_CrxO7RqnKl-VsjYgCmJyOUa3F.jpeg' }
  let(:wrong_encrypted_uri) { 'Zm9vYmFyZm9vYmFyZm9vYnjPh-DqPmZ58K3Oxb_CrxO7RqnKl-VsjYgCmJyOUa__' }

  let(:fake_response) do
    response = spy('Fake Roda Response')
    allow(response).to receive(:headers).and_return({})
    allow(response).to receive(:body).and_return(:body)
    allow(response).to receive(:status).and_return(:status)

    response
  end

  before(:each) do
    logger = instance_double('Fake Logger')
    allow(logger).to receive(:l).and_return(true)
    allow(logger).to receive(:f!).and_return(true)

    Config.define_singleton_method(:il) do
      logger
    end
  end

  it 'compresses image' do
    result = CompressesImage.call(encrypted_uri_with_extension, fake_response)
    expect(result).to be_success
  end

  describe DecryptsUrlAction do
    it 'decrypts given URI' do
      context = LightService::Testing::ContextFactory.make_from(CompressesImage)
                                                     .for(described_class)
                                                     .with(encrypted_uri: encrypted_uri)

      result = described_class.execute(context)

      expect(result).to be_success
      expect(result[:original_uri]).to eq(original_uri)
    end

    it 'ignores fake file extension in base64 digest' do
      context = LightService::Testing::ContextFactory.make_from(CompressesImage)
                                                     .for(described_class)
                                                     .with(encrypted_uri: encrypted_uri_with_extension)

      result = described_class.execute(context)

      expect(result).to be_success
      expect(result[:original_uri]).to eq(original_uri)
    end

    it 'fails on wrong base64' do
      context = LightService::Testing::ContextFactory.make_from(CompressesImage)
                                                     .for(described_class)
                                                     .with(encrypted_uri: wrong_encrypted_uri)

      result = described_class.execute(context)

      expect(result).to be_failure
    end
  end

  describe ValidatesUrlAction do
    it 'validates given original URI' do
      context = LightService::Testing::ContextFactory.make_from(CompressesImage)
                                                     .for(described_class)
                                                     .with(original_uri: original_uri, encrypted_uri: encrypted_uri)

      result = described_class.execute(context)

      expect(result).to be_success
      expect(result[:original_uri]).to eq(original_uri)
    end

    it 'fails on invalid URI' do
      context = LightService::Testing::ContextFactory.make_from(CompressesImage)
                                                     .for(described_class)
                                                     .with(
                                                       original_uri: invalid_uri,
                                                       encrypted_uri: invalid_encrypted_uri
                                                     )

      result = described_class.execute(context)

      expect(result).to be_failure
    end
  end

  describe CompressesImageAction do
    it 'compresses image by URL', vcr: true do
      context = LightService::Testing::ContextFactory.make_from(CompressesImage)
                                                     .for(described_class)
                                                     .with(original_uri: original_uri, encrypted_uri: encrypted_uri)

      result = described_class.execute(context)

      expect(result).to be_success

      expect(result[:raw_data].length).to eq(34_225)

      expect(result[:stats][:compression_rate]).to be > 3
      expect(result[:stats][:compression_time]).to be > 0
      expect(result[:stats][:retrieval_time]).to   be > 0
    end

    it 'fails on wrong image format', vcr: true do
      context = LightService::Testing::ContextFactory.make_from(CompressesImage)
                                                     .for(described_class)
                                                     .with(
                                                       original_uri: non_image_uri,
                                                       encrypted_uri: non_image_encrypted_uri
                                                     )

      result = described_class.execute(context)

      expect(result).to be_failure
    end
  end

  describe PreparesHeadersAction do
    it 'prepares correct headers to respond with' do
      context = LightService::Testing::ContextFactory.make_from(CompressesImage)
                                                     .for(described_class)
                                                     .with(
                                                       original_uri: original_uri,
                                                       encrypted_uri: encrypted_uri,
                                                       resp: fake_response
                                                     )

      result = described_class.execute(context)

      expect(result).to be_success
      expect(fake_response).to have_received(:'status=').with(200)
      expect(fake_response).to have_received(:headers).with(
        'Content-Type'   => 'image/jpeg',
        'Content-Length' => '34225',
        'Cache-Control'  => 'public, max-age=14400'
      )
    end
  end

  describe SendsResponseAction do
    it 'responses with raw binary compressed data' do
      context = LightService::Testing::ContextFactory.make_from(CompressesImage)
                                                     .for(described_class)
                                                     .with(
                                                       original_uri: original_uri,
                                                       encrypted_uri: encrypted_uri,
                                                       resp: fake_response
                                                     )

      result = described_class.execute(context)

      expect(result).to be_success
      expect(fake_response).to have_received(:body).with(result[:raw_data])
    end
  end
end
