# QMemo Cute Code And UI Style Guide

This guide is the working standard for the current app. Future code should follow it by default.
If a later user request repeats an existing rule with different details, replace the old rule. If it adds a new requirement, append it as a new rule.

## Product Direction

- The app is a local-first Q-style cartoon memo app for young users.
- The visual mood is cute, soft, sticker-like, rounded, and journal-like.
- Do not add login, backend calls, or account concepts unless explicitly requested.
- Keep interactions lightweight: quick create, edit, search, categorize, pin, and delete.

## Code Structure

- App routes live in `app/` and should stay route-focused.
- Shared UI components live in `src/components/`.
- Shared data/state lives in `src/context/`, `src/data/`, `src/db/`, and `src/types/`.
- Use Expo Router for navigation.
- Use TypeScript types from `src/types/` for memo/category/color data.
- Keep data access behind context or repository-style helpers; avoid direct storage calls from screen components.
- Use `apply_patch`-style small edits and avoid unrelated refactors.

## State And Storage

- Use `MemoContext` as the single source of truth for memo list state.
- Phone/native persistence uses `expo-sqlite/kv-store` unless a full SQL table migration is explicitly planned.
- Web preview may use `localStorage` fallback when SQLite blocks or hangs in browser preview.
- After create, edit, or delete, return to the home route and update the list immediately.

## Theme Tokens

Use `src/constants/theme.ts` before hardcoding values.

Colors:
- `background`: `#FFF6D7`
- `surface`: `#FFFDF6`
- `surfaceStrong`: `#FFFFFF`
- `text`: `#49392F`
- `muted`: `#9C8577`
- `line`: `#F2DFBF`
- `shadow`: `#C69C6D`
- `cream`: `#FFF0B8`
- `pink`: `#FFD7E5`
- `mint`: `#CFF5DD`
- `sky`: `#CFEAFF`
- `lavender`: `#E5D8FF`
- `coral`: `#FFC7B8`
- `accent`: `#FF9DB8`
- `accentStrong`: `#F06F9A`
- `green`: `#80D4A2`
- Memo cards render with a single default background color: `#FFFDF5`.

Radius:
- `sm`: `14`
- `md`: `20`
- `lg`: `28`
- `xl`: `34`
- Use `999` only for pills, circular buttons, and capsule controls.

Spacing:
- Page horizontal padding is `theme.spacing.page` = `20`.
- Common card padding: `18`, `22`, or `24`.
- Common section spacing: `12`, `14`, `16`, or `18`.
- Bottom list padding should leave room for floating action and tab bars.

## Typography

- Use system fonts; do not add custom font packages unless explicitly requested.
- Home header brand mark uses `assets/brand/app_logo.svg` in the former `记忆兔` text position, rendered as an image above the prompt.
- Home header prompt text: `16`, line height `22`, weight `400`.
- Editor title: `22`, weight `900`.
- Section titles: `18`, weight `900`.
- Card titles: `20`, weight `900`.
- Body copy: `15`, weight `400`, `600`, or `700`, line height around `22`.
- Labels: `15`, weight `900`.
- Small metadata: `12` or `13`, weight `700` or `800`.
- Placeholder text uses `theme.colors.muted`.

## Components

