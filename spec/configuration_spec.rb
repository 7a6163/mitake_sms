# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MitakeSms::Configuration do
  # Reset configuration before each test
  before do
    # Store original values
    @original_username = ENV['MITAKE_USERNAME']
    @original_password = ENV['MITAKE_PASSWORD']
    
    # Clear environment variables
    ENV['MITAKE_USERNAME'] = nil
    ENV['MITAKE_PASSWORD'] = nil
    
    # Reset configuration to defaults
    MitakeSms::Configuration.username = nil
    MitakeSms::Configuration.password = nil
    MitakeSms::Configuration.api_url = 'https://smsapi.mitake.com.tw/api/mtk/'
    MitakeSms::Configuration.timeout = 30
    MitakeSms::Configuration.open_timeout = 5
  end
  
  # Restore original environment variables after each test
  after do
    ENV['MITAKE_USERNAME'] = @original_username
    ENV['MITAKE_PASSWORD'] = @original_password
  end
  describe 'default values' do
    it 'has default values' do
      expect(described_class.username).to be_nil
      expect(described_class.password).to be_nil
      expect(described_class.api_url).to eq('https://smsapi.mitake.com.tw/api/mtk/')
      expect(described_class.timeout).to eq(30)
      expect(described_class.open_timeout).to eq(5)
    end
  end

  describe 'configuring' do
    before do
      MitakeSms.configure do |config|
        config.username = 'test_user'
        config.password = 'test_pass'
        config.api_url = 'https://custom.api.url/'
        config.timeout = 60
        config.open_timeout = 10
      end
    end

    it 'allows setting values' do
      expect(described_class.username).to eq('test_user')
      expect(described_class.password).to eq('test_pass')
      expect(described_class.api_url).to eq('https://custom.api.url/')
      expect(described_class.timeout).to eq(60)
      expect(described_class.open_timeout).to eq(10)
    end
  end
end
