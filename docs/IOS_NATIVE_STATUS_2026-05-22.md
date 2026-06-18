# iOS Native Status - 2026-05-22

## Project Goal

- QMemo Cute / 记忆兔备忘录 is moving from the React Native reference app to a native SwiftUI iOS app for App Store release.
- Active branch: `main`; `ios-native` remains synchronized as the native development mirror.
- Native project: `NativeIOS/QMemoCute.xcodeproj`.
- Main visual and code reference: `docs/CODE_STYLE_GUIDE.md` plus the existing React Native implementation under `app/` and `src/`.

## Confirmed Direction

- Continue native SwiftUI development instead of H5/WebView.
- Preserve the existing Q-style design language: soft cream background, rounded sticky-note cards, sticker PNG assets, gentle animation, and blurred modal backdrops.
- Keep homepage core interactions native: search, category filter, memo card actions, bottom tabs, and create menu morph animation.
- Asset replacements must be copied into `NativeIOS/QMemoCute/Assets.xcassets`; do not rely on desktop-only file paths.

## Today Completed

- Replaced the header text logo with the provided `app_logo.svg` asset.
- Replaced the floating create button center icon with `icon_功能入口_新建.png` while preserving the original pink circular button style.
- Added memo action icons for pin/unpin, edit, and delete.
- Tuned the pinned badge so the pin icon sits inside the tag with stable tag height.
- Tuned category segmented navigation spacing and press scale behavior.
- Fixed search overlay behavior so results render above the blurred backdrop instead of underneath it.
- Added a dedicated search result layer with result count, empty state, and tappable memo cards.
- Added the rule that icon/text/image replacement must not change an existing styled control's outer style unless explicitly requested.
- Stored the Xcode signing team in the native project settings for the current local build configuration.

## 2026-05-23 Update

- Refined the home floating create entry breakout style and press/open/close animation loop.
- Tuned create menu timing so the icon shrink and container expansion feel connected.
- Fixed memo card text layout so one-line and two-line subtitles keep more consistent vertical spacing.
- Added the first pass of the home memo-list scroll effect: the top card scales gently after crossing the top threshold, preserves visual spacing, and avoids lingering top-edge artifacts.
- Kept changes local to the native SwiftUI home screen and working UI rules.

## 2026-05-27 Update

- The editor page is now the main native editing surface instead of a bottom sheet.
- Memo-card and create-category entry paths expand into the editor with custom top navigation that appears downward from the top.
- Editor stickers support insertion, preview, drag, scale, rotation, text wrapping, long-press delete bubble, persistence, and restore after reopening.
- The editor More entry keeps the existing small white circular style while using native `UIButton + UIMenu` behavior to avoid delayed SwiftUI `Menu` pressed-state and shadow artifacts.
- More menu actions currently include pin/unpin and delete, with Q-style action icons.
- The editor toolbar no longer shows a separate save button; editor state persists through the current memo update flow.
- The native asset catalog contains current category, tab, action, logo, create-entry, memo sticker, and editor sticker resources.

## 2026-05-29 Update

- Editor bottom operation bar now uses `格式` as the format entry label and keeps the sticker entry as a separate icon button.
- The sticker popup is the canonical editor operation popup style: compact glass panel, 18pt black title, 34pt circular glass close button, 18pt padding, and soft shadow.
- The format popup has been aligned to the sticker popup header, spacing, close icon, glass container, and rounded/shadow treatment.
- Format popup presentation is scoped to the bottom operation overlay and no longer participates in the operation bar layout flow, preventing the bar and editor content from stretching when the popup opens.
- Editor format controls now include initial native state behavior: title/subtitle/caption turn bold on, body/monospace turn bold off, bold/italic/underline/strikethrough can combine, and monospace shows the body editor in a subtle gray input box. This is still uniform editor-body formatting, not persisted per text range.
- Added native asset-catalog SVG resources for the format controls: bold, italic, underline, strikethrough, and text background.
- Fixed home create-menu layering so the bottom tab bar stays in its original position under the page scrim and is not hidden, faded, or covered by a separate bottom-only overlay.
- Replaced the create-menu backdrop `Button` wrapper with a non-pressing display scrim plus transparent tap layer so tapping blank space does not feel like two separate close actions.
- Current editor sticker behavior remains: insert sticker, preview from the picker, drag, scale, rotate, delete through long press bubble, wrap text around stickers, persist, and restore.

## 2026-06-10 Update

- Added the home empty state for both a completely empty memo store and an empty filtered category, using the provided `EmptyMemoState` asset and context-specific copy.
- Consolidated the bottom tab bar at the app container level so switching between Home, Categories, and Settings keeps the bar visible and preserves its press/selection animation without flashing.
- Expanded the editor bottom operation bar from the current category chip into six visible quick actions while editing, with format, sticker, todo, bold, italic, underline, strikethrough, and color controls available through horizontal scrolling.
- Added text color choices for orange, blue, mint, pink, purple, and gray. Selected text and future typing receive the chosen foreground color and a 14% opacity background color.
- Rebuilt rich-text behavior around the UIKit-backed `RichTextView`: block styles apply to the selected range or cursor paragraph, inline styles remain combinable, typing attributes stay synchronized, and formatted content persists for both new and existing memos.
- Stabilized monospace editing as a paragraph format incompatible with title/subtitle/caption/body while remaining compatible with inline styles and colors.
- Completed the first-stage monospace input box behavior: multiline growth, restore after reopening, paragraph splitting, no ghost lines, stable caret alignment, 8pt inner padding, and a persistent 4pt visual gap from adjacent normal paragraphs.
- Added blank-area editing below existing content. If the last block is monospace, tapping below it creates a normal body paragraph, places the caret outside the gray input box, and preserves the same visual boundary spacing before text is entered.
- Kept the existing editor transition, popup appearance, sticker behavior, and home interactions unchanged while fixing these editor-specific paths.
- Refactored the native editor without changing UI or behavior: `MemoEditorView.swift` now coordinates the page, while editor types, format popup, stickers, native More menu, and UIKit rich-text implementation live in dedicated files.
- Added a maintenance rule that future structural refactors must use behavior-preserving extraction and must not combine file movement with visual, interaction, or persistence changes.