- Use `MemoCard` for memo list items.
- Memo cards display Q-style sticker PNGs from `assets/memo-icons/` in the right-side blank area, mapped by memo category: todo uses the latest `icon_待办贴纸.png` asset as `checklist.png` only, study uses reading, idea uses idea, and life/diary use flower-basket or camera-photo with stable per-memo selection.
- Memo cards include an internal grid-paper texture made from black hairline rules at `2%` opacity, clipped inside the rounded border, spanning the full card with consistent cell spacing, and layered below text and stickers so the card reads as a sticky note without hurting readability.
- Memo card titles stay one line; memo card content/subtitle is capped at two lines, uses weight `400`, keeps a `4` px gap from the title, and the updated time sits `6` px below the subtitle.
- Memo card right-side stickers live in the same body container as the title/subtitle, sit at `255` px from that container's left edge, and render at `86` x `86`; title-only cards use a separate vertical offset for visual centering.
- Memo card sticker assets should be sourced from `Q版icon` files whose names include `贴纸`, copied into `assets/memo-icons/`.
- Memo cards use a three-dot right-side action entry for future overflow actions instead of showing a pin/location-style icon.
- Memo card category badges should use matching PNG files from `assets/category-icons/` at `24` for non-pinned cards, include a 1px white outer stroke, and fallback to `Ionicons` only when no matching asset exists. When a memo is pinned, replace the badge icon with `assets/category-icons/pinned.png` at `32` x `32`, position it absolutely inside the badge with `2` px left spacing so it can overflow while the badge height stays unchanged, and add the memo category icon before the title at `32` x `32`.
- Memo card footers show the updated time only; do not show a trailing chevron unless it has a concrete action.
- Memo card actions open from either a long-press below the card or the three-dot button position, share the same springy scale/translate animation language as the create menu, and use the same tappable blurred backdrop pattern as search: soft cream translucent fallback fill plus blur when available. When a long-pressed card is too close to the bottom tab bar for the menu to fit below it, open the menu above the card instead.
- Memo card action menus include pin/unpin, delete, and edit; pin/unpin should persist through the local memo state and immediately update card ordering.
- Use `CategoryPill` for horizontal category filters.
- Home search is hidden by default. Use the Q-style search icon from `assets/action-icons/search.png` in the top-right header area; tapping it scales the current icon down to zero, waits about `0.15s`, then springs the next icon in while the search box expands leftward and downward from the icon position using the same morphing language as the create menu. The header icon changes to `assets/action-icons/close.png`; closing reverses the path, the close icon scales down to zero, waits about `0.15s`, then the search icon springs back in. Search-open state should add a tappable blurred backdrop over the content and floating create button, while keeping the header search control and search box above the backdrop. The backdrop must include a visible soft cream translucent fill as a fallback so it still reads as a modal search layer when `backdrop-filter` is unavailable or stale after hot reload.
- Category labels should be two Chinese characters. If a label is longer, keep the first two characters and remove the rest.
- Category filter pills should use a soft diffuse shadow. Inactive pills have no visible stroke; active pills use a 2px white stroke.
- Category filter pill icons should render at `24`.
- Category filter scroll containers should reserve vertical shadow buffer space based on shadow radius and offset, then offset it with negative margins so shadows are not clipped without changing the layout height.
- Category filter icons and create menu category icons should use matching PNG files from `assets/category-icons/` for all categories, including `diary`/`心情`; fallback to `Ionicons` only when no matching asset exists.
- Home header avatar should use `assets/profile-icons/avatar.png`, sit to the left of the title group, and render at `64`.
- Use `MemoForm` for create/edit memo forms.
- Memo form title and content inputs should be combined in one large editor container: title input on top, content input below, no separate title/content field labels, and original placeholders preserved.
- Memo form title and content inputs should hide the focused outline frame and internal focused border on web.
- Memo form should not show category tag selection on create or edit; category is selected before opening the create form and remains fixed when editing.
- Memo form selected color swatches use the lighter memo color palette and a soft accent selected border/checkmark instead of a dark selected border.
- Use `MemoEditorShell` for editor pages with consistent back navigation.
- Use `StickerEmptyState` for cute empty states.
- Use `IOS26Switch` for pin toggle behavior.
- Bottom tab bar should be a floating white capsule. Inactive tabs show icon only. The selected tab expands into a soft pink pill, keeps visible left padding, moves the icon slightly left, and reveals the label with a Bezier-eased animation. Selected tab labels use size `16`, weight `700`. Selected pills include a 1px `#FDFDFB` dashed inner stroke inset by `3` px. Labels stay `备忘`, `分类`, and `设置`.
- Bottom tab bar icons should use PNG files from `assets/tab-icons/`, sourced from `Q版icon` files with the `bar_` prefix.
- The home floating create button should keep a `24` px vertical gap above the bottom tab bar.
- Tapping the home floating create button starts from the original button shape: the entry first moves up `16` px with a subtle scale change, then morphs in place from the pink circular plus button into a white rounded create menu with Bezier-eased size, color, radius, opacity, and content reveal. While the menu is open, hide the separate floating create button; tapping the blank backdrop closes the menu. Menu options use existing memo categories and category icons, must show all five categories, and the content area should support vertical scrolling if constrained. Each create menu option is a full-width row with no default color block, a pressed light-gray background, a title plus auxiliary description capped at 20 Chinese characters, and an icon sized to the combined two-line text height.
- Tapping another bottom tab while the home create menu is open should close the menu.
- On the home screen, the header, search area, category filter, and `我的便签` section header stay fixed while scrolling; only the memo card list scrolls, starting `12` px below the `我的便签` row.
- Use `Ionicons` from `@expo/vector-icons`; do not hand-roll icons when a library icon exists.

## Layout Rules

- Screens use `SafeAreaView`.
- Top-level screen background is `theme.colors.background`.
- Cards use large radius, soft border, and light shadow.
- Avoid nested cards unless the inner card is a functional control group.
- Keep floating add button above the tab bar.
- Keep touch targets at least around `40` to `46` px high where practical.
- Text must not overflow its container on mobile widths.
- Do not change an existing component's height unless the user explicitly asks for a height adjustment; when increasing inner artwork or icon size, preserve the outer control height.

## Interaction Rules

- Pressable controls should include a subtle pressed scale effect.
- Navigation to create/edit pages must always provide an obvious return path.
- Save/delete actions should update state immediately and persist afterward.
- Destructive actions should get confirmation in a future pass before production use.
- Search should filter title and content.
- Pinned memos sort before unpinned memos.

## Styling Change Rule

- Do not modify visual styling unless the user explicitly asks for style changes.
- When the user asks to replace an icon, image, text, or asset inside an existing styled control, preserve the existing control's size, shape, fill, stroke, shadow, spacing, and interaction unless the user explicitly asks to change those outer styles.
- When the user asks for a breakout effect, position the overflowing icon or artwork absolutely with an overlay/alignment layer so it does not participate in the parent control's layout size.
- For bug fixes in styled components, only change the specific geometry or behavior needed to fix the bug.
- If a user asks for a style adjustment that conflicts with this guide, update this guide by replacing the conflicting rule.
- If a user asks for a style adjustment that is not covered here, add it as a new rule.
