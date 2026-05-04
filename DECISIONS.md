# LoqClock Decisions

This file captures product decisions that are already settled, so future implementation sessions do not reopen them accidentally.

## Naming

- product name: `LoqClock`
- repository name: `LoqClock`

## Product Shape

- macOS menu bar app
- local only
- menu bar icon only
- no menu bar text

## MVP Decisions

- default target work duration for a normal work day: `8h`
- default lunch duration for a normal work day: `1h`
- both values are configurable and overridable per day
- user can set shorter days such as `4h` target work for half days
- no automatic holiday detection
- no vacation tracking feature
- if a day has no entry, that day contributes `0 expected hours`
- lunch handling is manual with a default of `1h` and per-day override
- import/export is part of MVP
- supported import/export formats:
  - JSON
  - CSV

## Explicit Non-MVP Decisions

- no cloud sync
- no multi-device sync
- no shortcuts integration
- no flexible weekly contracts
- no public holiday detection
- no vacation day system
- no reminders/notifications in MVP
- no statistics/charts/graphs/tables in MVP

## MVP 2.0 Bucket

- reminders / notifications
- statistics
- charts
- graphs
- tables
- advanced analytics

## UX Decisions

- follow the latest Apple Human Interface Guidelines
- prefer native macOS conventions
- use a premium, lightweight, fast-feeling menu bar experience
- use Apple-style liquid glass / material treatments where appropriate

## Source Of Truth

For implementation details, use `PRODUCT_SPEC.md`.
