# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MitakeSms::Client do
  let(:config) { MitakeSms::Configuration.new }

  before do
    MitakeSms.configure do |c|
      c.username = 'test_username'
      c.password = 'test_password'
      c.api_url = 'https://test.mitake.com.tw/'
      c.timeout = 30
      c.open_timeout = 5
    end
  end

  let(:client) { described_class.new }
  let(:stubs) { Faraday::Adapter::Test::Stubs.new }
  let(:connection) do
    Faraday.new do |builder|
      builder.adapter :test, stubs
    end
  end

  before do
    allow_any_instance_of(described_class).to receive(:build_connection).and_return(connection)
  end

  describe '#send_sms' do
    let(:to) { '0912345678' }
    let(:text) { 'Test message' }

    context 'when the request is successful' do
      before do
        stubs.post('SmSend') do |env|
          expect(env.url.path).to eq('/SmSend')
          # Check for query parameters - only CharsetURL should be in query string
          expect(env.params['CharsetURL']).to eq('UTF8')
          expect(env.params['username']).to be_nil
          expect(env.params['password']).to be_nil

          # Check for form parameters - all other parameters should be in POST body
          expect(env.body[:username]).to eq('test_username')
          expect(env.body[:password]).to eq('test_password')
          expect(env.body[:dstaddr]).to eq(to)
          expect(env.body[:smbody]).to eq('Test message')
          expect(env.body[:destname]).to be_nil

          [
            200,
            { 'Content-Type' => 'text/plain' },
            "statuscode=1\nmsgid=1234567890\nAccountPoint=100"
          ]
        end
      end

      it 'sends an SMS and returns a successful response' do
        response = client.send_sms(to: to, text: text)

        expect(response).to be_success
        expect(response.message_id).to eq('1234567890')
        expect(response.account_point).to eq('100')
      end

      it 'sends an SMS with destname and returns a successful response' do
        destname = 'Test User'
        # Create a new stub for this specific test case
        new_stubs = Faraday::Adapter::Test::Stubs.new
        new_connection = Faraday.new do |builder|
          builder.adapter :test, new_stubs
        end
        allow_any_instance_of(described_class).to receive(:build_connection).and_return(new_connection)
        
        new_stubs.post('SmSend') do |env|
          # Check for destname in the body
          expect(env.body[:destname]).to eq(destname)
          [200, { 'Content-Type' => 'text/plain' }, "statuscode=1\nmsgid=1234567890\nAccountPoint=100"]
        end

        response = client.send_sms(to: to, text: text, destname: destname)

        expect(response).to be_success
        expect(response.message_id).to eq('1234567890')
        expect(response.account_point).to eq('100')
      end

      it 'maps response_url and client_id to the API field names' do
        new_stubs = Faraday::Adapter::Test::Stubs.new
        new_connection = Faraday.new { |builder| builder.adapter :test, new_stubs }
        allow_any_instance_of(described_class).to receive(:build_connection).and_return(new_connection)

        new_stubs.post('SmSend') do |env|
          expect(env.body[:response]).to eq('https://example.com/callback')
          expect(env.body[:clientid]).to eq('abc-123')
          expect(env.body).not_to have_key(:response_url)
          expect(env.body).not_to have_key(:client_id)
          [200, { 'Content-Type' => 'text/plain' }, "statuscode=1\nmsgid=1234567890\nAccountPoint=100"]
        end

        response = client.send_sms(
          to: to,
          text: text,
          response_url: 'https://example.com/callback',
          client_id: 'abc-123'
        )

        expect(response).to be_success
      end
    end

    context 'when the connection fails' do
      before do
        stubs.post('SmSend') { raise Faraday::ConnectionFailed, 'connection refused' }
      end

      it 'lets the Faraday error through so callers can retry on its class' do
        expect { client.send_sms(to: to, text: text) }.to raise_error(Faraday::ConnectionFailed)
      end
    end

    context 'when authentication fails' do
      before do
        stubs.post('SmSend') { [401, {}, ''] }
      end

      it 'raises an AuthenticationError' do
        expect {
          client.send_sms(to: to, text: text)
        }.to raise_error(MitakeSms::Client::AuthenticationError)
      end
    end
  end

  describe '#batch_send' do
    let(:messages) do
      [
        { to: '0912345678', text: 'Message 1' },
        { to: '0922333444', text: 'Message 2' }
      ]
    end

    # Faraday test stubs match in registration order, so each example registers
    # its own rather than inheriting one from an enclosing before block.
    def stub_bulk_send(body = "statuscode=1\nmsgid=1234567890\nAccountPoint=98", &capture)
      stubs.post('SmBulkSend') do |env|
        capture&.call(env)
        [200, { 'Content-Type' => 'text/plain' }, body]
      end
    end

    before { allow(client).to receive(:generate_unique_client_id).and_return('test-client-id') }

    context 'when the request is successful' do
      it 'sends the credentials and charset in the query string, per the API' do
        seen = nil
        stub_bulk_send { |env| seen = env }

        response = client.batch_send(messages)

        expect(seen.url.path).to eq('/SmBulkSend')
        expect(seen.params).to include(
          'username' => 'test_username',
          'password' => 'test_password',
          'Encoding_PostIn' => 'UTF8'
        )
        expect(seen.request_headers['Content-Type']).to eq('text/plain')
        expect(response).to be_success
        expect(response.message_id).to eq('1234567890')
        expect(response.account_point).to eq('98')
      end

      it 'lays the row out in the order the API documents' do
        sent = nil
        stub_bulk_send { |env| sent = env.body }

        client.batch_send(
          [{
            client_id: 'cid-1',
            to: '0912345678',
            dlvtime: '20250526120000',
            vldtime: '20250527120000',
            destname: 'Big Bao',
            response_url: 'https://callback.example/report',
            text: 'hello'
          }]
        )

        # ClientID $$ dstaddr $$ dlvtime $$ vldtime $$ destname $$ response $$ smbody
        expect(sent.split('$$')).to eq(
          [
            'cid-1', '0912345678', '20250526120000', '20250527120000',
            'Big Bao', 'https://callback.example/report', 'hello'
          ]
        )
      end

      it 'leaves optional fields empty rather than omitting them' do
        sent = nil
        stub_bulk_send { |env| sent = env.body }

        client.batch_send([{ to: '0912345678', text: 'hello' }])

        expect(sent).to eq('test-client-id$$0912345678$$$$$$$$$$hello')
      end

      it 'generates a client ID per row when none is given' do
        sent = nil
        allow(client).to receive(:generate_unique_client_id).and_return('id-a', 'id-b')
        stub_bulk_send { |env| sent = env.body }

        client.batch_send(messages)

        expect(sent.lines.map { |line| line.split('$$').first }).to eq(%w[id-a id-b])
      end

      it 'converts line breaks in the body to ASCII 6' do
        sent = nil
        stub_bulk_send { |env| sent = env.body }

        client.batch_send([{ to: '09', text: "line1\r\nline2\nline3\rline4" }])

        expect(sent).to end_with("line1\u0006line2\u0006line3\u0006line4")
      end

      it 'forwards other documented fields as query parameters' do
        params = nil
        stub_bulk_send("statuscode=1\nmsgid=1\nsmsPoint=2") { |env| params = env.params }

        response = client.batch_send(messages, smsPointFlag: '1', objectID: 'nightly')

        expect(params).to include('smsPointFlag' => '1', 'objectID' => 'nightly')
        expect(response.sms_point).to eq('2')
      end
    end

    context 'when a structural field contains a delimiter' do
      it 'rejects $$ in destname' do
        expect { client.batch_send([{ to: '09', destname: 'a$$b', text: 'hi' }]) }
          .to raise_error(ArgumentError, /messages\[0\]\[:destname\]/)
      end

      it 'rejects a line break in destname, which would otherwise split the row' do
        expect { client.batch_send([{ to: '09', text: 'ok' }, { to: '09', destname: "a\nb", text: 'hi' }]) }
          .to raise_error(ArgumentError, /messages\[1\]\[:destname\]/)
      end

      it 'allows $$ in the message body, which is the last field' do
        sent = nil
        stub_bulk_send { |env| sent = env.body }

        client.batch_send([{ to: '09', text: 'Price is $$100' }])

        expect(sent).to end_with('$$Price is $$100')
      end
    end

    context 'when the batch exceeds the API limit of 500' do
      let(:messages) { Array.new(501) { |i| { to: '0912345678', text: "Message #{i}" } } }

      it 'splits at 500 and returns one response per request' do
        sizes = []
        stubs.post('SmBulkSend') do |env|
          sizes << env.body.lines.size
          [200, {}, "statuscode=1\nmsgid=#{sizes.size}\nAccountPoint=98"]
        end

        responses = client.batch_send(messages)

        expect(sizes).to eq([500, 1])
        expect(responses.map(&:message_id)).to eq(%w[1 2])
        expect(responses).to all(be_a(MitakeSms::Response).and(be_success))
      end
    end
  end
end
