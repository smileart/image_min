# frozen_string_literal: true

require 'simple_encryptor'
require 'invisible_logger'
require 'rotation_hash'

# Module to implement App helpers
module AppHepler
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
