# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MitakeSms do
  before do
    MitakeSms.configure do |config|
      config.username = 'test_username'
      config.password = 'test_password'
      config.api_url = 'https://test.mitake.com.tw/'
      config.timeout = 30
      config.open_timeout = 5
    end
  end

  describe '.config' do
    # Configuration answers the same readers as its Dry config object, so
    # reading a setting through it would not notice the class being returned.
    it 'returns the Dry config object rather than the Configuration class' do
      expect(MitakeSms.config).to be(MitakeSms::Configuration.config)
    end
  end

  describe '.configure' do
    it 'is a no-op without a block' do
      expect { MitakeSms.configure }.not_to raise_error
    end

    it 'sets the configuration' do
      expect(MitakeSms.config.username).to eq('test_username')
      expect(MitakeSms.config.password).to eq('test_password')
      expect(MitakeSms.config.api_url).to eq('https://test.mitake.com.tw/')
      expect(MitakeSms.config.timeout).to eq(30)
      expect(MitakeSms.config.open_timeout).to eq(5)
    end
  end

  describe '.client' do
    it 'returns a client instance' do
      expect(MitakeSms.client).to be_a(MitakeSms::Client)
    end
  end

  describe '.send_sms' do
    let(:to) { '0912345678' }
    let(:text) { 'Test message' }
    let(:client) { instance_double(MitakeSms::Client) }

    before { allow(MitakeSms).to receive(:client).and_return(client) }

    it 'delegates to client' do
      expect(client).to receive(:send_sms)
        .with(to: to, text: text, destname: nil, response_url: nil, client_id: nil)

      MitakeSms.send_sms(to: to, text: text)
    end

    it 'delegates to client with destname' do
      expect(client).to receive(:send_sms)
        .with(to: to, text: text, destname: 'Test User', response_url: nil, client_id: nil)

      MitakeSms.send_sms(to: to, text: text, destname: 'Test User')
    end

    it 'delegates response_url and client_id' do
      expect(client).to receive(:send_sms)
        .with(to: to, text: text, destname: nil,
              response_url: 'https://example.com/callback', client_id: 'abc-123')

      MitakeSms.send_sms(
        to: to, text: text,
        response_url: 'https://example.com/callback', client_id: 'abc-123'
      )
    end

    it 'forwards any other documented field' do
      expect(client).to receive(:send_sms)
        .with(to: to, text: text, destname: nil, response_url: nil, client_id: nil, dlvtime: '20250526120000')

      MitakeSms.send_sms(to: to, text: text, dlvtime: '20250526120000')
    end
  end

  describe '.batch_send' do
    let(:messages) do
      [
        { to: '0912345678', text: 'Message 1' },
        { to: '0922333444', text: 'Message 2' }
      ]
    end
    let(:client) { instance_double(MitakeSms::Client) }

    before { allow(MitakeSms).to receive(:client).and_return(client) }

    it 'delegates to client with default options' do
      expect(client).to receive(:batch_send).with(messages, {})

      MitakeSms.batch_send(messages)
    end

    it 'delegates to client with custom options' do
      options = { smsPointFlag: '1' }

      expect(client).to receive(:batch_send).with(messages, options)

      MitakeSms.batch_send(messages, options)
    end
  end
end
