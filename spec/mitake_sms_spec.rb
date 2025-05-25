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

  describe '.configure' do
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

    it 'delegates to client' do
      client = instance_double(MitakeSms::Client)
      allow(MitakeSms).to receive(:client).and_return(client)

      expect(client).to receive(:send_sms).with(to: to, text: text, response_url: nil, client_id: nil, charset: 'UTF8')

      MitakeSms.send_sms(to: to, text: text)
    end
  end

  describe '.batch_send' do
    let(:messages) do
      [
        { to: '0912345678', text: 'Message 1' },
        { to: '0922333444', text: 'Message 2' }
      ]
    end

    it 'delegates to client with default options' do
      client = instance_double(MitakeSms::Client)
      allow(MitakeSms).to receive(:client).and_return(client)

      expect(client).to receive(:batch_send_with_limit).with(messages, 500, {})

      MitakeSms.batch_send(messages)
    end

    it 'delegates to client with custom options' do
      client = instance_double(MitakeSms::Client)
      allow(MitakeSms).to receive(:client).and_return(client)
      options = { charset: 'BIG5' }

      expect(client).to receive(:batch_send_with_limit).with(messages, 500, options)

      MitakeSms.batch_send(messages, options)
    end
  end

  describe '.batch_send_with_limit' do
    let(:messages) do
      [
        { to: '0912345678', text: 'Message 1' },
        { to: '0922333444', text: 'Message 2' }
      ]
    end
    let(:limit) { 10 }

    it 'delegates to client with the specified limit' do
      client = instance_double(MitakeSms::Client)
      allow(MitakeSms).to receive(:client).and_return(client)

      expect(client).to receive(:batch_send_with_limit).with(messages, limit, {})

      MitakeSms.batch_send_with_limit(messages, limit)
    end

    it 'uses default limit when not specified' do
      client = instance_double(MitakeSms::Client)
      allow(MitakeSms).to receive(:client).and_return(client)

      expect(client).to receive(:batch_send_with_limit).with(messages, 500, {})

      MitakeSms.batch_send_with_limit(messages)
    end

    it 'delegates to client with options' do
      client = instance_double(MitakeSms::Client)
      allow(MitakeSms).to receive(:client).and_return(client)
      options = { charset: 'BIG5' }

      expect(client).to receive(:batch_send_with_limit).with(messages, limit, options)

      MitakeSms.batch_send_with_limit(messages, limit, options)
    end
  end
end
