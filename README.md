# MitakeSms

[![codecov](https://codecov.io/gh/7a6163/mitake_sms/graph/badge.svg?token=QNRP1N3TOP)](https://codecov.io/gh/7a6163/mitake_sms)

A Ruby client for the Mitake SMS API, providing a simple and efficient way to send SMS messages through the Mitake SMS service.

## Features

- Send single SMS messages
- Send batch SMS messages
- Configurable API settings
- Simple and intuitive API
- Comprehensive error handling

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'mitake_sms', github: '7a6163/mitake_sms'
```

And then execute:

```bash
$ bundle install
```

Or install it yourself as:

```bash
$ gem install mitake_sms
```

## Usage

### Configuration

Before using the gem, you need to configure it with your Mitake SMS API credentials:

```ruby
require 'mitake_sms'

MitakeSms.configure do |config|
  config.username = 'your_username'  # Your Mitake SMS API username
  config.password = 'your_password'  # Your Mitake SMS API password
  config.api_url = 'https://smsapi.mitake.com.tw/api/mtk/'  # Default API URL
end
```

### Sending a Single SMS

```ruby
# Send a simple SMS
response = MitakeSms.send_sms('0912345678', 'Hello, this is a test message!')

if response.success?
  puts "Message sent successfully! Message ID: #{response.message_id}"
  puts "Remaining points: #{response.account_point}"
else
  puts "Failed to send message: #{response.error}"
end

# With additional options
response = MitakeSms.send_sms(
  '0912345678',
  'Hello with options!',
  from: 'YourBrand',
  response_url: 'https://your-callback-url.com/delivery-reports',
  client_id: 'your-client-reference-id'
)
```

### Sending Multiple SMS in Batch

```ruby
messages = [
  { to: '0912345678', text: 'First message' },
  { to: '0922333444', text: 'Second message', from: 'YourBrand' },
  { to: '0933555777', text: 'Third message', response_url: 'https://your-callback-url.com/reports' }
]

response = MitakeSms.batch_send(messages)

if response.success?
  puts "Batch sent successfully!"
  puts "Message ID: #{response.message_id}"
  puts "Remaining points: #{response.account_point}"
else
  puts "Failed to send batch: #{response.error}"
end
```

### Error Handling

The gem provides specific error classes for different types of errors:

```ruby
begin
  response = MitakeSms.send_sms('invalid', 'test')
rescue MitakeSms::Client::AuthenticationError => e
  puts "Authentication failed: #{e.message}"
rescue MitakeSms::Client::InvalidRequestError => e
  puts "Invalid request: #{e.message}"
rescue MitakeSms::Client::ServerError => e
  puts "Server error: #{e.message}"
rescue MitakeSms::Client::Error => e
  puts "An error occurred: #{e.message}"
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/7a6163/mitake_sms.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
