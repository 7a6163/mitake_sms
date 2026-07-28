# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.0.0] - 2026-07-28
### Changed
- Raised `required_ruby_version` to `>= 3.3.0`, from `>= 2.6.0`. CI now runs against
  3.3, 3.4 and ruby/head rather than 3.3 alone
- Raised the Faraday floor to `>= 2.14.3`, which is the oldest release without
  CVE-2026-54297 (`NestedParamsEncoder` recursion DoS), CVE-2026-33637 and
  CVE-2026-25765 (SSRF via protocol-relative URL host override). This drops support
  for the Faraday 1.x line, whose patched `1.10.6` cannot be expressed alongside the
  2.x floor in a single requirement

### Added
- `Response#message_ids`, `#client_id`, `#duplicate?`, `#sms_point` and `#records`, exposing the
  `[clientid]`, `Duplicate` and `smsPoint` fields the API returns but the parser previously dropped

### Fixed
- `batch_send` raises `ArgumentError` when a field other than `:text` contains `$$` or a line break.
  Both are `SmBulkSend` delimiters, so a `destname` holding either one silently shifted the remaining
  fields or split the row in two, corrupting that message and every field after it
- `batch_send` forwards options such as `:objectID` and `:smsPointFlag` to the API. It previously
  accepted and discarded everything except `:charset`, so `smsPoint` could never be requested
- Message bodies containing `\r\n` or a bare `\r` are now converted to ASCII code 6 like `\n` already
  was. A `\r\n` body previously kept a stray carriage return, and a `\r`-only body was left unconverted
- Message bodies are transcoded to UTF-8 before sending, so a Big5 or otherwise non-UTF-8 string
  arrives intact instead of as mojibake, and a batch mixing encodings no longer raises
  `Encoding::CompatibilityError` while being assembled
- `Response#success?` returns false for a reply containing no records at all, rather than reporting
  success off a vacuously true empty check
- `Response` now parses the reply as a list of records split on the `[clientid]` header, instead of
  flattening every line into one hash. A `SmBulkSend` reply previously kept only the last message's
  `msgid` and `statuscode`, silently discarding the result of every other message in the batch
- `Response#error` returns the documented reason for a failing `statuscode` (附錄二). It previously
  read an `Error` field that does not exist in the API, so it was always `nil`
- `Response#success?` accepts statuscode `0` (預約傳送中), `2` and `4` in addition to `1`. Scheduled
  sends were previously reported as failures. For a batch it is now true only if every record was
  accepted
- `Response#account_point` is read as a reply-level value rather than being attached to whichever
  record happened to be last
- `send_sms` now sends the callback URL as `response` and the dedup key as `clientid`, matching the
  Mitake API spec. They were previously sent as `response_url` and `client_id`, which the API ignores,
  so delivery report callbacks and 12-hour duplicate suppression never took effect

### Removed
- Removed `advanced_batch_send` and `advanced_batch_send_with_limit`. They posted to a `SmPost`
  endpoint that does not exist in the Mitake API, and passed recipient numbers and message bodies in
  the query string, which leaked them into access logs and broke on large batches due to URL length
  limits. Use `batch_send`, which implements the same `$$` format against `SmBulkSend`
- Removed the `charset` option from `send_sms` and `batch_send`. It only labelled the payload and
  never converted it, so `charset: 'BIG5'` sent UTF-8 bytes tagged as Big5, guaranteeing mojibake.
  Requests are now always UTF8 and non-UTF-8 input is transcoded for you
- Removed `batch_send_with_limit`. The 500 message cap is an API constraint rather than a tuning
  knob, and `batch_send` already applies it
- Dropped the `faraday-multipart` runtime dependency. The multipart middleware was registered after
  `url_encoded`, so it never handled a request, and the gem never sends file uploads

## [2.0.0] - 2025-05-26
### Changed
- Modified `send_batch` method to use the advanced format with $$ separators
- Updated batch SMS request to place data in the request body with 'text/plain' content type
- Updated tests to verify the new batch SMS request format

### Removed
- Removed `advanced_batch_send_with_limit` method to simplify the API surface

## [1.6.0] - 2025-05-25
### Added
- Added `destname` parameter to `send_sms` method for recipient name or system integration key value
- Added tests for the new `destname` parameter

## [1.5.3] - 2025-05-25
### Changed
- Updated the default API URL to `https://smsapi.mitake.com.tw/api/mtk/`
- Cleaned up whitespace in the codebase

## [1.5.2] - 2025-05-25
### Changed
- Modified `send_sms` method to keep only `CharsetURL` in query string and put all other parameters in POST body
- Updated tests to match the new parameter structure

## [1.5.1] - 2025-05-25
### Fixed
- Updated the API URL from `smsapi.mitake.com.tw` to `smsb2c.mitake.com.tw` to match the correct Mitake SMS API endpoint
- Fixed 404 errors when sending SMS messages

## [1.5.0] - 2025-05-25
### Added
- Added named parameters (keyword arguments) to `send_sms` method for improved readability and flexibility

### Changed
- Updated `send_sms` method to use named parameters instead of positional parameters
- Removed `from` parameter from `send_sms` method
- Updated tests to use named parameters for `send_sms` method

## [1.4.0] - 2025-05-25
### Changed
- Modified all batch SMS parameters to be sent as query string parameters instead of in the POST body
- Updated `send_batch` and `send_advanced_batch` methods to use query string parameters
- Modified tests to verify query string parameter handling for batch SMS

## [1.3.1] - 2025-05-25
### Changed
- Modified `CharsetURL` parameter to be sent as a query string parameter instead of a form parameter
- Updated tests to verify query string parameter handling

## [1.3.0] - 2025-05-25
### Changed
- Removed automatic URL encoding of message content
- Simplified message handling by only converting newlines to ASCII code 6
- Modified tests to match the updated implementation

## [1.2.0] - 2025-05-25
### Added
- Added proper handling of newlines in message text (converts to ASCII code 6)
- Added URL encoding for message content to handle special characters
- Added advanced batch SMS format support using ClientID $$ dstaddr $$ dlvtime $$ vldtime $$ destname $$ response $$ smbody
- Added automatic generation of unique ClientIDs for advanced batch SMS

### Changed
- Improved message formatting to comply with Mitake API requirements
- Enhanced test coverage to 92.81%

## [1.1.0] - 2025-05-24
### Added
- Added automatic handling of the 500 message limit for batch SMS sending
- Added UTF-8 encoding support by default for all SMS messages
- Added `CharsetURL` parameter for single SMS messages
- Added `Encoding_PostIn` parameter for batch SMS messages
- Added ability to customize character encoding via options

### Changed
- Updated documentation to reflect new encoding options
- Improved batch sending with automatic splitting of large batches

## [1.0.0] - 2025-05-24
### Added
- Initial stable release
- Added SMS sending functionality
- Support for both single and batch SMS sending
- Basic error handling and configuration system
- SimpleCov and SimpleCov-Cobertura for code coverage reporting
- GitHub Actions workflow for automated testing and code coverage
- Codecov integration with coverage badge in README

### Changed
- Refactored configuration system using `Dry::Configurable`
- Updated error handling with error classes under `MitakeSms::Client` namespace
- Updated `.gitignore` to exclude `.rspec_status`

### Fixed
- Fixed `method_missing` issue in configuration system
- Fixed error class references in tests
