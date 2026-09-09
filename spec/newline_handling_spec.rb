# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MitakeSms::Client do
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

  describe '#send_sms' do
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

    it 'transcodes a Big5 body to the UTF8 the API is told to expect' do
      stubs.post('SmSend') do |env|
        expect(env.body[:smbody].encoding).to eq(Encoding::UTF_8)
        expect(env.body[:smbody]).to eq('中文')
        [200, { 'Content-Type' => 'text/plain' }, "statuscode=1\nmsgid=1234567890"]
      end

      response = client.send_sms(to: to, text: '中文'.encode('BIG5'))
      expect(response).to be_success
    end
  end

  describe '#batch_send' do
    # The url_encoded middleware must not touch the text/plain batch body.
    it 'leaves characters that are significant in a query string alone' do
      sent = nil
      stubs.post('SmBulkSend') do |env|
        sent = env.body
        [200, { 'Content-Type' => 'text/plain' }, "statuscode=1\nmsgid=1234567890\nAccountPoint=98"]
      end

      client.batch_send(
        [
          { to: '0912345678', text: 'Message with & and ?' },
          { to: '0922333444', text: 'Another with + and =' }
        ]
      )

      expect(sent).to include('Message with & and ?').and include('Another with + and =')
    end
  end
end
