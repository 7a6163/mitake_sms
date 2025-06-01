# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Error handling and edge cases' do
  let(:client) { MitakeSms::Client.new }
  let(:stubs) { Faraday::Adapter::Test::Stubs.new }
  let(:connection) do
    Faraday.new do |builder|
      builder.adapter :test, stubs
    end
  end

  before do
    MitakeSms.configure do |c|
      c.username = 'test_username'
      c.password = 'test_password'
      c.api_url = 'https://test.mitake.com.tw/'
      c.timeout = 30
      c.open_timeout = 5
    end

    allow_any_instance_of(MitakeSms::Client).to receive(:build_connection).and_return(connection)
  end

  describe 'HTTP error handling' do
    let(:to) { '0912345678' }
    let(:text) { 'Test message' }

    it 'handles 400 Bad Request errors' do
      stubs.post('SmSend') { [400, {}, ''] }

      expect {
        client.send_sms(to: to, text: text)
      }.to raise_error(MitakeSms::Client::InvalidRequestError, 'Invalid request parameters')
    end

    it 'handles 500 Server errors' do
      stubs.post('SmSend') { [500, {}, ''] }

      expect {
        client.send_sms(to: to, text: text)
      }.to raise_error(MitakeSms::Client::ServerError, 'Server error: 500')
    end

    it 'handles other unexpected errors' do
      stubs.post('SmSend') { [418, {}, ''] }

      expect {
        client.send_sms(to: to, text: text)
      }.to raise_error(MitakeSms::Client::Error, 'Unexpected error: 418')
    end
  end

  describe 'batch_send edge cases' do
    it 'handles empty message array' do
      messages = []

      # Allow the client to generate unique client IDs for testing
      allow(client).to receive(:generate_unique_client_id).and_return('test-client-id')
      
      stubs.post('SmBulkSend') do |env|
        expect(env.body).to be_empty
        expect(env.params['username']).to eq('test_username')
        expect(env.params['password']).to eq('test_password')
        expect(env.params['Encoding_PostIn']).to eq('UTF8')
        [200, { 'Content-Type' => 'text/plain' }, "statuscode=1\nmsgid=1234567890\nAccountPoint=100"]
      end

      response = client.batch_send(messages)
      expect(response).to be_success
    end

    it 'handles messages with missing text' do
      messages = [
        { to: '0912345678' } # Missing text
      ]

      # Allow the client to generate unique client IDs for testing
      allow(client).to receive(:generate_unique_client_id).and_return('test-client-id')
      
      stubs.post('SmBulkSend') do |env|
        expect(env.body).to include('test-client-id')
        expect(env.body).to include('0912345678')
        expect(env.params['username']).to eq('test_username')
        expect(env.params['password']).to eq('test_password')
        expect(env.params['Encoding_PostIn']).to eq('UTF8')
        [200, { 'Content-Type' => 'text/plain' }, "statuscode=1\nmsgid=1234567890\nAccountPoint=100"]
      end

      response = client.batch_send(messages)
      expect(response).to be_success
    end
  end

  describe 'batch_send_with_limit edge cases' do
    it 'handles empty message array with limit' do
      messages = []
      limit = 300

      stubs.post('SmBulkSend') do |env|
        expect(env.body).to be_empty
        expect(env.params['username']).to eq('test_username')
        expect(env.params['password']).to eq('test_password')
        expect(env.params['Encoding_PostIn']).to eq('UTF8')
        [200, { 'Content-Type' => 'text/plain' }, "statuscode=1\nmsgid=1234567890\nAccountPoint=100"]
      end

      response = client.batch_send_with_limit(messages, limit)
      expect(response).to be_success
    end
  end

  describe 'configuration' do
    it 'uses configured timeout values' do
      MitakeSms.configure do |c|
        c.timeout = 60
        c.open_timeout = 10
      end

      expect(MitakeSms.config.timeout).to eq(60)
      expect(MitakeSms.config.open_timeout).to eq(10)
    end
  end
end
