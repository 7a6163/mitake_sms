# frozen_string_literal: true

module MitakeSms
  class Response
    # 附錄一 / 附錄二：statuscode 對應說明
    STATUS_MESSAGES = {
      '0' => '預約傳送中',
      '1' => '已送達業者',
      '2' => '已送達業者',
      '4' => '已送達手機',
      '5' => '內容有錯誤',
      '6' => '門號有錯誤',
      '7' => '簡訊已停用',
      '8' => '逾時無送達',
      '9' => '預約已取消',
      '*' => '系統發生錯誤，請聯絡三竹資訊窗口人員',
      'a' => '簡訊發送功能暫時停止服務，請稍候再試',
      'b' => '簡訊發送功能暫時停止服務，請稍候再試',
      'c' => '請輸入帳號',
      'd' => '請輸入密碼',
      'e' => '帳號、密碼錯誤',
      'f' => '帳號已過期',
      'h' => '帳號已被停用',
      'k' => '無效的連線位址',
      'l' => '帳號已達到同時連線數上限',
      'm' => '必須變更密碼，在變更密碼前，無法使用簡訊發送服務',
      'n' => '密碼已逾期，在變更密碼前，將無法使用簡訊發送服務',
      'p' => '沒有權限使用外部Http程式',
      'r' => '系統暫停服務，請稍後再試',
      's' => '帳務處理失敗，無法發送簡訊',
      't' => '簡訊已過期',
      'u' => '簡訊內容不得為空白',
      'v' => '無效的手機號碼',
      'w' => '查詢筆數超過上限',
      'x' => '發送檔案過大，無法發送簡訊',
      'y' => '參數錯誤',
      'z' => '查無資料'
    }.freeze

    # 簡訊已被三竹收下或已送達。其餘 statuscode 皆視為失敗。
    ACCEPTED_STATUS_CODES = %w[0 1 2 4].freeze

    attr_reader :raw_response, :records, :account_point

    def initialize(raw_response)
      @raw_response = raw_response
      @records = []
      parse(raw_response)
    end

    def code
      first_record['statuscode']
    end

    def message_id
      first_record['msgid']
    end

    def client_id
      first_record['clientid']
    end

    def sms_point
      first_record['smsPoint']
    end

    def duplicate?
      first_record['Duplicate'] == 'Y'
    end

    def message_ids
      @records.map { |record| record['msgid'] }.compact
    end

    def success?
      return false if @records.empty?

      @records.all? { |record| accepted?(record) }
    end

    def error?
      !success?
    end

    def error
      return nil if success?

      failures = @records.reject { |record| accepted?(record) }
      return 'Empty or unparseable response' if failures.empty?

      failures.map { |record| describe(record) }.join('; ')
    end

    private

    def first_record
      @records.first || {}
    end

    def accepted?(record)
      ACCEPTED_STATUS_CODES.include?(record['statuscode'])
    end

    def describe(record)
      status = record['statuscode']
      description = "#{status || '?'} #{STATUS_MESSAGES.fetch(status, '未知的狀態')}"
      msgid = record['msgid']
      msgid ? "#{msgid}: #{description}" : description
    end

    def parse(response)
      return unless response.is_a?(String)

      response.each_line do |raw_line|
        case raw_line.strip
        # 每筆回覆以 [clientid] 開頭，例如 [1] 或 [my-guid]
        when /\A\[(.*)\]\z/
          @records << { 'clientid' => Regexp.last_match(1) }
        # AccountPoint 是整批回覆共用的餘額，不屬於任何單筆簡訊
        when /\AAccountPoint=(.*)\z/
          @account_point = Regexp.last_match(1)
        when /\A([^=]+)=(.*)\z/
          @records << {} if @records.empty?
          @records.last[Regexp.last_match(1)] = Regexp.last_match(2)
        end
      end
    end
  end
end
