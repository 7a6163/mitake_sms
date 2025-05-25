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
        expect(env.params['smbody']).to include(6.chr)
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

      stubs.post('SmBulkSend') do |env|
        # Both messages should have newlines converted to ASCII code 6
        expect(env.params['smbody']).to include(6.chr)
        # Body should be empty
        expect(env.body).to be_empty
        [200, { 'Content-Type' => 'text/plain' }, "statuscode=1\nmsgid=1234567890\nAccountPoint=98"]
      end

      response = client.batch_send(messages)
      expect(response).to be_success
    end

    it 'converts newlines to ASCII code 6 in advanced batch SMS' do
      messages = [
        {
          client_id: 'test1',
          to: '0912345678',
          text: "First line\nSecond line",
          dlvtime: '202505251430',
          dest_name: 'Test User'
        }
      ]

      stubs.post('SmPost') do |env|
        # The message should have newlines converted to ASCII code 6
        expect(env.params['data']).to include(6.chr)
        # Body should be empty
        expect(env.body).to be_empty
        [200, { 'Content-Type' => 'text/plain' }, "statuscode=1\nmsgid=1234567890\nAccountPoint=97"]
      end

      response = client.advanced_batch_send(messages)
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

      stubs.post('SmBulkSend') do |env|
        # Both messages should contain the special characters
        expect(env.params['smbody']).to include("Message with & and ?")
        expect(env.params['smbody']).to include("Another with + and =")
        # Body should be empty
        expect(env.body).to be_empty
        [200, { 'Content-Type' => 'text/plain' }, "statuscode=1\nmsgid=1234567890\nAccountPoint=98"]
      end

      response = client.batch_send(messages)
      expect(response).to be_success
    end
  end
end
