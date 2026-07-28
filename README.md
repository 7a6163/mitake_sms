# MitakeSms

[![codecov](https://codecov.io/gh/7a6163/mitake_sms/graph/badge.svg?token=QNRP1N3TOP)](https://codecov.io/gh/7a6163/mitake_sms)
![Gem Version](https://img.shields.io/gem/v/mitake_sms)


A Ruby client for the Mitake SMS API, providing a simple and efficient way to send SMS messages through the Mitake SMS service.

## Features

- Send single SMS messages (`SmSend`)
- Send batch SMS messages (`SmBulkSend`) with automatic handling of the 500 message API limit
- Always sends UTF-8, transcoding input in other encodings
- Parses every record of a reply, not just the first
- Configurable API settings
- Comprehensive error handling

Status queries (`SmQuery`) and cancelling a scheduled send (`SmCancel`) are not
implemented yet. To learn whether a message reached the handset, have Mitake call
the `response_url` callback.

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
  config.timeout = 30       # Read timeout in seconds, default 30
  config.open_timeout = 5   # Connection timeout in seconds, default 5
end
```

The default `api_url` targets the HTTP API. If your account is provisioned for the
B2C variant, set the path to `/b2c/mtk/` instead; the endpoints are otherwise identical.

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
  destname: 'John Doe',  # Recipient name or integration key value (sent as `destname`)
  response_url: 'https://your-callback-url.com/delivery-reports', # Sent as `response`
  client_id: 'your-client-reference-id', # Sent as `clientid`, used by Mitake to de-duplicate
  dlvtime: '20250526120000',             # Any other documented SmSend field is forwarded as-is
  vldtime: '20250527120000'
)
```

Requests are always sent as UTF-8. Strings in another encoding are transcoded for
you, so `text: '中文'.encode('BIG5')` arrives intact.

### Sending Multiple SMS in Batch

Each message accepts the same fields as a single send. `client_id` is generated for
you when omitted; Mitake uses it to suppress duplicates within 12 hours.

```ruby
messages = [
  {
    client_id: 'unique-id-20250525-001', # Optional, auto-generated when absent
    to: '0912345678',                    # Required
    dlvtime: '20250526120000',           # Optional scheduled delivery (YYYYMMDDhhmmss)
    vldtime: '20250527120000',           # Optional validity deadline (YYYYMMDDhhmmss)
    destname: '大寶',                    # Optional recipient name
    response_url: 'https://callback.url', # Optional per-message callback
    text: '這是一則測試簡訊'             # Required
  },
  { to: '0922333444', text: '這是另一則測試簡訊' }
]

response = MitakeSms.batch_send(messages)

# Any other documented SmBulkSend field is forwarded as a query parameter
response = MitakeSms.batch_send(messages, smsPointFlag: '1', objectID: 'nightly-run')
```

Batches over 500 messages are split automatically, which is the API's per-request
limit. Under the limit you get one `Response`; over it you get an array of them.

```ruby
Array(response).each_with_index do |batch, index|
  if batch.success?
    puts "Batch #{index + 1} sent. Message IDs: #{batch.message_ids.join(', ')}"
    puts "Remaining points: #{batch.account_point}"
  else
    puts "Batch #{index + 1} failed: #{batch.error}"
  end
end
```

Line breaks in `text` are converted to ASCII code 6, as the API requires, so
`"First line\nSecond line"` renders as two lines on the handset. Messages longer
than one SMS are split by Mitake unless your account has long-message permission.

#### Delimiters in batch fields

The batch wire format separates fields with `$$` and rows with a newline. Either
one inside `client_id`, `to`, `dlvtime`, `vldtime`, `destname` or `response_url`
would shift every field after it, so `batch_send` raises `ArgumentError` naming
the offending message and field instead of sending a corrupted row:

```ruby
MitakeSms.batch_send([{ to: '0912345678', destname: 'A$$B', text: 'hi' }])
# => ArgumentError: messages[0][:destname] must not contain "$$" or a line break, ...
```

`text` is exempt because it is the last field on the row, so a message body may
contain `$$` freely. Mitake's documentation does not define an escape sequence,
though, so if a body containing `$$` ever comes back truncated, send it through
`send_sms` instead.

### Reading a Response

A batch reply contains one record per message, each introduced by a `[clientid]` line,
followed by an `AccountPoint` shared by the whole reply. A single send may omit the
`[clientid]` header; either shape is parsed the same way. `MitakeSms::Response` keeps
every record rather than collapsing them:

```ruby
response.success?      # true only if there is at least one record and every one was accepted
response.error?        # the inverse of success?
response.error         # nil on success, otherwise the documented reason for each failed record
response.code          # statuscode of the first record
response.message_id    # msgid of the first record
response.message_ids   # msgid of every record, for batch sends
response.client_id     # clientid of the first record
response.account_point # remaining points, shared by the whole reply
response.duplicate?    # true when Mitake suppressed a resend of the same clientid
response.sms_point     # points deducted, only present when smsPointFlag=1 was sent
response.records       # raw per-message hashes, if you need a field not listed above
response.raw_response  # the untouched reply body
```

Accepted status codes are `0`, `1`, `2` and `4`. An empty or unparseable body is not a
success, and `error` reports `'Empty or unparseable response'` for it.

Note that `statuscode=0` means 預約傳送中 (queued for scheduled delivery) and counts as a success.
Failures are the numeric codes `5`–`9` and the letter codes documented in 附錄二, such as `e`
(帳號、密碼錯誤) or `v` (無效的手機號碼).

### Error Handling

HTTP status codes are mapped to specific error classes, while transport failures are
raised as their original `Faraday::Error` subclass so you can retry on timeouts alone:

```ruby
begin
  response = MitakeSms.send_sms(to: '0912345678', text: 'test')
rescue MitakeSms::Client::AuthenticationError => e
  puts "Authentication failed: #{e.message}"
rescue MitakeSms::Client::InvalidRequestError => e
  puts "Invalid request: #{e.message}"
rescue MitakeSms::Client::ServerError => e
  puts "Server error: #{e.message}"
rescue Faraday::TimeoutError => e
  puts "Timed out, safe to retry: #{e.message}"
end
```

Note that `SmBulkSend` takes the username and password as query string parameters,
which the API mandates and the gem cannot avoid. They are protected in transit by
HTTPS, but if you log outbound request URLs, filter them at that layer.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/7a6163/mitake_sms.


## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
