# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MitakeSms::Client do
  let(:config) do
    MitakeSms::Configuration.new.tap do |c|
      c.username = 'test_username'
      c.password = 'test_password'
      c.api_url = 'https://test.api.mitake.com.tw/'
    end
  end

  let(:client) { described_class.new(config: config) }
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
        stubs.post('api/mtk/SmSend') do |env|
          expect(env.url.path).to eq('/api/mtk/SmSend')
          expect(env.body).to include("username=test_username")
          expect(env.body).to include("password=test_password")
          expect(env.body).to include("dstaddr=#{to}")
          
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
        stubs.post('api/mtk/SmSend') { [401, {}, ''] }
      end

      it 'raises an AuthenticationError' do
        expect {
          client.send_sms(to, text)
        }.to raise_error(MitakeSms::AuthenticationError)
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
        stubs.post('api/mtk/SmBulkSend') do |env|
          expect(env.url.path).to eq('/api/mtk/SmBulkSend')
          expect(env.body).to include("username=test_username")
          expect(env.body).to include("password=test_password")
          expect(env.body).to include("smbody=0912345678:Message 1\n0922333444:Message 2")
          
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
end
