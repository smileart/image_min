# frozen_string_literal: true

require 'simple_encryptor'
require 'invisible_logger'
require 'rotation_hash'

# Module to implement App helpers
module AppHelper
  # A teensy-weensy image to server as a placeholder on wrong config
  UMBRELLA = <<~UMBRELLA.gsub("\n", '')
    89504e470d0a1a0a0000000d49484452000000100000001008060000001ff3ff61000000017352
    474200aece1ce90000000467414d410000b18f0bfc6105000000097048597300000ec300000ec3
    01c76fa864000000ab49444154384fd5d0b10ec1501480e13b9018259e007d0bdd7901561e8445
    0c120f6328893e808e1633426b30773090f09fdb2b9a54a38d48f8932fa7e726b769aabeddc6cc
    cc15d1838b136e662ed04501a9d5b0c6126dd45132b3030f2b5491a8823d867a4b6f842dca7a8b
    3581133dbe6d8671f4f86c8723424c61618eb399f13d40e2e75e31807c9a4cf9798fbdff62bf20
    5372f1a3fef4053e1ab0719083bcb5201745530e7e39a5ee696028ca8eba93460000000049454e
    44ae426082
  UMBRELLA

  # Redefined Roda initialiser
  def initialize(*args)
    # Let Roda do its thing
    super
  end

  # Method to respond right away with a placeholder image
  #
  # @param [Object] request Roda request instance
  # @param [Object] response Roda response instance
  def render_placeholder(request, response)
    @placeholder_img_path ||= File.expand_path(
      "../#{Config.placeholder_image}",
      File.dirname(__FILE__)
    )

    # serve an UMBRELLA wita a bit of binary magic
    request.halt(200, response.headers({
      'Content-Type'   => 'image/png',
      'Cache-Control'  => 'no-cache, no-store, must-revalidate',
      'Content-Length' => UMBRELLA.length
    }), UMBRELLA.scan(/../).map(&:hex).pack("c*")) unless File.exist?(@placeholder_img_path)

    @placeholder_img_type = File.extname(Config.placeholder_image).tr('.', '')

    Config.il.l(binding, :placeholder)

    @raw_data_size ||= File.size(@placeholder_img_path).to_s
    @raw_data      ||= File.read(@placeholder_img_path)

    response.headers 'Content-Type'   => @placeholder_img_type == 'svg' ? 'xml/svg' : "image/#{@placeholder_img_type}"
    response.headers 'Cache-Control'  => 'no-cache, no-store, must-revalidate'
    response.headers 'Content-Length' => @raw_data_size

    request.halt(200, response.headers, @raw_data)
  end

  # Decrypt the encrypted URI digest to get the original URI
  #
  # @see SimpleEncryptor
  # @see RotationHash
  #
  # @note Method uses memoisation to save on decryption
  #
  # @param [String] encrypted_image_digest the encrypted version if the image URI
  # @return [String] decrypted original image URI
  def original_uri(encrypted_image_digest)
    return Config.urls_memo[encrypted_image_digest] if Config.urls_memo[encrypted_image_digest]
    Config.urls_memo[encrypted_image_digest] = SimpleEncryptor.decrypt(encrypted_image_digest, Config.secret_key)
  end

  # Encrypt the image URI into URL safe base64 digest
  #
  # @see Cryptor
  # @see RotationHash
  #
  # @note Method uses memoisation to save on future decryption
  #
  # @param [String] image_uri the original image URI
  # @return [String] encrypted image URI in form of base64 digest
  def uri_digest(image_uri)
    digest = SimpleEncryptor.encrypt(image_uri, Config.secret_key, Config.public_iv)
    Config.urls_memo[digest] = image_uri

    digest
  end

  # Get current request_id from Rake::RequestId middleware
  #
  # @return [String] request_id — UUID assigned to the current request (thread safe)
  def request_id
    Thread.current[:request_id]
  end
end
