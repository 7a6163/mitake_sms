# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'ClientID generation and handling' do
  let(:client) { MitakeSms::Client.new }
  let(:stubs) { Faraday::Adapter::Test::Stubs.new }
  let(:connection) do
    Faraday.new do |builder|
      builder.adapter :test, stubs
    end
  end

  before do
    MitakeSms.configure do |c|
      c.username = 'test_username'
      c.password = 'test_password'
      c.api_url = 'https://test.api.mitake.com.tw/'
    end

    allow_any_instance_of(MitakeSms::Client).to receive(:build_connection).and_return(connection)
  end

  describe '#generate_unique_client_id' do
    it 'generates a unique client ID' do
      client_id = client.send(:generate_unique_client_id)
      
      # Should be in format: YYYYMMDDHHMMSSmmm-xxxxxxxx
      expect(client_id).to match(/^\d{17}-[a-f0-9]{8}$/)
    end

    it 'generates different IDs on each call' do
      client_id1 = client.send(:generate_unique_client_id)
      client_id2 = client.send(:generate_unique_client_id)
      
      expect(client_id1).not_to eq(client_id2)
    end
  end

  describe 'advanced batch SMS with ClientID' do
    context 'when client_id is provided' do
      it 'uses the provided client_id' do
        messages = [
          { 
            client_id: 'custom-id-123',
            to: '0912345678', 
            text: 'Test message'
          }
        ]

        stubs.post('SmPost') do |env|
          # The data should include the custom client ID
          expect(env.body[:data]).to include('custom-id-123')
          [200, { 'Content-Type' => 'text/plain' }, "statuscode=1\nmsgid=1234567890\nAccountPoint=97"]
        end

        response = client.advanced_batch_send(messages)
        expect(response).to be_success
      end
    end

    context 'when client_id is not provided' do
      it 'generates a unique client_id automatically' do
        messages = [
          { 
            to: '0912345678', 
            text: 'Test message'
          }
        ]

        stubs.post('SmPost') do |env|
          # The data should include a generated client ID in the correct format
          client_id_pattern = /\d{17}-[a-f0-9]{8}/
          expect(env.body[:data]).to match(client_id_pattern)
          [200, { 'Content-Type' => 'text/plain' }, "statuscode=1\nmsgid=1234567890\nAccountPoint=97"]
        end

        response = client.advanced_batch_send(messages)
        expect(response).to be_success
      end
    end

    context 'when client_id is empty' do
      it 'generates a unique client_id automatically' do
        messages = [
          { 
            client_id: '',
            to: '0912345678', 
            text: 'Test message'
          }
        ]

        stubs.post('SmPost') do |env|
          # The data should include a generated client ID in the correct format
          client_id_pattern = /\d{17}-[a-f0-9]{8}/
          expect(env.body[:data]).to match(client_id_pattern)
          [200, { 'Content-Type' => 'text/plain' }, "statuscode=1\nmsgid=1234567890\nAccountPoint=97"]
        end

        response = client.advanced_batch_send(messages)
        expect(response).to be_success
      end
    end
  end
end
