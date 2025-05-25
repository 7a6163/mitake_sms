# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
