# LoqClock Product / Engineering Spec

## Purpose

Build a local-only macOS menu bar app named `LoqClock`.

Primary job:
- help the user track work time
- compute overtime balances
- show when the user can leave to reach `0` overtime for today
- show when the user can leave to reach `0` overtime for the current week

This document is optimized for implementation by coding agents. Prefer explicit behavior over interpretation.

## Product Principles

- `local_only`: no cloud sync, no accounts, no server
- `fast`: all views must feel instant, with no loading spinners for normal use
- `minimal_menu_bar`: menu bar shows icon only, never time text
- `private`: all data stored on device
- `low_friction`: common actions should be available from the menu bar popover
- `native_macos`: visual design should align with modern macOS aesthetics, including Apple-style liquid glass material treatments where appropriate
- `follow_latest_apple_guidelines`: UI and UX decisions should follow the latest applicable Apple Human Interface Guidelines and current platform conventions for macOS

## Scope

### MVP

- menu bar icon only
- popover UI for today overview and balances
- manual time tracking
- default workday settings:
  - `target_work_duration = 8h`
  - `default_lunch_duration = 1h`
- per-day overrides:
  - override target work duration for a specific day
  - override lunch duration for a specific day
- overtime balances:
  - total
  - current week
  - current month
  - current year
- leave-time predictions:
  - leave time to end today at `0` daily overtime
  - leave time to end current week at `0` weekly overtime
- local persistence
- import and export:
  - JSON
  - CSV

### Explicitly Out Of MVP

- cloud sync
- multi-device sync
- public holiday detection
- vacation day management
- flexible weekly contracts
- shortcuts integration
- notifications/reminders
- charts/graphs/tables
- advanced analytics

### MVP 2.0

- statistics
- charts
- graphs
- tables
- reminders / notifications
- advanced analytics

## Core Domain Model

### Definitions

- `work day`: a calendar date that has a time entry
- `off day`: a calendar date with no time entry
- `target work duration`: expected net working time for a day, excluding lunch
- `lunch duration`: non-working break duration for a day
- `net worked duration`: elapsed worked time excluding lunch
- `daily balance`: `net worked duration - target work duration`
- `overtime balance`: accumulated sum of daily balances across a period

### Critical Rule

If a day has no start entry, it counts as `0 expected hours`.

Interpretation for implementation:
- do not auto-create expected workdays
- do not infer holiday/vacation/workday from weekday
- if there is no entry for a date, that date contributes:
  - `0 worked`
  - `0 expected`
  - `0 balance`

This rule applies to weekdays and weekends equally.

## Required Data Model

Use a simple local persistence model. The exact storage format can be chosen later, but the app must preserve these concepts.

### WorkDayEntry

- `date`: local calendar date in user timezone
- `start_time`: optional timestamp
- `end_time`: optional timestamp
- `target_work_duration_minutes`: integer
- `lunch_duration_minutes`: integer
- `notes`: optional string
- `created_at`
- `updated_at`

Behavior:
- a day is considered tracked if a `WorkDayEntry` exists
- `start_time` is expected for normal tracked days
- `end_time` may be missing while the user is still working
- per-day target and lunch values are stored on the entry so historical values remain stable even if defaults later change

### AppSettings

- `default_target_work_duration_minutes`
- `default_lunch_duration_minutes`
- `menu_bar_icon_style` if needed later
- import/export preferences if useful later

Defaults:
- `default_target_work_duration_minutes = 480`
- `default_lunch_duration_minutes = 60`

## Calculation Rules

### Net Worked Duration

For a completed day:
- `gross_duration = end_time - start_time`
- `net_worked_duration = gross_duration - lunch_duration`

For an in-progress day:
- `gross_duration = now - start_time`
- `net_worked_duration = gross_duration - lunch_duration`

Clamp rule:
- if subtraction would produce a negative value, clamp to `0`

### Daily Balance

- `daily_balance = net_worked_duration - target_work_duration`

Examples:
- worked `8h`, lunch `1h`, target `8h`, elapsed from `09:00` to `18:00`
  - gross `9h`
  - net `8h`
  - balance `0h`
- half day with target override `4h`, lunch override `0m`, elapsed `08:00` to `12:00`
  - gross `4h`
  - net `4h`
  - balance `0h`

### Period Balances

Balances must be computed for:
- `total`: sum of all tracked days
- `week`: sum of days in current calendar week
- `month`: sum of days in current calendar month
- `year`: sum of days in current calendar year

Use the user locale/calendar for week boundaries if straightforward. If not, default to the current macOS calendar settings.

### Leave Time Prediction: Zero Overtime Today

Goal:
- predict the `end_time` at which today's `daily_balance` becomes `0`

Formula:
- `leave_for_zero_today = start_time + lunch_duration + target_work_duration`

Only valid when:
- today's entry exists
- `start_time` exists

If current time is already past this leave time:
- still show the calculated time
- optionally indicate that the user is already in positive overtime

### Leave Time Prediction: Zero Overtime This Week

Goal:
- predict the `end_time` today at which the cumulative balance for the current week becomes `0`

