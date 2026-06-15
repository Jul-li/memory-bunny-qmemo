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

## Native iOS Structure

- Active native branch: `main`; keep `ios-native` synchronized as the native development mirror.
- Active native project: `NativeIOS/QMemoCute.xcodeproj`.
- Native app code lives under `NativeIOS/QMemoCute/`.
- Keep `MemoEditorView.swift` focused on editor-page composition, state coordination, navigation, and persistence.
- Editor support code is split by responsibility: shared editor models and commands in `MemoEditorTypes.swift`, format popup UI in `MemoEditorFormatPanel.swift`, sticker behavior in `MemoEditorStickers.swift`, the native More menu in `MemoEditorMoreMenu.swift`, and UIKit rich-text/monospace editing in `MemoRichTextView.swift`.
- Basic todo-list editing lives in `TodoListEditorView.swift`. The Home create-menu `待办` route and existing `.todo` memos use this editor, while all other categories continue using `MemoEditorView`.
- Todo items persist as structured `MemoTodoItem` values. Keep `Memo.content` synchronized as a plain-text checkbox summary so the existing home card and search behavior continue working until the planned home redesign.
- Todo reminder scheduling lives in `TodoReminderManager.swift`. Keep date, time, and urgent controls in one native grouped section titled `时间与日期`; enabling urgent must also enable date and time, while disabling either required control must clear urgent.
- Urgent todo reminders use AlarmKit system alarms on iOS 26 and later. Keep the deployment target compatible with older systems by falling back to local notifications, and cancel both alarm types when a reminder, todo memo, or todo item is removed.
- Confirming the reminder sheet must persist the reminder immediately so alarm scheduling does not depend on a later editor dismissal or an additional save action.
- Structural refactors must start with behavior-preserving mechanical extraction. Do not change layout values, animation timing, interaction state, attributed-text behavior, or persistence formats while moving code between files.
- A feature-specific editor type should remain in its owning file instead of being added back to `MemoEditorView.swift`.
- Native visual assets live in `NativeIOS/QMemoCute/Assets.xcassets`; never depend on desktop-only source paths at runtime.
- Prefer SwiftUI for screens and layout, but use UIKit wrappers when native iOS behavior is more stable or more faithful to the intended interaction.
- Keep native changes scoped to the requested behavior. Do not rewrite a working SwiftUI component only to solve a small visual bug.

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
- Memo deletion must always show a second confirmation before mutating data. The confirmation copy is `便签删除后将无法恢复！确定删除当前便签吗？`, the destructive confirm button sits on the left, and the popup uses `PopDelete` artwork with an absolute-position breakout effect.
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
- Opening the home create menu must keep the bottom tab bar visible in its original position under the backdrop layer. Do not hide or fade the tab bar itself to simulate the backdrop.
- Tapping another bottom tab while the home create menu is open should close the menu.
- The first-level bottom tab bar is owned by the app container and remains mounted when switching Home, Categories, and Settings. Do not create a separate Home-only tab bar or remove/reinsert the bar during tab changes, because that causes flashing and drops the selection animation.
- Home empty states use the `EmptyMemoState` asset at `160` pt. Center the empty state inside the memo scrolling region, not the full screen. A completely empty store shows `还没有便签` / `从第一条开始记录吧🥕`; an empty filtered category shows `暂无相关便签` / `添加便签后会显示在这里`.
- On the home screen, the header, search area, category filter, and `我的便签` section header stay fixed while scrolling; only the memo card list scrolls, starting `12` px below the `我的便签` row.
- Use `Ionicons` from `@expo/vector-icons`; do not hand-roll icons when a library icon exists.

## Native iOS Components

