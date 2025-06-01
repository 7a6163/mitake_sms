# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Newline and special character handling' do
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
    end

    allow_any_instance_of(MitakeSms::Client).to receive(:build_connection).and_return(connection)
  end

  describe 'handling newlines in message text' do
    let(:to) { '0912345678' }
    let(:text_with_newlines) { "First line\nSecond line" }

    it 'converts newlines to ASCII code 6 in single SMS' do
      stubs.post('SmSend') do |env|
        # The newline should be converted to ASCII code 6
        expect(env.body[:smbody]).to include(6.chr)
        # Only CharsetURL should be in query parameters
        expect(env.params['CharsetURL']).to eq('UTF8')
        [200, { 'Content-Type' => 'text/plain' }, "statuscode=1\nmsgid=1234567890\nAccountPoint=100"]
      end

      response = client.send_sms(to: to, text: text_with_newlines)
      expect(response).to be_success
    end

    it 'converts newlines to ASCII code 6 in batch SMS' do
      messages = [
        { to: '0912345678', text: "First line\nSecond line" },
        { to: '0922333444', text: "Another\nmulti-line\nmessage" }
      ]

      # Allow the client to generate unique client IDs for testing
      allow(client).to receive(:generate_unique_client_id).and_return('test-client-id')
      
      stubs.post('SmBulkSend') do |env|
        # Both messages should have newlines converted to ASCII code 6
        expect(env.body).to include(6.chr)
        # Check for query parameters
        expect(env.params['username']).to eq('test_username')
        expect(env.params['password']).to eq('test_password')
        expect(env.params['Encoding_PostIn']).to eq('UTF8')
        [200, { 'Content-Type' => 'text/plain' }, "statuscode=1\nmsgid=1234567890\nAccountPoint=98"]
      end

      response = client.batch_send(messages)
      expect(response).to be_success
    end

    it 'converts newlines to ASCII code 6 in batch SMS with advanced options' do
      messages = [
        {
          client_id: 'test1',
          to: '0912345678',
          text: "First line\nSecond line",
          dlvtime: '202505251430',
          destname: 'Test User'
        }
      ]

      # Allow the client to use the provided client ID
      stubs.post('SmBulkSend') do |env|
        # The message should have newlines converted to ASCII code 6
        expect(env.body).to include(6.chr)
        expect(env.body).to include('test1')
        expect(env.body).to include('0912345678')
        expect(env.body).to include('202505251430')
        expect(env.body).to include('Test User')
        # Check for query parameters
        expect(env.params['username']).to eq('test_username')
        expect(env.params['password']).to eq('test_password')
        expect(env.params['Encoding_PostIn']).to eq('UTF8')
        [200, { 'Content-Type' => 'text/plain' }, "statuscode=1\nmsgid=1234567890\nAccountPoint=97"]
      end

      response = client.batch_send(messages)
      expect(response).to be_success
    end
  end

  describe 'handling special characters in message text' do
    let(:to) { '0912345678' }
    let(:text_with_special_chars) { "Message with & and ?" }

    it 'handles special characters in batch SMS' do
      messages = [
        { to: '0912345678', text: "Message with & and ?" },
        { to: '0922333444', text: "Another with + and =" }
      ]

      # Allow the client to generate unique client IDs for testing
      allow(client).to receive(:generate_unique_client_id).and_return('test-client-id')
      
      stubs.post('SmBulkSend') do |env|
        # Both messages should contain the special characters
        expect(env.body).to include("Message with & and ?")
        expect(env.body).to include("Another with + and =")
        # Check for query parameters
        expect(env.params['username']).to eq('test_username')
        expect(env.params['password']).to eq('test_password')
        expect(env.params['Encoding_PostIn']).to eq('UTF8')
        [200, { 'Content-Type' => 'text/plain' }, "statuscode=1\nmsgid=1234567890\nAccountPoint=98"]
      end

      response = client.batch_send(messages)
      expect(response).to be_success
    end
  end
end
