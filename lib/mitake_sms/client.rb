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
    # @param destname [String] recipient name or key value for system integration (optional)
    # @param response_url [String] callback URL for delivery reports (optional)
    # @param client_id [String] client reference ID (optional)
    # @param charset [String] character encoding, defaults to 'UTF8' (optional)
    # @param options [Hash] additional options (optional)
    # @return [MitakeSms::Response] response object
    def send_sms(to:, text:, destname: nil, response_url: nil, client_id: nil, charset: 'UTF8', **options)
      require 'uri'

      # Create options hash with only non-nil values
      param_options = {}
      param_options[:destname] = destname if destname
      param_options[:response_url] = response_url if response_url
      param_options[:client_id] = client_id if client_id

      # Replace any newline characters with ASCII code 6 (ACK)
      # This is required by the Mitake API to represent line breaks
      processed_text = text.to_s.gsub("\n", 6.chr)

      # Prepare query parameters - only CharsetURL is sent as query parameter
      query_params = {
        CharsetURL: charset
      }

      # Prepare form parameters - all other parameters are sent in the POST body
      form_params = {
        username: @config.username,
        password: @config.password,
        dstaddr: to,
        smbody: processed_text
      }.merge(param_options).merge(options)

      # Construct the endpoint URL
      endpoint = "SmSend"

      response = @connection.post(endpoint) do |req|
        req.params = query_params
        req.body = form_params
      end

      handle_response(response)
    end

    # Send multiple SMS in a single request
    # @param messages [Array<Hash>] array of message hashes
    #   Each hash should contain :to and :text keys, and can include :from, :response_url, :client_id
    # @param options [Hash] additional options
    # @option options [String] :charset character encoding, defaults to 'UTF8'
    # @option options [Boolean] :skip_encoding skip URL encoding (for tests)
    # @return [MitakeSms::Response, Array<MitakeSms::Response>] response object or array of response objects if batch was split
    def batch_send(messages, options = {})
      # Mitake SMS API has a limit of 500 messages per request
      # Automatically split larger batches into multiple requests of 500 messages each
      batch_send_with_limit(messages, 500, options)
    end

    # Send multiple SMS in a single request with a limit per request
    # @param messages [Array<Hash>] array of message hashes
    #   Each hash should contain :to and :text keys, and can include :from, :response_url, :client_id
    # @param limit [Integer] maximum number of messages per request (default: 500)
    # @param options [Hash] additional options
    # @option options [String] :charset character encoding, defaults to 'UTF8'
    # @option options [Boolean] :skip_encoding skip URL encoding (for tests)
    # @return [MitakeSms::Response, Array<MitakeSms::Response>] response object or array of response objects if batch was split
    def batch_send_with_limit(messages, limit = 500, options = {})
      charset = options[:charset] || 'UTF8'

      # If messages count is within the limit, use the regular batch send
      return send_batch(messages, charset, options) if messages.size <= limit

      # Otherwise, split into batches of the specified limit
      responses = []
      messages.each_slice(limit) do |batch|
        responses << send_batch(batch, charset, options)
      end

      # Return array of responses
      responses
    end

    # Send multiple SMS in a single request using advanced format
    # @param messages [Array<Hash>] array of message hashes with advanced options
    #   Each hash can contain the following keys:
    #   - :client_id [String] client reference ID (required)
    #   - :to [String] recipient phone number (required)
    #   - :dlvtime [String] delivery time in format YYYYMMDDHHMMSS (optional)
    #   - :vldtime [String] valid until time in format YYYYMMDDHHMMSS (optional)
    #   - :dest_name [String] recipient name (optional)
    #   - :response [String] callback URL for delivery reports (optional)
    #   - :text [String] message content (required)
    # @param options [Hash] additional options
    # @option options [String] :charset character encoding, defaults to 'UTF8'
    # @option options [Boolean] :skip_encoding skip URL encoding (for tests)
    # @return [MitakeSms::Response, Array<MitakeSms::Response>] response object or array of response objects if batch was split
    def advanced_batch_send(messages, options = {})
      # Mitake SMS API has a limit of 500 messages per request
      # Automatically split larger batches into multiple requests of 500 messages each
      advanced_batch_send_with_limit(messages, 500, options)
    end

    # Send multiple SMS in a single request with a limit per request using advanced format
    # @param messages [Array<Hash>] array of message hashes with advanced options
    # @param limit [Integer] maximum number of messages per request (default: 500)
    # @param options [Hash] additional options
    # @option options [String] :charset character encoding, defaults to 'UTF8'
    # @option options [Boolean] :skip_encoding skip URL encoding (for tests)
    # @return [MitakeSms::Response, Array<MitakeSms::Response>] response object or array of response objects if batch was split
    def advanced_batch_send_with_limit(messages, limit = 500, options = {})
      charset = options[:charset] || 'UTF8'

      # If messages count is within the limit, use the regular batch send
      return send_advanced_batch(messages, charset, options) if messages.size <= limit

      # Otherwise, split into batches of the specified limit
      responses = []
      messages.each_slice(limit) do |batch|
        responses << send_advanced_batch(batch, charset, options)
      end

      # Return array of responses
      responses
    end

    private

    # Internal method to send a single batch
    # @param batch [Array<Hash>] array of message hashes for a single batch
    # @param charset [String] character encoding, defaults to 'UTF8'
    # @param options [Hash] additional options
    # @return [MitakeSms::Response] response object
    def send_batch(batch, charset = 'UTF8', options = {})
      require 'uri'

      # Format each message according to the advanced format
      # ClientID $$ dstaddr $$ dlvtime $$ vldtime $$ destname $$ response $$ smbody
      data = batch.map do |msg|
        # ClientID is required and must be unique
        # If not provided, generate a unique ID
        client_id = msg[:client_id]
        if client_id.nil? || client_id.empty?
          client_id = generate_unique_client_id
        end

        to = msg[:to]
        dlvtime = msg[:dlvtime] || ''
        vldtime = msg[:vldtime] || ''
        dest_name = msg[:destname] || ''
        response_url = msg[:response_url] || ''

        # Replace any newline characters in the message text with ASCII code 6 (ACK)
        # This is required by the Mitake API to represent line breaks within message content
        processed_text = msg[:text].to_s.gsub("\n", 6.chr)

        # Format according to API documentation: ClientID $$ dstaddr $$ dlvtime $$ vldtime $$ destname $$ response $$ smbody
        [client_id, to, dlvtime, vldtime, dest_name, response_url, processed_text].join('$$')
      end.join("\n")

      # Parameters for the request
      query_params = {
        username: @config.username,
        password: @config.password,
        Encoding_PostIn: charset
      }

      # According to the API documentation, the data should be in the request body
      response = @connection.post('SmBulkSend') do |req|
        req.params = query_params
        req.body = data
        req.headers['Content-Type'] = 'text/plain'
      end

      handle_response(response)
    end

    # Internal method to send a single batch using advanced format
    # @param batch [Array<Hash>] array of message hashes for a single batch with advanced options
    # @param charset [String] character encoding, defaults to 'UTF8'
    # @param options [Hash] additional options
    # @return [MitakeSms::Response] response object
    def send_advanced_batch(batch, charset = 'UTF8', options = {})
      require 'uri'

      # Format each message according to the advanced format
      # ClientID $$ dstaddr $$ dlvtime $$ vldtime $$ destname $$ response $$ smbody
      data = batch.map do |msg|
        # ClientID is required and must be unique
        # If not provided, generate a unique ID
        client_id = msg[:client_id]
        if client_id.nil? || client_id.empty?
          client_id = generate_unique_client_id
        end

        to = msg[:to]
        dlvtime = msg[:dlvtime] || ''
        vldtime = msg[:vldtime] || ''
        dest_name = msg[:dest_name] || ''
        response_url = msg[:response] || ''

        # Replace any newline characters in the message text with ASCII code 6 (ACK)
        # This is required by the Mitake API to represent line breaks within message content
        processed_text = msg[:text].to_s.gsub("\n", 6.chr)

        [client_id, to, dlvtime, vldtime, dest_name, response_url, processed_text].join('$$')
      end.join("\n")

      # All parameters should be sent as query string parameters
      query_params = {
        username: @config.username,
        password: @config.password,
        data: data,
        Encoding_PostIn: charset
      }

      # Use empty body with all parameters in query string
      response = @connection.post('SmPost') do |req|
        req.params = query_params
        req.body = {}
      end

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

    # Generate a unique client ID for SMS messages
    # @return [String] a unique ID combining timestamp and random values
    def generate_unique_client_id
      require 'securerandom'

      # Generate a unique ID using timestamp (to milliseconds) and a random UUID portion
      timestamp = Time.now.strftime('%Y%m%d%H%M%S%L')
      random_part = SecureRandom.uuid.gsub('-', '')[0, 8]
      "#{timestamp}-#{random_part}"
    end
  end
end
