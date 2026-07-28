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
    # @param destname [String] recipient name or key value for system integration (optional)
    # @param response_url [String] callback URL for delivery reports (optional)
    # @param client_id [String] client reference ID (optional)
    # @param options [Hash] any other documented SmSend field
    # @return [MitakeSms::Response] response object
    def send_sms(to:, text:, destname: nil, response_url: nil, client_id: nil, **options)
      client.send_sms(
        to: to,
        text: text,
        destname: destname,
        response_url: response_url,
        client_id: client_id,
        **options
      )
    end

    # Send multiple SMS messages in a single request
    # The Mitake SMS API has a limit of 500 messages per request
    # If more than 500 messages are provided, they will be automatically split into multiple requests
    # @param messages [Array<Hash>] array of message hashes
    #   Each hash requires :to and :text, and may include :client_id, :dlvtime,
    #   :vldtime, :destname and :response_url
    # @param options [Hash] any other documented SmBulkSend field
    # @raise [ArgumentError] if a field other than :text contains '$$' or a line break
    # @return [MitakeSms::Response, Array<MitakeSms::Response>] response object or array of response objects if batch was split
    def batch_send(messages, options = {})
      client.batch_send(messages, options)
    end
  end
end
