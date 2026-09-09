# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
bin/setup                              # bundle install
bundle exec rspec                      # run all specs
bundle exec rspec spec/client_spec.rb  # one file
bundle exec rspec spec/client_spec.rb:42  # one example by line
bundle exec rspec --only-failures      # replay failures from .rspec_status
bin/console                            # IRB with the gem loaded
bundle exec rake install               # install the gem locally

bundle exec mutant run                 # mutation testing (all subjects)
bundle exec mutant run -- 'MitakeSms::Response*'   # one class
bundle exec mutant session subject 'MitakeSms::Response#parse'  # detail on last run
```

`rake spec` is **not** defined (the README is wrong); the Rakefile only pulls in
`bundler/gem_tasks`. Use `bundle exec rspec`.

SimpleCov enforces `minimum_coverage 80` in `spec/spec_helper.rb`, so a run that
passes every example can still exit non-zero on coverage.

`mutant run` exits non-zero while any mutation survives. `MitakeSms::Response` is
at **100%**; the whole gem is at **84.1%** (195 alive, all in `Client`,
`Configuration` and the `MitakeSms` module facade). Config lives in `.mutant.yml` — `usage: opensource`
is what keeps mutant free, and is only valid while this repo is public. SimpleCov
is skipped under mutant (`unless defined?(Mutant)` in `spec_helper`) because its
`at_exit` minimum-coverage check would fail every mutation run and clobber
`coverage/`.

Specs use WebMock — no request reaches Mitake. `spec_helper` resets
`MitakeSms.@config` and `@client` before each example, so the memoized client in
`MitakeSms.client` doesn't leak configuration between tests.

## Architecture

A single-purpose Faraday client for the Mitake (三竹) SMS HTTP API. Four files:

- `lib/mitake_sms.rb` — module-level facade (`send_sms`, `batch_send`) delegating
  to a memoized `Client`, plus a duplicate set of error classes that mirror the
  ones nested in `Client`. Rescue the `MitakeSms::Client::*` ones — those are
  what `handle_response` actually raises.
- `configuration.rb` — `Dry::Configurable` settings, defaulted from
  `MITAKE_USERNAME` / `MITAKE_PASSWORD`.
- `client.rb` — request building for both endpoints.
- `response.rb` — line-oriented parser for Mitake's reply format.

### The two endpoints differ in shape

`SmSend` posts a URL-encoded form with credentials in the body; `SmBulkSend`
posts `text/plain` with credentials in the **query string** (the API mandates
this — don't "fix" it, just don't log request URLs).

### Wire-format invariants that constrain edits

- A batch row is `client_id$$to$$dlvtime$$vldtime$$destname$$response_url$$smbody`,
  rows joined by `\n`. `STRUCTURAL_FIELDS` are validated to reject `$$` and line
  breaks (`ArgumentError`); `text` is exempt only because it is last on the row.
  Adding a field to the row means adding it to `STRUCTURAL_FIELDS` too.
- Line breaks in a message body become ASCII code 6 (`LINE_BREAK`) — this is the
  API's requirement, not an escape.
- Everything is transcoded to UTF-8 (`CHARSET = 'UTF8'`); Big5 is only a label to
  Mitake and produces mojibake.
- Batches over `BATCH_LIMIT` (500) split, and `batch_send` then returns an
  **array** of `Response` instead of one. Callers wrap in `Array(...)`.
- `client_id` is auto-generated per row when absent and must be unique, not just
  random: Mitake de-duplicates on it for 12 hours.

### Response parsing

A reply is `key=value` lines, with each record introduced by a `[clientid]` line
and a trailing `AccountPoint` shared by the whole reply. `Response` keeps every
record (`records`, `message_ids`), not just the first. `success?` requires at
least one record and every `statuscode` in `ACCEPTED_STATUS_CODES` (`0 1 2 4` —
`0` is 預約傳送中 and counts as success). An empty/unparseable body is a failure
with `error == 'Empty or unparseable response'`. `STATUS_MESSAGES` mirrors 附錄一/
附錄二 of the vendor PDFs checked into the repo root.

### Errors

HTTP status maps to `Client::AuthenticationError` (401), `InvalidRequestError`
(400), `ServerError` (5xx). Transport failures are deliberately left as raw
`Faraday::Error` subclasses so callers can retry timeouts alone — don't wrap them.

## Conventions

- `# frozen_string_literal: true` on every file; single-quoted strings in `lib/`.
- Comments explaining vendor-API quirks are load-bearing; keep them when editing.
- Ruby >= 3.3, tested on 3.3 / 3.4 / 4.0 in CI.
- Update `CHANGELOG.md` and `lib/mitake_sms/version.rb` together for releases;
  pushing a tag triggers `.github/workflows/publish.yml`.
