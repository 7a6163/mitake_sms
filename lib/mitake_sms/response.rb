# frozen_string_literal: true

module MitakeSms
  class Response
    attr_reader :raw_response, :code, :message_id, :account_point, :error

    def initialize(raw_response)
      @raw_response = raw_response
      parse_response(raw_response)
    end

    def success?
      @code == '1'
    end

    def error?
      !success?
    end

    private

    def parse_response(response)
      return unless response.is_a?(String)
      
      # Split by newline and create a hash from key=value pairs
      @parsed_response = {}
      response.each_line do |line|
        key, value = line.strip.split('=', 2)
        @parsed_response[key] = value if key && value
      end
      
      @code = @parsed_response['statuscode']
      @message_id = @parsed_response['msgid']
      @account_point = @parsed_response['AccountPoint']
      @error = @parsed_response['Error']
    end
  end
end
