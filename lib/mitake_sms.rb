# frozen_string_literal: true

require_relative 'mitake_sms/version'
require_relative 'mitake_sms/configuration'
require_relative 'mitake_sms/response'
require_relative 'mitake_sms/client'

module MitakeSms
  class Error < StandardError; end

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
    # @return [MitakeSms::Configuration] the current configuration
    def config
      @config ||= Configuration.new
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
    # @return [MitakeSms::Response] response object
    def send_sms(to, text, options = {})
      client.send_sms(to, text, options)
    end

    # Send multiple SMS messages in a single request
    # @param messages [Array<Hash>] array of message hashes
    #   Each hash should contain :to and :text keys, and can include :from, :response_url, :client_id
    # @return [MitakeSms::Response] response object
    def batch_send(messages)
      client.batch_send(messages)
    end
  end
end
