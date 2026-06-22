# QMemo Cute Development Roadmap

## Next: Todo Foundation

- [ ] Introduce an explicit memo/todo content-type field when the home information architecture is redesigned; the current compatibility phase still routes through the existing `待办` category.
- [x] Define the first-stage todo item model: item text, completion state, creation time, and stable identifier.
- [x] Support creating, editing, completing, reopening, and locally persisting basic todo lists.
- [ ] Allow todo completion directly from the home list.
- [ ] Keep completed todos as history instead of deleting them automatically.
- [x] Convert existing `待办` memo content into list items by line when it is first opened in the dedicated todo editor.
- [x] Add optional date-time reminders for individual todo items using local notifications.
- [x] Add urgent todo reminders using AlarmKit system alarms on iOS 26+, with local-notification fallback on older systems.
- [x] Show the nearest active todo reminder as a live countdown in the existing Home card badge.
- [ ] Add list-level scheduling, repeated tasks, subtasks, and priority after item reminders are stable.

## Home Information Architecture

- [ ] Redesign the home information structure after the todo data model is stable.
- [ ] Use `全部 / 便签 / 待办` as the primary content filter.
- [ ] Keep life, study, inspiration, mood, and other categories as secondary filters.
- [ ] Group home content by date, such as today, yesterday, and earlier dates.
- [ ] Preserve existing search, create entry, card interactions, and bottom navigation behavior during the redesign.

## Calendar And Statistics

- [x] Replace the current category first-level page with a calendar/statistics page and rename its tab to `统计`.
- [x] Mark dates that contain memo or todo records.
- [x] Show monthly record days, memo count, completed todo count, weekly trend, and category totals.
- [ ] Open a daily detail view containing that day's memos and todos.

## Mood Tracking

- [ ] Add an optional manual mood selection to memo records.
- [ ] Store mood type, emoji, source (`manual` or `inferred`), and optional confidence.
- [ ] Display the day's primary mood on the calendar; manual daily mood takes priority.
- [ ] Show a normal record marker when a date has content but no mood.
- [ ] Exclude ordinary todo text from automatic mood inference.
- [ ] Add local keyword-based mood suggestions with user confirmation as the first inference phase.
- [ ] Evaluate on-device semantic analysis later; cloud analysis requires explicit user consent.

## Later Phases

- [ ] Add repeated tasks, subtasks, and priority after the basic todo workflow is stable.
- [ ] Continue sticker shape-aware text wrapping and rich-text edge-case testing.
- [ ] Complete settings, backup/migration, in-app purchase planning, and App Store release preparation.

## Delivery Order

1. Todo data model and persistence.
2. Basic todo create, edit, complete, and restore workflow.
3. Home information architecture redesign.
4. Calendar and monthly statistics.
5. Manual mood records.
6. Mood inference and advanced todo capabilities.
