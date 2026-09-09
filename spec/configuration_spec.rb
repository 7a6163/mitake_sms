# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MitakeSms::Configuration do
  describe 'default values' do
    it 'has default values' do
      expect(described_class.username).to be_nil
      expect(described_class.password).to be_nil
      expect(described_class.api_url).to eq('https://smsapi.mitake.com.tw/api/mtk/')
      expect(described_class.timeout).to eq(30)
      expect(described_class.open_timeout).to eq(5)
    end
  end

  # MitakeSms.configure writes through the Dry config object, so the class-level
  # writers are only exercised when a caller uses them directly. Every value here
  # differs from the default, or an assignment that never happened would still pass.
  describe 'class-level writers' do
    it 'writes every setting through to the config' do
      described_class.username = 'writer_user'
      described_class.password = 'writer_pass'
      described_class.api_url = 'https://writer.example/'
      described_class.timeout = 61
      described_class.open_timeout = 11

      expect(described_class.username).to eq('writer_user')
      expect(described_class.password).to eq('writer_pass')
      expect(described_class.api_url).to eq('https://writer.example/')
      expect(described_class.timeout).to eq(61)
      expect(described_class.open_timeout).to eq(11)
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
