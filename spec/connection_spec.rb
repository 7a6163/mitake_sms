# frozen_string_literal: true

require 'spec_helper'

# Every other Client spec stubs #build_connection out, so this is the only place
# the real Faraday stack is assembled and exercised.
RSpec.describe MitakeSms::Client do
  describe 'the connection it builds' do
    subject(:connection) { described_class.new.send(:build_connection) }

    before do
      MitakeSms.configure do |c|
        c.username = 'built_user'
        c.password = 'built_pass'
        c.api_url = 'https://built.example/api/'
        c.timeout = 41
        c.open_timeout = 7
      end
    end

    it 'points at the configured api_url' do
      expect(connection.url_prefix.to_s).to eq('https://built.example/api/')
    end

    it 'applies both configured timeouts' do
      expect(connection.options.timeout).to eq(41)
      expect(connection.options.open_timeout).to eq(7)
    end

    it 'form-encodes the body and reaches the network through the adapter' do
      stub_request(:post, 'https://built.example/api/SmSend')
        .with(body: 'a=b')
        .to_return(status: 200, body: 'ok')

      response = connection.post('SmSend') { |req| req.body = { a: 'b' } }

      expect(response.body).to eq('ok')
    end

    it 'prefers a config passed to the constructor over the global one' do
      custom = Struct.new(:username, :password, :api_url, :timeout, :open_timeout)
                     .new('u', 'p', 'https://custom.example/', 11, 3)

      built = described_class.new(custom).send(:build_connection)

      expect(built.url_prefix.to_s).to eq('https://custom.example/')
      expect(built.options.timeout).to eq(11)
    end
  end
end