## Current Known State

- `xcodebuild` succeeds with:
  `xcodebuild -project NativeIOS/QMemoCute.xcodeproj -scheme QMemoCute -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' build`
- AppIntents metadata extraction completes without the previous missing-framework warning after the AlarmKit integration.
- Local Xcode user state files are ignored and should not be committed.
- A root `ios/QMemoCute.xcworkspace` exists locally but is not part of the active native project path; review before deciding whether to keep it.

## 2026-06-11 Update

- Added `MemoTodoItem` as the first structured todo-list model with stable identity, text, completion state, and creation time.
- Added `TodoListEditorView` as the dedicated editor for the Home create-menu `待办` entry and existing `.todo` memos.
- Basic todo lists now support adding and removing rows, completing individual items, confirming saves, local persistence, and restore after reopening.
- Existing todo-category memo text is converted into list items by line when opened; structured items remain synchronized to `Memo.content` so the current Home cards and search continue working without layout changes.
- Existing non-todo categories still use the original rich-text `MemoEditorView`; Home card layout was not changed.

## 2026-06-12 Update

- Added an optional reminder time to each structured todo item.
- Todo rows now provide a native iOS date/time reminder sheet and show the selected reminder below the item text.
- Future, incomplete, nonempty todo items schedule local notifications after saving; notification permission is requested only when the user confirms a reminder.
- Removing a reminder, completing or deleting its item, or deleting the whole todo memo removes the corresponding pending notification.
- Reminder values persist with todo data and restore when the editor is reopened.
- Simplified reminder editing into one sheet with switch-controlled inline month and time pickers. Opening time automatically enables today's date and collapses the calendar, and the sheet no longer dismisses accidentally through a downward drag.
- Grouped date, time, and urgent switches under the `时间与日期` heading. Enabling urgent turns on date and time and opens the time picker; disabling date or time clears urgent.
- Urgent reminders use AlarmKit system alarms on iOS 26 and later, with the todo text shown as the alarm title. iOS 17 through iOS 25 continue using local notifications as the compatibility fallback.
- Added the required AlarmKit usage description, persisted the urgent flag with old-data decoding compatibility, and made reminder-sheet confirmation persist and schedule immediately.
- Fixed urgent-alarm scheduling feedback: the editor now waits for AlarmKit synchronization, confirms the item ID exists in `AlarmManager.alarms`, and displays the real failure reason instead of silently treating a local-notification fallback as a successful system alarm.
- AlarmKit alarms are app-owned system alarms and are not expected to be inserted into Apple's Clock app alarm list. Simulator verification covers authorization and registration only; the user performs final real-device alert verification.
- Reminder time labels remain pink before their scheduled date, automatically switch to gray after the date passes, and stay tappable for rescheduling while the todo remains unfinished.

## 2026-06-18 Update

- Added a live Home-card countdown for the nearest future reminder belonging to a nonempty, incomplete todo item.
- Countdown formatting is `X天` above 24 hours, `HH:MM` from 1 through 24 hours, and `MM:SS` below 1 hour; remaining seconds are rounded down so a newly entered two-minute reminder proceeds through `01:59` instead of displaying `00:02`.
- Added the `TodoReminder` asset from the supplied alarm artwork. It replaces the todo icon while a reminder is active; pinned cards retain the pin icon without replacing the countdown text.
- Verified the day, hour-minute, minute-second, pinned, and no-reminder paths in the iPhone 17 / iOS 26.5 simulator without changing the existing memo-card layout or interactions.

## Open Items

- Follow `docs/DEVELOPMENT_ROADMAP.md` for the agreed todo, home redesign, calendar statistics, and mood-tracking sequence.
- Continue visual parity checks against the React Native reference for any remaining homepage details.
- Manually verify search result tapping in the simulator after future search changes.
- Continue editor feature development around todo behavior, richer paragraph operations, and edge-case coverage for persisted attributed text.
- Refine sticker/text wrapping toward shape-aware paths without regressing sticker persistence or manipulation.
- Build out the category page.
- Build out the settings page.
- Plan the App Store in-app purchase flow and product structure.
- Decide final App Store bundle ID, display name, signing/capabilities, app icon set, screenshots, and privacy notes before submission.
- Add data backup/migration and production-grade recovery checks before release.

## Working Rules

- Do not replace an existing styled control's outer style unless explicitly requested.
- For asset-only requests, preserve size, shape, fill, stroke, shadow, spacing, and interaction of the existing control.
- Keep changes scoped and commit only project-relevant files.
- Prefer reading `docs/CODE_STYLE_GUIDE.md` before making UI changes.
