# frozen_string_literal: true

require 'faraday'
require 'securerandom'
require_relative 'configuration'
require_relative 'response'

module MitakeSms
  class Client
    class Error < StandardError; end
    class AuthenticationError < Error; end
    class InvalidRequestError < Error; end
    class ServerError < Error; end

    # The Mitake API represents a line break inside smbody as ASCII code 6.
    LINE_BREAK = 6.chr

    BATCH_LIMIT = 500

    # The API also accepts Big5, but it only labels the payload and never
    # converts it, so sending anything other than UTF8 just invites mojibake.
    CHARSET = 'UTF8'

    FIELD_SEPARATOR = '$$'

    # Every SmBulkSend field except smbody, in wire order. A '$$' or a line
    # break in any of these shifts the remaining fields of the row.
    STRUCTURAL_FIELDS = %i[client_id to dlvtime vldtime destname response_url].freeze

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
    # @param options [Hash] any other documented SmSend field, such as
    #   :dlvtime, :vldtime, :objectID or :smsPointFlag
    # @return [MitakeSms::Response] response object
    def send_sms(to:, text:, destname: nil, response_url: nil, client_id: nil, **options)
      form_params = {
        username: @config.username,
        password: @config.password,
        dstaddr: to,
        smbody: normalize_body(text)
      }
      form_params[:destname] = destname if destname
      form_params[:response] = response_url if response_url
      form_params[:clientid] = client_id if client_id

      perform_request('SmSend', params: { CharsetURL: CHARSET }) do |req|
        req.body = form_params.merge(options)
      end
    end

    # Send multiple SMS in a single request, splitting at the API's 500 message limit
    # @param messages [Array<Hash>] array of message hashes
    #   Each hash requires :to and :text, and may include :client_id, :dlvtime,
    #   :vldtime, :destname and :response_url
    # @param options [Hash] any other documented SmBulkSend field, such as
    #   :objectID or :smsPointFlag
    # @raise [ArgumentError] if a field other than :text contains '$$' or a line break
    # @return [MitakeSms::Response, Array<MitakeSms::Response>] response object or array of response objects if batch was split
    def batch_send(messages, options = {})
      messages.each_with_index { |msg, index| validate_row!(msg, index) }

      batch_send_with_limit(messages, BATCH_LIMIT, options)
    end

    private

    def batch_send_with_limit(messages, limit, options)
      return send_batch(messages, options) if messages.size <= limit

      messages.each_slice(limit).map { |batch| send_batch(batch, options) }
    end

    def send_batch(batch, options)
      query_params = {
        username: @config.username,
        password: @config.password,
        Encoding_PostIn: CHARSET
      }.merge(options)

      perform_request('SmBulkSend', params: query_params) do |req|
        req.body = batch.map { |msg| format_batch_row(msg) }.join("\n")
        req['Content-Type'] = 'text/plain'
      end
    end

    # ClientID $$ dstaddr $$ dlvtime $$ vldtime $$ destname $$ response $$ smbody
    def format_batch_row(msg)
      client_id = msg[:client_id]
      client_id = generate_unique_client_id if client_id.to_s.empty?

      [
        client_id,
        msg[:to],
        msg[:dlvtime],
        msg[:vldtime],
        msg[:destname],
        msg[:response_url],
        normalize_body(msg[:text])
      ].join(FIELD_SEPARATOR)
    end

    def validate_row!(msg, index)
      STRUCTURAL_FIELDS.each do |field|
        value = msg[field].to_s
        next unless value.include?(FIELD_SEPARATOR) || value.match?(/[\r\n]/)

        raise ArgumentError,
              "messages[#{index}][:#{field}] must not contain #{FIELD_SEPARATOR.inspect} or a line break, " \
              'because both are SmBulkSend delimiters'
      end
    end

    # Mitake expects UTF8 bytes with ASCII code 6 standing in for a line break.
    # Transcoding also keeps a batch of mixed-encoding strings from failing to join.
    def normalize_body(text)
      text.to_s.encode(Encoding::UTF_8).gsub(/\r\n?|\n/, LINE_BREAK)
    end

    def perform_request(endpoint, params:)
      response = @connection.post(endpoint) do |req|
        req.params = params
        yield req
      end

      handle_response(response)
    end

    def build_connection
      Faraday.new(url: @config.api_url) do |conn|
        conn.request :url_encoded
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

    # Mitake uses the client ID to suppress duplicate sends within 12 hours,
    # so it has to be unique per message rather than merely random.
    def generate_unique_client_id
      "#{Time.now.strftime('%Y%m%d%H%M%S%L')}-#{SecureRandom.hex(4)}"
    end
  end
end
