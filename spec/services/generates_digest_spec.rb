# frozen_string_literal: true

require 'light-service'
require 'light-service/testing'

require_relative '../spec_helper'
require_relative '../../lib/services/generates_digest'

describe GeneratesDigest do
  let(:encrypted_link) do
    '<a href=\'localhost:9292/Zm9vYmFyZm9vYmFyZm9vYnjPh-DqPmZ58K3Oxb_CrxO7RqnKl-VsjYgCmJyOUa3F\'>image</a>'
  end

  let(:fake_request) do
    request = spy('Fake Roda Request')

    allow(request).to receive(:halt) { |*args| args }
    allow(request).to receive(:params) do
      {
        'image_uri'    => 'https://httpbin.org/image/jpeg',
        'secret_token' => 'testtesttesttest'
      }
    end

    request
  end

  let(:fake_response) do
    response = spy('Fake Roda Response')
    allow(response).to receive(:headers).and_return(:headers)
    allow(response).to receive(:body).and_return(:body)

    response
  end

  before(:each) do
    logger = instance_double('Fake Logger')
    allow(logger).to receive(:l).and_return(true)

    Config.define_singleton_method(:il) do
      logger
    end
  end

  it 'generates digest' do
    result = GeneratesDigest.call(fake_request, fake_request)

    expect(result).to be_success
  end

  describe EncryptsUrlAction do
    let(:fake_request_wrong_token) do
      request = spy('Fake Roda Request')

      allow(request).to receive(:halt) { |*args| args }
      allow(request).to receive(:params) do
        {
          'image_uri'    => 'https://httpbin.org/image/jpeg',
          'secret_token' => 'totallywrongtoken'
        }
      end

      request
    end

    let(:fake_request_no_uri) do
      request = spy('Fake Roda Request')

      allow(request).to receive(:halt) { |*args| args }
      allow(request).to receive(:params) do
        {
          'secret_token' => 'testtesttesttest'
        }
      end

      request
    end

    it 'encrypts URL and returns a link' do
      context = LightService::Testing::ContextFactory.make_from(GeneratesDigest)
                                                     .for(described_class)
                                                     .with(req: fake_request, resp: fake_response)

      result = described_class.execute(context)
      expect(result).to be_success

      expect(fake_response).to have_received(:body).with(encrypted_link)
    end

    it 'fails with a wrong token provided' do
      context = LightService::Testing::ContextFactory.make_from(GeneratesDigest)
                                                     .for(described_class)
                                                     .with(req: fake_request_wrong_token, resp: fake_response)

      result = described_class.execute(context)
      expect(result).to be_failure

      expect(fake_request_wrong_token).to have_received(:halt).with(400)
    end

    it 'fails with no URI provided' do
      context = LightService::Testing::ContextFactory.make_from(GeneratesDigest)
                                                     .for(described_class)
                                                     .with(req: fake_request_no_uri, resp: fake_response)

      result = described_class.execute(context)
      expect(result).to be_failure

      expect(fake_request_no_uri).to have_received(:halt).with(400)
    end
  end
end
