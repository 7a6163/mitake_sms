# frozen_string_literal: true

# 設定覆蓋率報告
require 'simplecov'
require 'simplecov-cobertura'

SimpleCov.start do
  add_filter '/spec/'
  add_filter '/vendor/'
  # 添加你想要測量覆蓋率的文件夾
  add_group 'Library', 'lib'
  
  # 設定輸出格式
  formatter SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::CoberturaFormatter # 生成 XML 格式報告
  ])
  
  # 設定覆蓋率報告的最小覆蓋率百分比
  minimum_coverage 80
end

require 'bundler/setup'
require 'mitake_sms'
require 'webmock/rspec'
require 'pry'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Clear configuration before each test
  config.before do
    MitakeSms.instance_variable_set(:@config, nil)
    MitakeSms.instance_variable_set(:@client, nil)
  end
end
