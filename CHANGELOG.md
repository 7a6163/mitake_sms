# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
