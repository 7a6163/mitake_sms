# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MitakeSms::Response do
  describe 'successful response' do
    let(:raw_response) { "statuscode=1\nmsgid=1234567890\nAccountPoint=100" }
    let(:response) { described_class.new(raw_response) }

    it 'parses the response correctly' do
      expect(response).to be_success
      expect(response.code).to eq('1')
      expect(response.message_id).to eq('1234567890')
      expect(response.account_point).to eq('100')
      expect(response.error).to be_nil
    end
  end

  describe 'error response' do
    let(:raw_response) { "statuscode=0\nError=Invalid username or password" }
    let(:response) { described_class.new(raw_response) }

    it 'parses the error response correctly' do
      expect(response).not_to be_success
      expect(response.code).to eq('0')
      expect(response.error).to eq('Invalid username or password')
      expect(response.message_id).to be_nil
      expect(response.account_point).to be_nil
    end
  end

  describe 'batch response' do
    let(:raw_response) do
      <<~RESPONSE
        statuscode=1
        msgid=1234567890,1234567891
        AccountPoint=98
      RESPONSE
    end
    let(:response) { described_class.new(raw_response) }

    it 'parses the batch response correctly' do
      expect(response).to be_success
      expect(response.code).to eq('1')
      expect(response.message_id).to eq('1234567890,1234567891')
      expect(response.account_point).to eq('98')
    end
  end
end
