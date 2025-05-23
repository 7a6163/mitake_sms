# frozen_string_literal: true

require 'faraday'
require 'faraday/multipart'
require_relative 'configuration'
require_relative 'response'

module MitakeSms
  class Client
    class Error < StandardError; end
    class AuthenticationError < Error; end
    class InvalidRequestError < Error; end
    class ServerError < Error; end

    # Initialize a new MitakeSms::Client
    # @param config [MitakeSms::Configuration] configuration object
    def initialize(config = nil)
      @config = config || MitakeSms.config
      @connection = build_connection
    end

    # Send a single SMS
    # @param to [String] recipient phone number
    # @param text [String] message content
    # @param options [Hash] additional options
    # @option options [String] :from sender ID
    # @option options [String] :response_url callback URL for delivery reports
    # @option options [String] :client_id client reference ID
    # @return [MitakeSms::Response] response object
    def send_sms(to, text, options = {})
      params = {
        username: @config.username,
        password: @config.password,
        dstaddr: to,
        smbody: text.encode('BIG5', invalid: :replace, undef: :replace, replace: '?')
      }.merge(options.slice(:from, :response_url, :client_id))

      response = @connection.post('SmSend', params)
      handle_response(response)
    end

    # Send multiple SMS in a single request
    # @param messages [Array<Hash>] array of message hashes
    #   Each hash should contain :to and :text keys, and can include :from, :response_url, :client_id
    # @return [MitakeSms::Response] response object
    def batch_send(messages)
      params = {
        username: @config.username,
        password: @config.password,
        smbody: messages.map do |msg|
          to = msg[:to]
          text = msg[:text].to_s.encode('BIG5', invalid: :replace, undef: :replace, replace: '?')
          "#{to}:#{text}"
        end.join("\n")
      }
      response = @connection.post('SmBulkSend', params)
      handle_response(response)
    end

    private

    def build_connection
      Faraday.new(url: @config.api_url) do |conn|
        conn.request :url_encoded
        conn.request :multipart
        conn.adapter Faraday.default_adapter
        conn.options.timeout = @config.timeout
        conn.options.open_timeout = @config.open_timeout
      end
    end

    def handle_response(response)
      case response.status
      when 200
        Response.new(response.body)
      when 401
        raise AuthenticationError, 'Invalid username or password'
      when 400
        raise InvalidRequestError, 'Invalid request parameters'
      when 500..599
        raise ServerError, "Server error: #{response.status}"
      else
        raise Error, "Unexpected error: #{response.status}"
      end
    end
  end
end
