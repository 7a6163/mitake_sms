# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MitakeSms do
  before do
    MitakeSms.configure do |config|
      config.username = 'test_username'
      config.password = 'test_password'
      config.api_url = 'https://test.api.mitake.com.tw/'
      config.timeout = 30
      config.open_timeout = 5
    end
  end

  describe '.configure' do
    it 'sets the configuration' do
      expect(MitakeSms.config.username).to eq('test_username')
      expect(MitakeSms.config.password).to eq('test_password')
      expect(MitakeSms.config.api_url).to eq('https://test.api.mitake.com.tw/')
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
      
      expect(client).to receive(:send_sms).with(to, text, {})
      
      MitakeSms.send_sms(to, text)
    end
  end

  describe '.batch_send' do
    let(:messages) do
      [
        { to: '0912345678', text: 'Message 1' },
        { to: '0922333444', text: 'Message 2' }
      ]
    end

    it 'delegates to client' do
      client = instance_double(MitakeSms::Client)
      allow(MitakeSms).to receive(:client).and_return(client)
      
      expect(client).to receive(:batch_send).with(messages)
      
      MitakeSms.batch_send(messages)
    end
  end
end
