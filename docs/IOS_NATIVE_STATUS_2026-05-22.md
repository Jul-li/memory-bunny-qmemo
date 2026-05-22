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

## Current Known State

- `xcodebuild` succeeds with:
  `xcodebuild -project NativeIOS/QMemoCute.xcodeproj -scheme QMemoCute -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' build`
- The AppIntents metadata warning is still present but non-blocking because the app does not currently depend on `AppIntents.framework`.
- Local Xcode user state files are ignored and should not be committed.
- A root `ios/QMemoCute.xcworkspace` exists locally but is not part of the active native project path; review before deciding whether to keep it.

## Open Items

- Continue visual parity checks against the React Native reference for any remaining homepage details.
- Manually verify search result tapping in the simulator after future search changes.
- Decide final App Store bundle ID, display name, signing/capabilities, app icon set, screenshots, and privacy notes before submission.
- Add real persistence and production delete confirmation in a later pass if not already covered by the native implementation.

## Working Rules

- Do not replace an existing styled control's outer style unless explicitly requested.
- For asset-only requests, preserve size, shape, fill, stroke, shadow, spacing, and interaction of the existing control.
- Keep changes scoped and commit only project-relevant files.
- Prefer reading `docs/CODE_STYLE_GUIDE.md` before making UI changes.
