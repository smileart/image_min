# frozen_string_literal: true

# Module to keep logging stencils
module ImageMinLog
  # Log stencil fot InvisibleLogger
  # @see InvisibleLogger
  STENCIL = {
    secret: {
      vars: %i[request_id image_uri secret_token],
      level: :info,
      template: <<~LOG
        Secret → metric#request_id=%<request_id>s ::|
        original_url=%<image_uri>s ::|
        secret_token=%<secret_token>s
      LOG
    },
    hit: {
      vars: [:request_id],
      level: :info,
      template: <<~LOG
        Compression → metric#request_id=%<request_id>s ::|
        count#hit=1
      LOG
    },
    encrypted_uri: {
      vars: [:encrypted_uri],
      level: :info,
      template: 'encrypted_uri: %<encrypted_uri>s'
    },
    original_image: {
      vars: %i[original_uri original_image_type],
      template: <<~LOG
        original_uri=%<original_uri>s ::|
        original_image_type=%<original_image_type>s
      LOG
    },
    compression_stats: {
      vars: [
        { retrieval_time: 'stats[:retrieval_time]' },
        { compression_percent: 'stats[:compression_rate].ceil(2)' },
        { compression_time: 'stats[:compression_time]' }
      ],
      level: :info,
      template: <<~LOG
        count#compressed_img=1|
        measure#retrieval_time=%<retrieval_time>s|
        measure#compression_percent=%<compression_percent>s|
        measure#compression_time=%<compression_time>s
      LOG
    },
    origin_error: {
      vars: [:request_id, { error_class: 'e.class' }, { error_message: 'e.message' }],
      level: :error,
      template: <<~LOG
        Compression → metric#request_id=%<request_id>s ::|
        error_type=%<error_class>s ::|
        error_message=%<error_message>s
      LOG
    },
    placeholder: {
      vars: [:request_id],
      level: :info,
      template: <<~LOG
        Placeholder → metric#request_id=%<request_id>s ::|
        count#placeholder_img=1
      LOG
    },
    compression_error: {
      vars: [:request_id, { error_class: 'stats[:error_class]' }, { error_message: 'stats[:error_message]' }],
      level: :error,
      template: <<~LOG
        Compression → metric#request_id=%<request_id>s ::|
        compression_error_type=%<error_class>s ::|
        compression_error_message=%<error_message>s
      LOG
    }
  }.freeze
end
