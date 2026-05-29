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
- Editor format controls currently expose UI for title, subtitle, body, monospaced style, bold, italic, underline, strikethrough, text background, and color selection; the formatting commands are still UI-only placeholders until rich text editing is implemented.
- Current editor sticker behavior remains: insert sticker, preview from the picker, drag, scale, rotate, delete through long press bubble, wrap text around stickers, persist, and restore.

## Current Known State

- `xcodebuild` succeeds with:
  `xcodebuild -project NativeIOS/QMemoCute.xcodeproj -scheme QMemoCute -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' build`
- The AppIntents metadata warning is still present but non-blocking because the app does not currently depend on `AppIntents.framework`.
- Local Xcode user state files are ignored and should not be committed.
- A root `ios/QMemoCute.xcworkspace` exists locally but is not part of the active native project path; review before deciding whether to keep it.

## Open Items

- Continue visual parity checks against the React Native reference for any remaining homepage details.
- Manually verify search result tapping in the simulator after future search changes.
- Continue editor feature development: text color, bold, italic, richer text style controls, and sticker/text wrapping refinements.
- Implement the actual rich text formatting behavior behind the current format popup controls.
- Continue tuning the editor popup open/close motion against the sticker popup standard.
- Build out the category page.
- Build out the settings page.
- Plan the App Store in-app purchase flow and product structure.
- Decide final App Store bundle ID, display name, signing/capabilities, app icon set, screenshots, and privacy notes before submission.
- Add real persistence and production delete confirmation in a later pass if not already covered by the native implementation.

## Working Rules

- Do not replace an existing styled control's outer style unless explicitly requested.
- For asset-only requests, preserve size, shape, fill, stroke, shadow, spacing, and interaction of the existing control.
- Keep changes scoped and commit only project-relevant files.
- Prefer reading `docs/CODE_STYLE_GUIDE.md` before making UI changes.
