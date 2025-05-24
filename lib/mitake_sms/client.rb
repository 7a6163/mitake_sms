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
    # @option options [String] :charset character encoding, defaults to 'UTF8'
    # @return [MitakeSms::Response] response object
    def send_sms(to, text, options = {})
      charset = options.delete(:charset) || 'UTF8'

      params = {
        username: @config.username,
        password: @config.password,
        dstaddr: to,
        smbody: text,
        CharsetURL: charset
      }.merge(options.slice(:from, :response_url, :client_id))

      response = @connection.post('SmSend', params)
      handle_response(response)
    end

    # Send multiple SMS in a single request
    # @param messages [Array<Hash>] array of message hashes
    #   Each hash should contain :to and :text keys, and can include :from, :response_url, :client_id
    # @return [MitakeSms::Response, Array<MitakeSms::Response>] response object or array of response objects if batch was split
    def batch_send(messages)
      # Mitake SMS API has a limit of 500 messages per request
      # Automatically split larger batches into multiple requests of 500 messages each
      batch_send_with_limit(messages, 500)
    end

    # Send multiple SMS in a single request with a limit per request
    # @param messages [Array<Hash>] array of message hashes
    #   Each hash should contain :to and :text keys, and can include :from, :response_url, :client_id
    # @param limit [Integer] maximum number of messages per request (default: 500)
    # @param options [Hash] additional options
    # @option options [String] :charset character encoding, defaults to 'UTF8'
    # @return [MitakeSms::Response, Array<MitakeSms::Response>] response object or array of response objects if batch was split
    def batch_send_with_limit(messages, limit = 500, options = {})
      charset = options[:charset] || 'UTF8'

      # If messages count is within the limit, use the regular batch send
      return send_batch(messages, charset) if messages.size <= limit

      # Otherwise, split into batches of the specified limit
      responses = []
      messages.each_slice(limit) do |batch|
        responses << send_batch(batch, charset)
      end

      # Return array of responses
      responses
    end

    private

    # Internal method to send a single batch
    # @param batch [Array<Hash>] array of message hashes for a single batch
    # @param charset [String] character encoding, defaults to 'UTF8'
    # @return [MitakeSms::Response] response object
    def send_batch(batch, charset = 'UTF8')
      params = {
        username: @config.username,
        password: @config.password,
        smbody: batch.map do |msg|
          to = msg[:to]
          text = msg[:text].to_s
          "#{to}:#{text}"
        end.join("\n"),
        Encoding_PostIn: charset
      }
      response = @connection.post('SmBulkSend', params)
      handle_response(response)
    end

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
