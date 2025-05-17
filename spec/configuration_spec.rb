# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MitakeSms::Configuration do
  describe 'default values' do
    it 'has default values' do
      expect(subject.username).to eq('')
      expect(subject.password).to eq('')
      expect(subject.api_url).to eq('https://smsapi.mitake.com.tw/api/mtk/')
      expect(subject.timeout).to eq(30)
      expect(subject.open_timeout).to eq(5)
    end
  end

  describe 'configuring' do
    it 'allows setting values' do
      subject.username = 'test_user'
      subject.password = 'test_pass'
      subject.api_url = 'https://custom.api.url/'
      subject.timeout = 60
      subject.open_timeout = 10

      expect(subject.username).to eq('test_user')
      expect(subject.password).to eq('test_pass')
      expect(subject.api_url).to eq('https://custom.api.url/')
      expect(subject.timeout).to eq(60)
      expect(subject.open_timeout).to eq(10)
    end
  end
end
