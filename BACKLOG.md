# LoqClock Backlog

This repository uses GitHub issues as the implementation backlog.

## Current Issue Sequence

1. `#1` Bootstrap the macOS menu bar app shell
2. `#2` Implement local persistence and core domain models
3. `#3` Build the calculation engine for balances and leave-time predictions
4. `#4` Implement settings and per-day editing flows
5. `#6` Implement start/end tracking for today's session
6. `#5` Build the MVP menu bar popover UI
7. `#7` Implement JSON and CSV import/export
8. `#8` Polish the MVP for native feel, performance, and QA

## Notes

- `#5` and `#6` are intentionally separate.
- The recommended build order does `#6` before `#5` so the session interaction logic exists before the main UI is fully polished.
- Keep MVP 2.0 ideas out of implementation unless the user explicitly requests them.
