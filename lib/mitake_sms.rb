# frozen_string_literal: true

require_relative 'mitake_sms/version'
require_relative 'mitake_sms/configuration'
require_relative 'mitake_sms/response'
require_relative 'mitake_sms/client'

module MitakeSms
  class Error < StandardError; end
  class AuthenticationError < Error; end
  class InvalidRequestError < Error; end
  class ServerError < Error; end

  class << self
    # Configure the gem
    # @yield [MitakeSms::Configuration] the configuration object
    # @example
    #   MitakeSms.configure do |config|
    #     config.username = 'your_username'
    #     config.password = 'your_password'
    #   end
    def configure
      yield(config) if block_given?
    end

    # Get the current configuration
    # @return [Dry::Configurable::Config] the configuration object
    def config
      Configuration.config
    end

    # Create a new client with the current configuration
    # @return [MitakeSms::Client] a new client instance
    def client
      @client ||= Client.new
    end

    # Send a single SMS message
    # @param to [String] recipient phone number
    # @param text [String] message content
    # @param options [Hash] additional options
    # @option options [String] :from sender ID
    # @option options [String] :response_url callback URL for delivery reports
    # @option options [String] :client_id client reference ID
    # @option options [String] :charset character encoding, defaults to 'UTF8'

    # @return [MitakeSms::Response] response object
    def send_sms(to, text, options = {})
      client.send_sms(to, text, options)
    end

    # Send multiple SMS messages in a single request
    # The Mitake SMS API has a limit of 500 messages per request
    # If more than 500 messages are provided, they will be automatically split into multiple requests
    # @param messages [Array<Hash>] array of message hashes
    #   Each hash should contain :to and :text keys, and can include :from, :response_url, :client_id
    # @param options [Hash] additional options
    # @option options [String] :charset character encoding, defaults to 'UTF8'

    # @return [MitakeSms::Response, Array<MitakeSms::Response>] response object or array of response objects if batch was split
    def batch_send(messages, options = {})
      client.batch_send_with_limit(messages, 500, options)
    end

    # Send multiple SMS messages in a single request with a limit per request
    # @param messages [Array<Hash>] array of message hashes
    #   Each hash should contain :to and :text keys, and can include :from, :response_url, :client_id
    # @param limit [Integer] maximum number of messages per request (default: 500)
    # @param options [Hash] additional options
    # @option options [String] :charset character encoding, defaults to 'UTF8'

    # @return [MitakeSms::Response, Array<MitakeSms::Response>] response object or array of response objects if batch was split
    def batch_send_with_limit(messages, limit = 500, options = {})
      client.batch_send_with_limit(messages, limit, options)
    end
    
    # Send multiple SMS messages in a single request using advanced format
    # @param messages [Array<Hash>] array of message hashes with advanced options
    #   Each hash can contain the following keys:
    #   - :client_id [String] client reference ID (optional)
    #   - :to [String] recipient phone number (required)
    #   - :dlvtime [String] delivery time in format YYYYMMDDHHMMSS (optional)
    #   - :vldtime [String] valid until time in format YYYYMMDDHHMMSS (optional)
    #   - :dest_name [String] recipient name (optional)
    #   - :response [String] callback URL for delivery reports (optional)
    #   - :text [String] message content (required)
    # @param options [Hash] additional options
    # @option options [String] :charset character encoding, defaults to 'UTF8'

    # @return [MitakeSms::Response, Array<MitakeSms::Response>] response object or array of response objects if batch was split
    def advanced_batch_send(messages, options = {})
      client.advanced_batch_send(messages, options)
    end
    
    # Send multiple SMS messages in a single request with a limit per request using advanced format
    # @param messages [Array<Hash>] array of message hashes with advanced options
    # @param limit [Integer] maximum number of messages per request (default: 500)
    # @param options [Hash] additional options
    # @option options [String] :charset character encoding, defaults to 'UTF8'

    # @return [MitakeSms::Response, Array<MitakeSms::Response>] response object or array of response objects if batch was split
    def advanced_batch_send_with_limit(messages, limit = 500, options = {})
      client.advanced_batch_send_with_limit(messages, limit, options)
    end
  end
end
