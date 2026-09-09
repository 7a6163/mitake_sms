# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MitakeSms::Response do
  # 回覆範例取自 B2C/HTTP_MitakeAPI_v2.14 文件
  describe 'SmSend response' do
    let(:response) do
      described_class.new("[1]\nmsgid=#000000013\nstatuscode=1\nAccountPoint=126")
    end

    it 'parses the single record' do
      expect(response).to be_success
      expect(response).not_to be_error
      expect(response.error).to be_nil
      expect(response.code).to eq('1')
      expect(response.message_id).to eq('#000000013')
      expect(response.client_id).to eq('1')
      expect(response.account_point).to eq('126')
      expect(response.records.size).to eq(1)
    end

    it 'keeps the body untouched' do
      expect(response.raw_response).to eq("[1]\nmsgid=#000000013\nstatuscode=1\nAccountPoint=126")
    end
  end

  describe 'SmSend response without the [clientid] header' do
    let(:response) { described_class.new("statuscode=1\nmsgid=1234567890\nAccountPoint=100") }

    it 'still parses the key=value lines into one record' do
      expect(response).to be_success
      expect(response.code).to eq('1')
      expect(response.message_id).to eq('1234567890')
      expect(response.account_point).to eq('100')
    end
  end

  describe 'SmBulkSend response' do
    let(:response) do
      described_class.new(
        "[1]\nmsgid=#000000333\nstatuscode=0\n[2]\nmsgid=#000000334\nstatuscode=1\nAccountPoint=92"
      )
    end

    it 'keeps every record instead of collapsing them' do
      expect(response.records.size).to eq(2)
      expect(response.message_ids).to eq(['#000000333', '#000000334'])
      expect(response.records.map { |r| r['clientid'] }).to eq(%w[1 2])
    end

    it 'treats the shared AccountPoint as response level' do
      expect(response.account_point).to eq('92')
      expect(response.records.map { |r| r['AccountPoint'] }).to eq([nil, nil])
    end

    it 'is successful because 0 and 1 are both accepted' do
      expect(response).to be_success
      expect(response.error).to be_nil
    end
  end

  describe 'statuscode 0' do
    let(:response) { described_class.new("statuscode=0\nmsgid=#000000013") }

    it 'is a success because it means 預約傳送中' do
      expect(response).to be_success
    end
  end

  describe 'error statuscode' do
    let(:response) { described_class.new('statuscode=e') }

    it 'reports the documented reason' do
      expect(response).not_to be_success
      expect(response).to be_error
      expect(response.code).to eq('e')
      expect(response.error).to eq('e 帳號、密碼錯誤')
      expect(response.message_id).to be_nil
      expect(response.account_point).to be_nil
    end
  end

  describe 'partially failed batch' do
    let(:response) do
      described_class.new("[1]\nmsgid=#000000333\nstatuscode=1\n[2]\nstatuscode=v\nAccountPoint=92")
    end

    it 'is not successful and names only the failing record' do
      expect(response).not_to be_success
      expect(response.error).to eq('v 無效的手機號碼')
    end
  end

  describe 'undocumented statuscode' do
    let(:response) { described_class.new('statuscode=Q') }

    it 'falls back to an unknown status description' do
      expect(response).not_to be_success
      expect(response.error).to eq('Q 未知的狀態')
    end
  end

  describe 'Duplicate and smsPoint fields' do
    let(:response) do
      described_class.new("[abc]\nmsgid=#000000013\nstatuscode=1\nsmsPoint=2\nDuplicate=Y\nAccountPoint=126")
    end

    it 'exposes them' do
      expect(response).to be_duplicate
      expect(response.sms_point).to eq('2')
      expect(response.client_id).to eq('abc')
    end
  end

  describe 'non-duplicate response' do
    let(:response) { described_class.new("statuscode=1\nmsgid=#000000013") }

    it 'is not flagged as duplicate' do
      expect(response).not_to be_duplicate
    end

    it 'is not flagged as duplicate when Duplicate is present but not Y' do
      response = described_class.new("statuscode=1\nDuplicate=N")

      expect(response).not_to be_duplicate
    end
  end

  describe 'a reply carrying only a balance' do
    let(:response) { described_class.new('AccountPoint=110') }

    it 'reads the balance but does not report success without any record' do
      expect(response.account_point).to eq('110')
      expect(response.records).to be_empty
      expect(response).not_to be_success
      expect(response.error).to eq('Empty or unparseable response')
    end

    # Every per-record reader reads through an absent first record.
    it 'reads every record field as absent rather than raising' do
      expect(response.code).to be_nil
      expect(response.message_id).to be_nil
      expect(response.message_ids).to be_empty
      expect(response.client_id).to be_nil
      expect(response.sms_point).to be_nil
      expect(response).not_to be_duplicate
    end
  end

  describe 'a failing record carrying a msgid' do
    let(:response) { described_class.new("[1]\nmsgid=#000000013\nstatuscode=5") }

    it 'prefixes the reason with the msgid' do
      expect(response.error).to eq('#000000013: 5 內容有錯誤')
    end
  end

  describe 'a record with no statuscode at all' do
    let(:response) { described_class.new("[1]\nmsgid=#000000013") }

    it 'is a failure described with a placeholder status' do
      expect(response).not_to be_success
      expect(response.error).to eq('#000000013: ? 未知的狀態')
    end
  end

  describe 'several failing records' do
    let(:response) { described_class.new("[1]\nstatuscode=5\n[2]\nstatuscode=v") }

    it 'joins every reason' do
      expect(response.error).to eq('5 內容有錯誤; v 無效的手機號碼')
    end
  end

  describe 'a batch where one record has no msgid' do
    let(:response) { described_class.new("[1]\nmsgid=#000000333\nstatuscode=1\n[2]\nstatuscode=1") }

    it 'drops the missing msgid instead of yielding nil' do
      expect(response.message_ids).to eq(['#000000333'])
    end
  end

  describe 'line shapes' do
    it 'ignores whitespace around a line' do
      response = described_class.new("  statuscode=1  \nmsgid=1")

      expect(response).to be_success
    end

    it 'keeps an empty clientid header as its own record' do
      response = described_class.new("[]\nstatuscode=1")

      expect(response.client_id).to eq('')
      expect(response.records.size).to eq(1)
    end

    it 'keeps an empty AccountPoint out of the records' do
      response = described_class.new("[1]\nstatuscode=1\nAccountPoint=")

      expect(response.account_point).to eq('')
      expect(response.records.size).to eq(1)
    end

    it 'keeps a key with an empty value' do
      response = described_class.new('statuscode=')

      expect(response.code).to eq('')
      expect(response.records.size).to eq(1)
    end
  end

  describe 'empty or unparseable response' do
    it 'fails on an empty body' do
      response = described_class.new('')

      expect(response).not_to be_success
      expect(response.error).to eq('Empty or unparseable response')
    end

    it 'fails on a non-string body' do
      response = described_class.new(nil)

      expect(response).not_to be_success
      expect(response.records).to be_empty
    end

    # A truthy non-String must be rejected by the type check, not merely by being falsy.
    it 'fails on a truthy body that is not a string' do
      response = described_class.new(123)

      expect(response).not_to be_success
      expect(response.records).to be_empty
      expect(response.raw_response).to eq(123)
    end

    # A String subclass is still a body worth parsing.
    it 'parses a String subclass body' do
      response = described_class.new(Class.new(String).new('statuscode=1'))

      expect(response).to be_success
    end
  end
end
