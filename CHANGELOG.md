# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
