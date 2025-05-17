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
      if response.is_a?(String)
        # Handle single response
        parts = response.split('\n').map { |line| line.split('=') }.to_h
        @code = parts['statuscode']
        @message_id = parts['msgid']
        @account_point = parts['AccountPoint']
        @error = parts['Error']
      elsif response.is_a?(Array)
        # Handle batch response
        # TODO: Implement batch response parsing if needed
      end
    end
  end
end