- Prefer the latest native iOS component first for controls, menus, materials, and navigation chrome. Only implement a custom coded version from the design rules when the native component's result is visibly inadequate or blocks the required interaction.
- Native editor pages use a custom top navigation chrome for expanded transitions from first-level pages.
- For any transition that expands from a first-level element into a second-level editor page, the navigation bar appears from the top downward.
- The editor More entry keeps the existing 44 px white circular button, brown ellipsis icon, soft shadow, and native menu popover.
- The editor More entry uses a native `UIButton + UIMenu` bridge when SwiftUI `Menu` causes delayed highlight, shadow, or pressed-state artifacts.
- Do not add visible wrapper containers around More/menu entries to fix interaction bugs.
- The editor bottom function area stays compact until the user enters an editing/tool interaction.
- In the inactive editor state, the bottom function area shows only the memo category chip. Activating title/body editing or opening an editor tool expands the same container from right to left, hides the category chip, and reveals the quick actions. Show six actions per visible width, allow horizontal scrolling for the remainder, omit dividers, and use circular selected states.
- The expanded editor quick-action order starts with format and sticker, followed by todo and inline formatting actions. Keep the full format popup as the advanced formatting surface even when its common inline actions are duplicated in the toolbar.
- Stickers in the editor must save with the memo and restore when the memo is reopened.
- Sticker placement supports drag, scale, rotation, and long-press delete through a small delete bubble.
- Sticker/text wrapping should preserve readability and avoid covering text; refine wrapping geometry without changing unrelated editor layout.
- Editor bottom operation popups share one common visual standard. Use the sticker popup as the source of truth for popup spacing, title font, close icon size, close button glass style, rounded container, shadow, and inner padding.
- Editor format popup title and close control must match the sticker popup header: 18pt black title, 34pt circular glass close button, 14pt bold `xmark`, and 18pt panel padding.
- Editor format popup uses 18pt vertical inner padding. Keep the header row at 18pt horizontal padding, and use 14pt horizontal padding for the content control rows so the format controls have more breathing room without changing other editor popups.
- Editor format and sticker popups open with the same elastic reveal: the panel expands upward from the bottom while widening left and right from a compressed state. Closing reverses the same motion. Do not animate or rearrange the popup's internal controls for this transition.
- Editor bottom operation popups must overlay above the bottom operation bar instead of participating in the bar's layout flow. Opening a popup must not stretch, shift, or resize the bottom operation bar or editor content.
- The editor bottom format entry displays the text `格式`, not `Aa`. Its popup opens above the bottom operation bar and uses the same popup language as other editor operation popups.
- Editor format popup text-style labels use stepped sizes `20/18/16/14/14`, with the first three labels sharing the same bold weight and body/monospace sharing the same 14pt size. Text-style and inline-icon selections both use full-segment `#FDE8A4` backgrounds with selected text/icons using `#F1920D`; do not use inner icon-only selection circles. The inline icon row must fill the content container with consistent left/right padding, the left icon group stretches to fill available space, the right color group stays right-aligned, the gap between icon groups stays fixed at 12pt, and controls use a 48pt height. Color swatches need a 1px white outline.
- Editor format controls keep block style and inline style as separate states. `标题`, `副标题`, and `小标题` use their own semibold block fonts; `正文` and `等宽样式` use regular block fonts. Bold, italic, underline, and strikethrough can be toggled independently and combined.
- Editor rich-text formatting is scoped, not global: if body text is selected, apply the formatting only to the selected range; if there is no selection, apply it only to the paragraph containing the cursor, using line breaks as paragraph boundaries. If the cursor is on a new empty line, update only the editor's current typing attributes so the next input uses the selected style. Every style change must sync `UITextView.typingAttributes` for future typing.
- Editor rich text uses a UIKit-backed `RichTextView` inside `UIViewRepresentable`. Store format state with `NSAttributedString.Key.font` and `.paragraphStyle`, plus lightweight custom tracking keys for block/inline state. Calculate line height with `ceil(max(font.lineHeight, font.pointSize * 1.25) / 4) * 4`, set it as both min/max paragraph line height, and apply baseline offset so text sits vertically centered in the line.
- The editor caret must visually align with the active text style. `RichTextView.caretRect(for:)` should derive the active font from `typingAttributes` and center the caret inside the current line fragment, instead of relying on `textView.font` or a fixed cursor height.
- Monospace is mutually exclusive with title, subtitle, caption, and body block styles, but remains compatible with bold, italic, underline, strikethrough, foreground color, and text background color.
- A monospace input box uses 8pt padding on every side. Adjacent normal paragraphs must keep a visible 4pt gap from the gray box above or below; this rule also applies to a new empty caret line before any text is entered.
- Tapping blank editor space below the last rendered block creates or focuses a paragraph at the document end. If the last block is monospace, the new paragraph must use body typing attributes and its caret must render below the gray box, never inside the monospace block.
- Monospace background drawing is active only for characters and empty lines whose block style is monospace. Changing one line to another block style removes the gray background from that line without changing monospace blocks above or below it.
- Todo reminders belong to individual `MemoTodoItem` records through an optional `reminderAt` date. Use the native iOS date/time picker and local `UNUserNotificationCenter` notifications; do not introduce a custom calendar control for the first-stage reminder flow.
- Todo reminder date and time controls stay inside one non-dismissible-by-drag sheet. New reminders start with both switches off. Enabling date reveals the current month's inline calendar while time stays collapsed; enabling time automatically enables date with today selected, collapses the calendar, and reveals the inline time wheel. Date and time may remain enabled together, but only one picker panel is expanded at a time.
- Todo rows do not expose a trailing delete action. Keep the trailing reminder button visually hidden and noninteractive unless that exact todo text field is currently being edited; preserve its layout space so multiline text does not reflow when focus changes.
- Request notification permission only when the user confirms an actual future reminder. Saving an ordinary todo list with no reminders must not trigger the permission prompt.
- Resynchronize a todo memo's pending notifications after it is saved. Completed items, empty items, removed reminders, past reminder times, deleted items, and deleted todo memos must not retain pending notifications.

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
- Any transition that expands an element from a first-level page into a second-level page must use the expanded-page navigation chrome: hide the native navigation bar during the transition and reveal the custom top navigation from the top downward, matching the memo-card-to-editor transition. Do not let the navigation bar slide in from right to left for these expanded transitions.
- Save/delete actions should update state immediately and persist afterward.
- Destructive actions should get confirmation in a future pass before production use.
- Search should filter title and content.
- Pinned memos sort before unpinned memos.

## Verification Rules

- Build success alone is not enough for QMemo Cute interaction work.
- After a UI or interaction fix, run the exact changed path in the simulator or on device before reporting completion.
- If a fix touches a previously working interaction, do a quick regression pass on that interaction.
- When a user reports a video or screenshot issue, inspect the visual evidence before changing implementation direction.

## Styling Change Rule

- Do not modify visual styling unless the user explicitly asks for style changes.
- When the user asks to replace an icon, image, text, or asset inside an existing styled control, preserve the existing control's size, shape, fill, stroke, shadow, spacing, and interaction unless the user explicitly asks to change those outer styles.
- When the user asks for a breakout effect, position the overflowing icon or artwork absolutely with an overlay/alignment layer so it does not participate in the parent control's layout size.
- For bug fixes in styled components, only change the specific geometry or behavior needed to fix the bug.
- If a user asks for a style adjustment that conflicts with this guide, update this guide by replacing the conflicting rule.
- If a user asks for a style adjustment that is not covered here, add it as a new rule.
