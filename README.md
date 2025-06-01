# MitakeSms

[![codecov](https://codecov.io/gh/7a6163/mitake_sms/graph/badge.svg?token=QNRP1N3TOP)](https://codecov.io/gh/7a6163/mitake_sms)
![Gem Version](https://img.shields.io/gem/v/mitake_sms)


A Ruby client for the Mitake SMS API, providing a simple and efficient way to send SMS messages through the Mitake SMS service.

## Features

- Send single SMS messages
- Send batch SMS messages with automatic handling of the 500 message API limit
- UTF-8 encoding support by default
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
# Send a simple SMS (uses UTF-8 encoding by default)
response = MitakeSms.send_sms(to: '0912345678', text: 'Hello, this is a test message!')

if response.success?
  puts "Message sent successfully! Message ID: #{response.message_id}"
  puts "Remaining points: #{response.account_point}"
else
  puts "Failed to send message: #{response.error}"
end

# With additional options
response = MitakeSms.send_sms(
  to: '0912345678',
  text: 'Hello with options!',
  destname: 'John Doe',  # Recipient name or integration key value
  response_url: 'https://your-callback-url.com/delivery-reports',
  client_id: 'your-client-reference-id',
  charset: 'BIG5'  # Override the default UTF-8 encoding if needed
)
```

### Sending Multiple SMS in Batch

```ruby
messages = [
  { to: '0912345678', text: 'First message' },
  { to: '0922333444', text: 'Second message', from: 'YourBrand' },
  { to: '0933555777', text: 'Third message', response_url: 'https://your-callback-url.com/reports' }
]

# Automatically handles batches according to the Mitake SMS API limit (500 messages per request)
# If you send more than 500 messages, they will be automatically split into multiple requests
# Uses UTF-8 encoding by default
response = MitakeSms.batch_send(messages)

# You can specify a different character encoding if needed
response = MitakeSms.batch_send(messages, charset: 'BIG5')

# If fewer than 500 messages, you'll get a single response
if response.is_a?(MitakeSms::Response) && response.success?
  puts "Batch sent successfully!"
  puts "Message ID: #{response.message_id}"
  puts "Remaining points: #{response.account_point}"

# If more than 500 messages, you'll get an array of responses
elsif response.is_a?(Array)
  response.each_with_index do |batch_response, index|
    if batch_response.success?
      puts "Batch #{index + 1} sent successfully!"
      puts "Message ID: #{batch_response.message_id}"
      puts "Remaining points: #{batch_response.account_point}"
    else
      puts "Batch #{index + 1} failed: #{batch_response.error}"
    end
  end
else
  puts "Failed to send batch: #{response.error}"
end
```

### Sending Large Batches with Custom Limit

```ruby
# Create a large batch of messages
messages = (1..1000).map do |i|
  { to: '0912345678', text: "Message #{i}" }
end

# The Mitake SMS API has a limit of 500 messages per request
# However, you can set a lower limit if needed for your use case
# This will split into batches of 300 messages each
# Uses UTF-8 encoding by default
responses = MitakeSms.batch_send_with_limit(messages, 300)

# You can specify a different character encoding if needed
responses = MitakeSms.batch_send_with_limit(messages, 300, charset: 'BIG5')

# Process the array of responses
responses.each_with_index do |batch_response, index|
  if batch_response.success?
    puts "Batch #{index + 1} sent successfully!"
  else
    puts "Batch #{index + 1} failed: #{batch_response.error}"
  end
end
```

### Sending Batch SMS with Advanced Format

The batch_send method now uses the advanced format by default, which provides more control over each message in the batch, including scheduled delivery, validity period, recipient name, and more:

```ruby
# Create messages with advanced options
messages = [
  {
    client_id: 'unique-id-20250525-001', # Client reference ID (auto-generated if not provided)
    to: '0912345678',                    # Required recipient phone number
    dlvtime: '20250526120000',           # Optional delivery time (YYYYMMDDhhmmss)
    vldtime: '20250527120000',           # Optional validity period (YYYYMMDDhhmmss)
    destname: '大寶',                    # Optional recipient name
    response_url: 'https://callback.url', # Optional callback URL
    text: '這是一則測試簡訊'             # Required message content
  },
  {
    # client_id will be auto-generated if not provided
    to: '0922333444',
    text: '這是另一則測試簡訊'
    # Other fields are optional
  }
]

# Note about ClientID:
# - ClientID is used by Mitake to prevent duplicate message sending within 12 hours
# - If not provided, a unique ID will be automatically generated using timestamp and random values
# - For custom tracking, you can provide your own unique ClientID
#
# Note about message text formatting:
# - If your message text contains line breaks (\n), they will be automatically converted
#   to ASCII code 6 as required by the Mitake API
# - Example: "First line\nSecond line" will be properly displayed with a line break on the recipient's device
# - Special characters like '&' are automatically URL encoded to ensure proper transmission
# - Long messages will be automatically split into multiple SMS messages if your account doesn't
#   have long message permissions

# Send using batch_send (automatically handles the advanced format)
response = MitakeSms.batch_send(messages)

# Process response similar to regular batch sending
if response.is_a?(MitakeSms::Response) && response.success?
  puts "Advanced batch sent successfully!"
  puts "Message ID: #{response.message_id}"
  puts "Remaining points: #{response.account_point}"
elsif response.is_a?(Array)
  response.each_with_index do |batch_response, index|
    if batch_response.success?
      puts "Batch #{index + 1} sent successfully!"
    else
      puts "Batch #{index + 1} failed: #{batch_response.error}"
    end
  end
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
