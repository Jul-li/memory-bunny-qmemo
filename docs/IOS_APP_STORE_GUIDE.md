# iOS App Store Development Guide

This project is now iOS-first for production development. Web preview remains useful for fast layout checks, but App Store readiness should be judged on iPhone builds.

## Development Modes

- Fast preview: `npm run web` or `npm start` for quick UI checks only.
- Expo Go smoke test: useful for early interaction testing, but not the production reference.
- iOS development build: use `npm run build:ios:dev` for a closer-to-production app with `expo-dev-client`.
- Internal preview build: use `npm run build:ios:preview` before wider device testing.
- App Store build: use `npm run build:ios:production`, then `npm run submit:ios`.

## iOS Build Requirements

- Confirm the final Bundle ID before the first production submission. The current placeholder is `com.memorybunny.qmemo`.
- Use a paid Apple Developer account for App Store Connect, signing, TestFlight, and production submission.
- Keep `ios.buildNumber` increasing for every App Store upload.
- Validate local data persistence, search, create/edit/delete, pinning, and empty states on a physical iPhone before release.
- Treat safe areas, bottom tab spacing, keyboard behavior, and gesture interactions as iOS QA blockers.

## Release Checklist

- App name, icon, splash, and Bundle ID are final.
- No login, backend, or external account dependency is introduced.
- Destructive actions have confirmation before production release.
- TypeScript passes with `npm run typecheck`.
- A development or preview build has been tested on at least one physical iPhone.
- App Store screenshots, description, privacy details, and age rating are prepared in App Store Connect.
