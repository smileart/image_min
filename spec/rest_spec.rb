# frozen_string_literal: true

require 'httparty'
require 'active_support/core_ext/numeric/time'
require 'network_utils/url_info'
require 'network_utils/port'

require_relative 'spec_helper'

describe 'ImageMin REST service' do
  let(:service_address) { "http://#{Config.site}" }
  let(:jpeg_image_url) { 'https://httpbin.org/image/jpeg' }
  let(:jpeg_image_digest) { 'Zm9vYmFyZm9vYmFyZm9vYnjPh-DqPmZ58K3Oxb_CrxO7RqnKl-VsjYgCmJyOUa3F' }
  let(:jpeg_image_encrypted_link) { "<a href='%s%s'>image</a>" }
  let(:unicode_image_url) do
    %w[
      https://ae01.alicdn.com/kf/HTB1IyKARVXXXXbBXpXXq6xXFXXXf/3D-Pleine-Courbe-Trempé-Protecteur
      -D-écran-En-Verre-Pour-Blackberry-font-b-Priv-b-font.jpg
    ].join ''
  end

  let(:unicode_image_digest) do
    %w[
      NjU3YTg2ZjdmNGZkM2U5OD35AeDLC1qNo1DXI0716pVWuyzQERDbHhTNtvSDiIjOkB_dYqLxn71kp3fnSKOch2_8V99dos
      lF2xHMnOHxp4YqRgNuaZ7DXKiyFPKYnQ0zZOK9mQU6a_d4SQc0D5a0NmbDROqvDLlJSeAZMX06QUPciaUu6iDjGTG8QEJA
      1wfhxOYAfVaGRf85O8URhYpoAb4LWsAUpxRqG3AOtI5E9kc
    ].join ''
  end

  before(:all) do
    if NetworkUtils::Port.available?(Config.port, 'localhost', 5)
      `rackup --env test --server puma --port $PORT --daemonize --pid /tmp/rack_test_server.pid && sleep 1`
    end
  end

  after(:all) do
    `kill -15 $(cat /tmp/rack_test_server.pid 2> /dev/null) > /dev/null 2>&1`
  end

  it 'reports its own status', vcr: false do
    response = HTTParty.get("#{service_address}/status")
    expect(response.parsed_response).to eq('OK')
    expect(response.code).to eq(200)
  end

  it 'response with 404 on the main page', vcr: false do
    response = HTTParty.get("#{service_address}/")
    expect(response.code).to eq(404)
  end

  it 'response with 404 on wrong URL', vcr: false do
    response = HTTParty.get("#{service_address}/wrong/url")
    expect(response.code).to eq(404)
  end

  it 'response with a link on /secret', vcr: false do
    response = HTTParty.post(
      "#{service_address}/secret",
      query: {
        image_uri: jpeg_image_url,
        secret_token: Config.secret_token
      }
    )

    expect(response.body).to eq(
      format(
        jpeg_image_encrypted_link,
        "#{service_address.sub('http://', '')}/",
        jpeg_image_digest
      )
    )

    expect(response.headers['content-type']).to eq('text/html')
    expect(response.code).to eq(200)
  end

  it 'response with a compressed version of the image', vcr: false do
    response = HTTParty.get("#{service_address}/#{jpeg_image_digest}")
    original_image = NetworkUtils::UrlInfo.new(jpeg_image_url)

    expect(response.body.size).to be < original_image.size
  end

  it 'response with a compressed version of the image with Unicode URL', vcr: false do
    response = HTTParty.get("#{service_address}/#{unicode_image_digest}")
    original_image = NetworkUtils::UrlInfo.new(unicode_image_url)

    expect(response.body.size).to be < original_image.size
  end

  it 'ignores "file" extension on image request', vcr: false do
    response = HTTParty.get("#{service_address}/#{jpeg_image_digest}.jpeg")
    original_image = NetworkUtils::UrlInfo.new(jpeg_image_url)

    expect(response.body.size).to be < original_image.size
  end

  it 'response with appropriate headers', vcr: false do
    response = HTTParty.get("#{service_address}/#{jpeg_image_digest}")

    expect(response.headers['Content-Type']).to eq('image/jpeg')
    expect(response.headers['Content-Length'].to_i).to eq(response.body.size)
    expect(response.headers['Cache-Control']).to eq("public, max-age=#{Config.client_cache_ttl.to_i.hours}")
    expect(response.headers['Content-Disposition']).to eq('inline')
    expect(response.headers['X-XSS-Protection']).to eq('1; mode=block')
  end

  it 'response with a placeholder image when something goes wrong', vcr: false do
    response         = HTTParty.get("#{service_address}/#{jpeg_image_digest}__")
    placeholder_size = File.size(Config.placeholder_image)

    expect(response.code).to eq(200)
    expect(response.body.size).to eq(placeholder_size)
  end

  it 'placeholder shouldn\'t be cached', vcr: false do
    response         = HTTParty.get("#{service_address}/#{jpeg_image_digest}__")
    placeholder_size = File.size(Config.placeholder_image)

    expect(response.headers['Cache-Control']).to eq('no-cache, no-store, must-revalidate')
    expect(response.body.size).to eq(placeholder_size)
  end
end
