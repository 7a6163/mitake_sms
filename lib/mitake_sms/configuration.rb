# frozen_string_literal: true

require 'dry/configurable'

module MitakeSms
  class Configuration
    extend Dry::Configurable

    setting :username, ''
    setting :password, ''
    setting :api_url, 'https://smsapi.mitake.com.tw/api/mtk/'
    setting :timeout, 30
    setting :open_timeout, 5
  end

  class << self
    def configure
      yield(config) if block_given?
    end

    def config
      @config ||= Configuration.new
    end
  end
end
