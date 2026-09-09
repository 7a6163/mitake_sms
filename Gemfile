# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in mitake_sms.gemspec
gemspec

group :development, :test do
  # These gems are used for development but not included in the gem
  gem "irb"
  # pry loads ostruct, which is no longer a default gem as of Ruby 4.0
  gem "ostruct"
  # Mutation testing. Free under `usage: opensource` while this repo is public.
  gem "mutant-rspec"
end
