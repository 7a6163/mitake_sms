# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MitakeSms::Client do
  let(:config) { MitakeSms::Configuration.new }

  before do
    MitakeSms.configure do |c|
      c.username = 'test_username'
      c.password = 'test_password'
      c.api_url = 'https://test.api.mitake.com.tw/'
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
          # Check for query parameters
          expect(env.params['username']).to eq('test_username')
          expect(env.params['password']).to eq('test_password')
          expect(env.params['dstaddr']).to eq(to)
          expect(env.params['smbody']).to eq('Test message')
          expect(env.params['CharsetURL']).to eq('UTF8')
          # Body should be empty
          expect(env.body).to be_empty

          [
            200,
            { 'Content-Type' => 'text/plain' },
            "statuscode=1\nmsgid=1234567890\nAccountPoint=100"
          ]
        end
      end

      it 'sends an SMS and returns a successful response' do
        response = client.send_sms(to, text)

        expect(response).to be_success
        expect(response.message_id).to eq('1234567890')
        expect(response.account_point).to eq('100')
      end
    end

    context 'when authentication fails' do
      before do
        stubs.post('SmSend') { [401, {}, ''] }
      end

      it 'raises an AuthenticationError' do
        expect {
          client.send_sms(to, text)
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

    context 'when the request is successful' do
      before do
        stubs.post('SmBulkSend') do |env|
          expect(env.url.path).to eq('/SmBulkSend')
          # Check for query parameters
          expect(env.params['username']).to eq('test_username')
          expect(env.params['password']).to eq('test_password')
          expect(env.params['smbody']).to include('Message 1')
          expect(env.params['smbody']).to include('Message 2')
          expect(env.params['Encoding_PostIn']).to eq('UTF8')
          # Body should be empty
          expect(env.body).to be_empty

          [
            200,
            { 'Content-Type' => 'text/plain' },
            "statuscode=1\nmsgid=1234567890\nAccountPoint=98"
          ]
        end
      end

      it 'sends batch SMS and returns a successful response' do
        response = client.batch_send(messages)

        expect(response).to be_success
        expect(response.message_id).to eq('1234567890')
        expect(response.account_point).to eq('98')
      end
    end
  end

  describe '#batch_send_with_limit' do
    context 'when messages count is within the limit' do
      let(:messages) do
        [
          { to: '0912345678', text: 'Message 1' },
          { to: '0922333444', text: 'Message 2' }
        ]
      end

      before do
        stubs.post('SmBulkSend') do |env|
          expect(env.url.path).to eq('/SmBulkSend')
          # Check for query parameters
          expect(env.params['username']).to eq('test_username')
          expect(env.params['password']).to eq('test_password')
          expect(env.params['smbody']).to include('Message 1')
          expect(env.params['smbody']).to include('Message 2')
          expect(env.params['Encoding_PostIn']).to eq('UTF8')
          # Body should be empty
          expect(env.body).to be_empty

          [
            200,
            { 'Content-Type' => 'text/plain' },
            "statuscode=1\nmsgid=1234567890\nAccountPoint=98"
          ]
        end
      end

      it 'sends a single batch and returns a single response' do
        response = client.batch_send_with_limit(messages, 5)

        expect(response).to be_a(MitakeSms::Response)
        expect(response).to be_success
        expect(response.message_id).to eq('1234567890')
        expect(response.account_point).to eq('98')
      end
    end

    context 'when messages count exceeds the limit' do
      let(:messages) do
        [
          { to: '0912345678', text: 'Message 1' },
          { to: '0922333444', text: 'Message 2' },
          { to: '0933555666', text: 'Message 3' },
          { to: '0944666777', text: 'Message 4' }
        ]
      end

      before do
        # Set up counter to track which batch is being processed
        batch_counter = 0

        # Stub for both batches
        stubs.post('SmBulkSend') do |env|
          expect(env.url.path).to eq('/SmBulkSend')

          batch_counter += 1

          if batch_counter == 1
            # First batch should contain Message 1 and Message 2
            expect(env.params['username']).to eq('test_username')
            expect(env.params['password']).to eq('test_password')
            expect(env.params['smbody']).to include('Message 1')
            expect(env.params['smbody']).to include('Message 2')
            expect(env.params['Encoding_PostIn']).to eq('UTF8')
            # Body should be empty
            expect(env.body).to be_empty

            [
              200,
              { 'Content-Type' => 'text/plain' },
              "statuscode=1\nmsgid=1234567890\nAccountPoint=98"
            ]
          else
            # Second batch should contain Message 3 and Message 4
            expect(env.params['username']).to eq('test_username')
            expect(env.params['password']).to eq('test_password')
            expect(env.params['smbody']).to include('Message 3')
            expect(env.params['smbody']).to include('Message 4')
            expect(env.params['Encoding_PostIn']).to eq('UTF8')
            # Body should be empty
            expect(env.body).to be_empty

            [
              200,
              { 'Content-Type' => 'text/plain' },
              "statuscode=1\nmsgid=1234567891\nAccountPoint=96"
            ]
          end
        end
      end

      it 'splits into multiple batches and returns an array of responses' do
        responses = client.batch_send_with_limit(messages, 2)

        expect(responses).to be_an(Array)
        expect(responses.size).to eq(2)

        expect(responses[0]).to be_a(MitakeSms::Response)
        expect(responses[0]).to be_success
        expect(responses[0].message_id).to eq('1234567890')
        expect(responses[0].account_point).to eq('98')

        expect(responses[1]).to be_a(MitakeSms::Response)
        expect(responses[1]).to be_success
        expect(responses[1].message_id).to eq('1234567891')
        expect(responses[1].account_point).to eq('96')
      end
    end
  end
end
