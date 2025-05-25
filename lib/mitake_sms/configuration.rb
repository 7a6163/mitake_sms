# frozen_string_literal: true

require 'dry/configurable'

module MitakeSms
  class Configuration
    extend Dry::Configurable

    setting :username, default: ENV['MITAKE_USERNAME']
    setting :password, default: ENV['MITAKE_PASSWORD']
    setting :api_url, default: 'https://smsb2c.mitake.com.tw/b2c/mtk/'
    setting :timeout, default: 30
    setting :open_timeout, default: 5

    # Provide direct access to configuration values at the class level
    class << self
      def username
        config.username
      end

      def username=(value)
        config.username = value
      end

      def password
        config.password
      end

      def password=(value)
        config.password = value
      end

      def api_url
        config.api_url
      end

      def api_url=(value)
        config.api_url = value
      end

      def timeout
        config.timeout
      end

      def timeout=(value)
        config.timeout = value
      end

      def open_timeout
        config.open_timeout
      end

      def open_timeout=(value)
        config.open_timeout = value
      end
    end
  end

  # Methods for the MitakeSms module itself
  class << self
    def configure
      yield(config) if block_given?
    end

    # Return the Dry::Configurable object directly
    def config
      Configuration.config
    end
  end
end
