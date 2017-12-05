# frozen_string_literal: true

require 'dotenv'
require 'env_vars/dotenv'
require 'image_optim'
require 'invisible_logger'
require 'rotation_hash'

require_relative './image_compressor'
require_relative './log_stencils/image_min'

# Configuration from the ENV
Config = Env::Vars.new do
  # Env
  mandatory :rack_env, :string

  # Secret Keys
  mandatory :secret_key, :string
  mandatory :public_iv, :string
  mandatory :secret_token, :string

  # App Config
  optional  :env_name, :string, '<NONE>'
  optional  :placeholder_image, :string, './img/placeholder.jpg'
  optional  :image_optim_config_path, :string, './config/image_optim.yml'
  optional  :memoisation_limit, :int, 10_000
  optional  :client_cache_ttl, :int, 4
  optional  :host, :string, 'localhost'
  optional  :port, :string, '9292'
  optional  :site, :string, 'localhost:9292'
  optional  :retrieval_timeout, :int, 5
  optional  :compression_timeout, :int, 3

  # Server
  optional  :max_threads, :int, 16
  optional  :web_concurrency, :int, 5
  optional  :zombies_killing_rate, :int, 5
  optional  :zombies_max_population, :int, 5
  optional  :validate_online, :bool, true
  optional  :log_level, :string, Logger::WARN

  property :il do
    # Configure standard Logger
    logger       = Logger.new(STDOUT)
    logger.level = log_level

    # Invisible logger
    InvisibleLogger.new(logger: logger, log_stencil: ImageMinLog::STENCIL)
  end

  property :urls_memo do
    RotationHash.new(memoisation_limit, nil)
  end

  property :image_compressor do
    image_optim = ImageOptim.new(config_paths: image_optim_config_path, pngout: false, svgo: false)

    ImageCompressor.new(
      image_optim:         image_optim,
      compression_timeout: compression_timeout,
      retrieval_timeout:   retrieval_timeout
    )
  end
end