Formula:
- `remaining_needed_today = max(0, -balance_before_finishing_today_with_current_progress_adjusted))`

Use this direct implementation approach instead:
1. compute current week balance excluding today's current partial progress
2. compute today's currently accumulated net worked duration
3. compute how much additional net work today is needed so:
   - `week_balance_after_today = 0`
4. convert required additional net work into leave time by adding lunch handling

Equivalent simplified formula:
- `required_net_work_today = target_work_duration - week_balance_before_today`
- `leave_for_zero_week = start_time + lunch_duration + required_net_work_today`

Where:
- `week_balance_before_today` = sum of daily balances for tracked days earlier this week

Interpretation:
- if the user already has positive weekly overtime, they may leave earlier than the normal zero-for-today time
- if the user has negative weekly balance, they must stay longer

Clamp/display rules:
- if `required_net_work_today < 0`, user has already covered the week before today; still compute a displayable result, but UI may show a supportive message like `weekly target already satisfied`
- if no `start_time` today, no leave prediction is available

## Editing Rules

### Default Behavior for a New Day

When creating today's entry:
- prefill `target_work_duration_minutes` from settings
- prefill `lunch_duration_minutes` from settings

### Manual Overrides

User must be able to override for a specific day:
- target work duration
- lunch duration
- start time
- end time

This is required for:
- skipped lunch
- extended lunch
- shorter or longer workday
- half-day work
- corrected historical entries

### No Automatic Break Detection

Lunch is modeled as:
- default `60` minutes
- manually overwritable per day

No automatic inference from idle time is required.

## UI Structure

### Menu Bar

- icon only
- no text
- click opens main popover

### Main Popover MVP Sections

Order from top to bottom:

1. `Today`
   - start time
   - end time or live in-progress state
   - target work duration
   - lunch duration
   - net worked duration
   - daily balance

2. `Leave Times`
   - leave at for `0 today`
   - leave at for `0 this week`

3. `Balances`
   - total
   - week
   - month
   - year

4. `Actions`
   - start day / set start time
   - end day / set end time
   - edit today
   - import
   - export
   - open settings

### Settings MVP

- default target work duration
- default lunch duration
- import options entry point if needed
- export options entry point if needed

### Visual Direction

- use native macOS components where possible
- follow the latest Apple Human Interface Guidelines and current macOS UX conventions
- use translucent / material-heavy surfaces consistent with Apple liquid glass direction
- prefer calm, premium visuals over dashboard density
- optimize for rapid scanning and minimal latency

## Import / Export

### Supported Formats

- JSON
- CSV

### Export Requirements

User chooses format.

Export must include enough data to fully reconstruct entries:
- date
- start time
- end time
- target work duration
- lunch duration
- notes if present

### Import Requirements

User chooses file.

Behavior:
- parse file
- validate rows/records
- preview is optional, not required for MVP
- import into local store

Conflict handling for MVP:
- if imported date already exists, prefer a simple explicit strategy such as:
  - `replace existing`
  - `skip existing`

Implementation may choose one simple strategy for MVP, but it must be deterministic and clearly surfaced in UI.

Recommended MVP strategy:
- prompt user to choose `replace` or `skip` before final import

## Error Handling

- invalid times must never crash the app
- malformed import files must produce actionable user-facing errors
- calculation failures should fall back safely and avoid corrupted balances
- persistence failures should be surfaced clearly

## Performance Expectations

- app launch should feel instant
- popover open should feel instant
- all balance calculations should be synchronous or effectively instant for personal-scale data
- avoid unnecessary async loading states for local operations

## Suggested Technical Direction

Preferred stack:
- Swift
- SwiftUI
- menu bar app architecture using `MenuBarExtra` or equivalent modern macOS-native approach
- local persistence using a lightweight local store

Persistence can be:
- JSON files
- SQLite
- SwiftData

Choose the option that yields:
- fast local reads
- stable history editing
- simple import/export support
- low implementation complexity

## Suggested Implementation Order

1. bootstrap menu bar app shell
2. implement local persistence model
3. implement settings with defaults
4. implement day entry creation/editing
5. implement daily calculations
6. implement period balances
7. implement leave-time predictions
8. implement popover UI
9. implement import/export
10. polish visuals and interaction latency

## Acceptance Criteria For MVP

- user can open app from menu bar icon
- user can create or edit today's entry
- user can override today's target work duration
- user can override today's lunch duration
- user can see daily balance
- user can see total/week/month/year balances
- user can see leave time for `0 today`
- user can see leave time for `0 this week`
- a date with no entry contributes `0 expected hours`
- data persists locally across app restarts
- user can export data as JSON
- user can export data as CSV
- user can import data from JSON
- user can import data from CSV

## Non-Goals

Do not add these unless explicitly requested:
- team features
- payroll logic
- tax logic
- HR workflows
- holiday calendars
- vacation tracking
- background network services

## Agent Notes

When implementing:
- preserve the `0 expected hours when no entry exists` rule exactly
- store per-day overrides on the entry, not only in settings
- avoid scope creep into HR-style absence logic
- optimize first for correctness of calculations, then for UI polish
- prefer simple explicit user flows over automation
