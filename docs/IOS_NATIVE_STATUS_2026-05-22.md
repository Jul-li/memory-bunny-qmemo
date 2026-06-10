# iOS Native Status - 2026-05-22

## Project Goal

- QMemo Cute / 记忆兔备忘录 is moving from the React Native reference app to a native SwiftUI iOS app for App Store release.
- Active branch: `ios-native`.
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

## Current Known State

- `xcodebuild` succeeds with:
  `xcodebuild -project NativeIOS/QMemoCute.xcodeproj -scheme QMemoCute -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' build`
- The AppIntents metadata warning is still present but non-blocking because the app does not currently depend on `AppIntents.framework`.
- Local Xcode user state files are ignored and should not be committed.
- A root `ios/QMemoCute.xcworkspace` exists locally but is not part of the active native project path; review before deciding whether to keep it.

## Open Items

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
