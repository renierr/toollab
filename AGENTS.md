# AI Developer Guidelines & Project Playbook (AGENTS.md)

Welcome, AI Developer! This playbook provides the technical rules, architectural guardrails, and design aesthetics for maintaining and scaling the **ToolLab** codebase.

---

## Priority Model

- `ALWAYS`: Hard constraints. Do not violate.
- `PREFER`: Default behavior. Use unless there is a clear reason not to.

---

## ALWAYS

- **Caveman style**: Short, direct answers. No filler.
- Do not run production compilation or release builds unless explicitly requested.
- **Git Write Consent**: Never run git write operations (`git add`, `git commit`, `git push`) without fresh explicit approval. A direct "commit" request authorizes staging and creating one commit for the current work only; it does not authorize future commits. A direct "push" request authorizes one push only. "Fix it" or "proceed" is not approval to commit or push.
- Never mention AI agents in commit messages or code. This includes `Co-Authored-By: Claude ...` trailers and any "Generated with Claude Code" attribution in commits or PR descriptions — omit them entirely.
- **Resilience to Rejected Commands**: If a user rejects or stops a command execution, continue the task and provide the alternative results or plan. A rejected command must not abort the overall execution.
- **State Management & Data Flow**: Always channel app state through providers. Global state goes in `lib/providers/app_state.dart`; tool-specific state goes in a standalone `ChangeNotifier` at `lib/tools/<name>/<name>_state.dart`. Never update local state variables in views for persistent data.
- **Small Screen Fitting**: Always use responsive layouts (like `Wrap` instead of horizontal `Row` for actions, and scrollable/grid metrics) in dialogs/modals/cards to prevent overflow on mobile.
- **Ask the Right Widget How Much Room There Is**: Three different questions look alike at the call site — pick the mechanism by the question, not by habit.
  1. *"How much room do I have?"* — a widget choosing its own layout. Use `LayoutBuilder` plus the `BoxConstraints` extension in `lib/widgets/responsive_layout.dart`: `constraints.isCompact` / `isMedium` / `isExpanded` for device tiers, `constraints.canSplit` for "two panes side by side". Never `MediaQuery` here — inside a pane, drawer or split view the window is not the space available.
  2. *"How big is the window?"* — chrome and overlays only: dialog max height, app bar height, safe-area padding, the physical device orientation a sensor needs. Use the aspect accessors — `MediaQuery.sizeOf(context)`, `orientationOf`, `paddingOf`, `devicePixelRatioOf` — never `MediaQuery.of(context)`, which subscribes to every MediaQuery change. There are no window-width tier helpers; a width question is question (1).
  3. *"Does my own content fit?"* — a toolbar, tile or chart row asking whether its own children still fit. Use `LayoutBuilder` with a local literal named for the reason (`cramped`, `isCompact`), not a device tier. A metric tile at `< 240` is not asking about phones.
  When a child cannot answer (1) for itself because its parent already constrained it — a 280-wide sidebar that must know it is in sidebar mode, or a panel inside a scroll view that cannot measure the viewport's height — the parent measures and passes the mode down as a parameter. Never re-derive it from `MediaQuery`.
  Two decisions taken from the same measurement must share one measurement. A page that puts a pane inline when wide and behind a drawer when narrow computes `canSplit` once and passes it down; asking twice lets the drawer button and the inline pane both appear.
- **Cross-Platform Checks**: Check platform before using platform-specific APIs (sensors, battery, etc.).
- **Prevent Duplicated UI/Dialog Code**: Extract custom dialogs, overlays, or recurring visual elements to `lib/widgets/` immediately. Never copy-paste presentation logic across views.
- **Use Existing Custom Widgets**: Always reuse existing custom widgets in `lib/widgets/` (such as `ToolCard`, `ToolLayout`, `ReadableWidth`, `ResponsiveAlertDialog`, `InfoCard` — check the directory for other reusable options) rather than writing from scratch. Check the codebase for existing reusable options before writing presentation code.
- **Share Cross-Tool Widgets**: Any widget, component, or utility pattern used by 2+ different tools must be extracted to `lib/widgets/` as a shared widget. Tool-specific private widgets (`_SomeWidget`) stay in the tool's own folder under `lib/tools/<name>/`. This includes common patterns like sensor data display rows, status badges, action icon buttons, loading indicators, info cards, and value readouts.
- **Tool Cleanup on Dispose**: Every tool page must use the `DisposeCleanup` mixin (`lib/core/tool_page_state.dart`) and register all cleanup via `onDispose()` in `initState` — sensor subscriptions, wakelocks, controllers, listeners. Never override `dispose()` manually.
- **No Useless Comments**: Do not add code comments that are not useful. This includes comments explaining the prompt or user requests, and obvious comments that merely restate what the code does. Only comment when it explains something non-obvious — a *why*, a caveat, or a subtle constraint.
- **Debug Logging**: Use `debugLog()` from `lib/helpers/debug_log.dart` for debug-only diagnostic logs. Use `errorLog()` for actionable errors that must remain logged outside debug builds. Do not use `debugPrint()` directly in app code. Wrap performance logging and any expensive message construction in `if (kDebugMode)` at the call site so it is removed from profile/release builds.
- **Comments Stay Minimal**: Keep every comment as short as it can be — one line where one line does the job, and only where standard code reading would not reveal the point. Never write multi-line prose blocks or doc comments that restate a class/method name, list what a widget renders, or narrate a change, a decision history, or an AI prompt. When a comment grows past a line or two, the fix is almost always to shorten it, not to keep it.
- **Latest Dependencies & Modern APIs**: Always use the latest version of a dependency available at the time of adding it. Do not add outdated versions. Avoid deprecated method calls (e.g. always use `.withValues(alpha: ...)` instead of `.withOpacity(...)` to prevent precision loss, and use new and modern code).
- **Typed Rows, Never Raw Maps**: A `Map<String, dynamic>` sqlite row must never leave its DB helper. Every table gets a model class with typed fields and a `fromMap` factory (`lib/tools/<name>/<name>.dart`, or grouped under `models/`); the helper returns that model and state, pages and widgets never index a row by column name. Untyped maps leak the schema into the UI, hide which fields a query path actually populates, and turn a typo into a runtime null. Raw maps stay only at genuine untyped boundaries — decoded JSON from an import file, `SyncDelegate` wire payloads, platform-channel data. See `lib/tools/notes/note.dart` and `lib/tools/grocery_list/grocery_item.dart`.
- **Database Test Isolation**: Database unit/widget tests must never read or write to the standard persistent database. Always set `dbPathOverride` to `inMemoryDatabasePath` on `DatabaseService.instance` and close the connection in `tearDownAll` to ensure test state is clean and fully isolated in memory.
- **Platform Scope**: iOS and macOS are NOT supported. Tools and services do not need to handle, verify, or support iOS or macOS platforms. Focus purely on Android and Windows.
- **Temporary Files & Plans**: Always use the `.agents/temp/` folder (create if not exists) for storing plans, temporary files, or agent scratch files. Never commit this folder.
- **Temp File Manager**: Always use `TempFileManager` (`lib/helpers/temp_file_manager.dart`) for all app temp file creation/reading/cleanup. Never use raw `getTemporaryDirectory()` + manual `File()` — this leaves orphans and bypasses namespace isolation.
- **Temp File Lifecycle** — Three cleanup levels:
  1. **`TempFileScope.cleanTracked()`** — per-widget/controller cleanup. Create a scope via `TempFileManager.createScope()`, store as `late final TempFileScope _scope`, and register cleanup via `onDispose(() => _scope.cleanTracked())`. Only this scope's files are removed. Always use scoped tracking for StatefulWidgets and ChangeNotifiers.
  2. **`TempFileManager.cleanTracked()`** — global tracked file cleanup (for files created via the static `TempFileManager.createFile()`). Only relevant for StatelessWidgets or static helpers without lifecycle.
  3. **`TempFileManager.cleanSession()`** / **`cleanAll()`** — session-level / nuclear cleanup. `cleanSession` removes the current session dir; `cleanAll` nukes the entire `tool_lab/` base dir and re-initializes (use from maintenance page). `cleanSession` fires automatically on `AppLifecycleState.detached`.
- **Large Data → Temp Files**: Prefer `TempFileManager.createFile()` or `scope.createFile()` for large binary data (images, PDFs, exports) instead of holding large `Uint8List` in memory. Small in-memory bytes (< 100 KB) are fine for fast access.
- **Tool ID Single Source of Truth**: Never hardcode tool ID strings (`'fast-drop'`, `'notes'`, etc.) outside of `config.dart`. Always reference via `MyTool.config.id`. This applies to pages, sync delegates, DB helpers, archive classes — everywhere. The only occurrence of the literal tool ID string should be in `config.dart`.
- **Keep Tool Reference Docs Current**: Some tools ship a reference page next to their code (for example `lib/tools/health_dashboard/docs/storage-model.html`, which documents the storage model, the Health Connect type mapping and when each write path runs, or `lib/tools/renpho_ble_probe/README.md`, which documents the BLE wire protocol, the setup sequence and the derived-value tiers). When you change what such a doc describes — schema, mapping, write paths, defaults — update the doc in the same change. Do not publish these as artifacts; they are repo files.
- **Localize User-Facing Strings**: Never hardcode UI text. Add a key to both `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb` and read it via `AppLocalizations.of(context).<key>`. See [Core Guardrails §4](#4-localization-i18n).

---

## PREFER

- Keep answers extremely short and concise. English for code/docs.
- Use explicit return types for methods.
- Reference colors from `AppTheme` in `lib/theme/theme.dart`. No hardcoded hex codes.
- Bind UI screens to state using `Consumer<AppState>`, `context.watch<AppState>()`, or `context.read<AppState>()`. Tool-specific state: use `context.watch<MyToolState>()` / `context.read<MyToolState>()` from the tool's own `ChangeNotifier`. Prefer `context.watch<T>()` over `Provider.of<T>(context)` and `context.read<T>()` over `Provider.of<T>(context, listen: false)`. Use `context.read<T>()` in button callbacks and lifecycle methods.
- Log errors with clear service or page context prefixes to make debugging easy.
- Extract dialogs, detailed cards, or list items to `lib/widgets/` to promote modular codebase structure.
- Extract repetitive visual components to shared reusable widgets to maintain consistency.
- **Color Strategy — 3-Layer Approach**:
  1. **Tool-specific palette**: Tools with a strong visual identity (e.g. EMF detector's neon cyberpunk colors) define their own `lib/tools/<name>/<name>_colors.dart` file with `static const` values. These are not theme-abstracted — they are part of the tool's aesthetic.
  2. **Semantic status colors in AppTheme**: Cross-tool status indicators (battery level, sync state, delete actions) use `AppTheme.statusGreen`, `AppTheme.statusRed`, `AppTheme.statusAmber`, etc. in `lib/theme/theme.dart`.
  3. **Theme.of(context) properties**: Universal colors like surface, background, text, dividers use `theme.colorScheme.*` and `theme.textTheme.*` — never hardcoded `Colors.grey[200]` or `Colors.white` for structural UI.
- **Private Widgets over Helpers**: A method that *builds a subtree* — anything beyond a single constructor call — must be a `StatelessWidget` class, not a `Widget _buildFoo(...)` method. A helper method has no element of its own, so it cannot be `const`, cannot stop a rebuild at its boundary, and re-diffs its whole subtree every time the enclosing `build()` runs. This bites hardest inside a `State`, and worst inside a list or a per-row builder.
  - **Where it goes**: its own file under `widgets/` when the widget is reused, takes a wide constructor API, or the host file is already long. A private `class _Foo extends StatelessWidget` at the bottom of the same file is fine for a single-use component — it gets the same element, `const` and rebuild boundary without a one-use file.
  - **Not covered**: methods returning `List<Widget>` for a `children:`/`actions:` spread (wrapping them in a widget would add a container element and change the layout — and each item already gets its own element), and one-expression delegators that just forward fields to an already-extracted widget.
- **Const Constructors**: Prefer using `const` constructors for widgets and in `build()` methods where possible to reduce rebuilds.
- **Lazy Lists**: Prefer `ListView.builder` or slivers for dynamic or performance-sensitive lists.

---

## Tool Architecture

### 1. Tool Structure
Each tool lives in its own folder under `lib/tools/<name>/` and follows this layout:
```
lib/tools/<name>/
  config.dart           - Tool metadata (ToolModel)
  <name>_page.dart      - Thin coordinator page (composes widgets, no inline builders)
  <name>_colors.dart    - Optional tool-specific color palette
  widgets/              - REQUIRED for component widgets — every visual component gets its own file here
    <name>_display.dart
    <name>_toolbar.dart
```
- **`config.dart`** — Tool metadata (name, icon, route, color). Exports a static `const ToolModel` via a tool class.
- **`<name>_page.dart`** — Tool entry point page. Must be a thin coordinator — only `StatefulWidget` state + build method that composes extracted widgets. No inline `Widget _buildFoo(...)` methods.
- **`widgets/` subfolder** — ALWAYS place tool-specific component widgets here (e.g. `widgets/<name>_display.dart`, `widgets/<name>_toolbar.dart`, `widgets/<name>_panel.dart`). Never inline builders in the page file, and never scatter widget files at the tool root. `config.dart`, `<name>_page.dart`, and optional `<name>_colors.dart` sit at the tool root. Non-widget files (enums, models, codecs, parsers, services) may sit at the tool root or be grouped into descriptively named subfolders (e.g. `converters/`, `models/`) when that improves clarity — use subfolders only for non-widget logic; widget files always live under `widgets/`.

### 2. Tool Development, Adaptation & Creation
See the comprehensive guide at [`docs/creating-a-tool.md`](docs/creating-a-tool.md) for details on:
- Folder structure and naming conventions.
- Fullscreen config (`fullscreen: true` in `ToolModel`) to hide standard `AppBar` and enable auto-styled floating overlays.
- Responsive layout adaptations (aspect-ratio constraint switching using `ResponsiveOrientationLayout`, adapting to constrained height).
- Shared common widgets usage (`ToolLayout`, `ToolChip`, etc.).
- Step-by-step instructions for creating a new tool.

### 3. Tool Config Pattern
See [`docs/creating-a-tool.md`](docs/creating-a-tool.md) Step 1 for the full `config.dart` pattern (state providers, l10n resolvers, sync/background hooks).

### 4. Routing
Routes are auto-generated from `ToolRegistry.all` in `lib/app.dart`. Each tool's `route` field becomes a GoRouter path. Page creation uses `ToolModel.createPage` — no manual switch needed in `app.dart`.

Tool state providers declared via `stateProviders` are auto-collected into `main.dart`'s `MultiProvider` — no manual provider registration needed either.

### 5. Storage
- **Per-tool settings**: use `DatabaseService.instance` (`lib/services/database_service.dart`) — singleton with `setSetting`/`getSetting`/`getAllSettings`.
- **Global settings** (theme, compact mode, sort): go through `AppState`, which persists via `SharedPreferences` (`lib/services/settings_service.dart`).
- **Tool tables**: the DB helper is the row/model boundary. It owns the raw `db.query` maps and returns model instances; see the ALWAYS rule *Typed Rows, Never Raw Maps*. Column-projection queries used inside the helper itself (a short-id lookup, a tag join) may stay maps.

### 6. Bidirectional Sync
- Tools that require data syncing can implement `SyncDelegate`. Register it via `syncDelegateFactory` in the tool's `ToolModel` config — this auto-registers in `AppState` via `ToolRegistry.all` iteration, making the global Settings "Sync Now" button cover that tool. For database storage tracking, protocol flows, and serialization requirements, see the detailed technical specification in [AGENTS.detail.md](AGENTS.detail.md#1-bidirectional-cloud-synchronization).
- **Binary blob handling**: The browser-toolkit backend uses a `__type: 'blob'` wire format for binary fields. `SyncService._unwrapBlobData` centrally unwraps incoming blobs for all tools. Tools wrapping binary data in `getRecordData` must emit `{__type: 'blob', mimeType, data: <base64>}`. Store binary data as native SQLite `BLOB` columns — never as base64 `TEXT`. See [AGENTS.detail.md §1.5](AGENTS.detail.md#15-binary-data--blob-handling-in-sync).

### 7. File Saving & Sharing
- Use `FileSaveHelper` (`lib/helpers/file_save_helper.dart`) to download/export files (such as database backups, reports, or JSON exports). For cross-platform file saving architecture, platform-specific providers, and implementation details, see [AGENTS.detail.md](AGENTS.detail.md#2-database-backup-export--file-downloading-specifications).

### 8. Launcher Shortcuts & App Drawer Icons (Android)
For every tool added to the app, launcher entry points must be maintained. See [`docs/creating-a-tool.md`](docs/creating-a-tool.md) Step 4 for the `AndroidManifest.xml` activity-alias, `MainActivity.kt` and `ShortcutHelper.kt` wiring.

### 9. Background Tasks (Android)
Work that must happen while the app is closed goes through `BackgroundTaskService` — never add a scheduler, plugin or timer of your own. See [`docs/creating-a-tool.md`](docs/creating-a-tool.md) §9 for the registration pattern and the constraints on a scheduled run.

---

## Core Guardrails

### 1. State Management & UI Binding
- Standard: `provider` + `ChangeNotifier` (`AppState` in `lib/providers/app_state.dart`).
- Tool-specific state: standalone `ChangeNotifier` in `lib/tools/<name>/<name>_state.dart`, registered via `stateProviders` in `ToolModel`.
- Ensure UI automatically rebuilds by binding via standard consumers.

### 2. Styling & Layouts
- Theme variables from `AppTheme`: `background`, `surface`, `accentBlue`, `accentGreen`, `accentAmber`, `accentRed`.
- Breakpoints and tiers live in `lib/widgets/responsive_layout.dart`: `Breakpoints.mobile` (600), `.tablet` (900), `.split` (720, the width at which two panes beat stacking), `.readableContent` (900, past which one column stops reading well), the `LayoutSizeClass` enum and the `BoxConstraints` extension. Never hardcode a device-tier number in a tool; tools branch on the extension, not on the constants.
- **Cap or reflow on wide screens.** A `ListView` fills whatever width it gets, so maximized on a desktop each row becomes one thin strip with its icon and trailing value at opposite edges. Wrap the *scrollable* (not the rows — that would strand the scrollbar) in `ReadableWidth` (`lib/widgets/readable_width.dart`) for card stacks, settings columns and message lists; use a `SliverGridDelegateWithMaxCrossAxisExtent` instead when the items are card-shaped and extra width should become more columns. Content that genuinely wants the room — canvases, images, editors, wide tables — stays uncapped.
- `ResponsiveOrientationLayout` switches on the aspect ratio of the available box. Prefer it over a width tier for canvas/viewport tools (sketch board, image viewer, compass, level), where the question is which side the leftover room is on.
- Tools with fixed geometry (calculator keypad) should scale, not reflow by tier. Do not force breakpoints on them.

### 4. Localization (i18n)
- The app supports **English (`en`)** and **German (`de`)** via Flutter's `gen_l10n` (`flutter_localizations` + `intl`). ARB sources live in `lib/l10n/app_en.arb` (template) and `lib/l10n/app_de.arb`; config is `l10n.yaml` at the project root.
- **All new user-facing strings must be localized.** Never hardcode UI text (`Text('...')`, tooltips, hints, labels, snackbars, dialog titles). Add a key to **both** ARB files and read it via `AppLocalizations.of(context).<key>` (import `package:tool_lab/l10n/app_localizations.dart`). `en` is the template — every key added there must also exist in `de`.
- After editing ARB files, regenerate with `flutter gen-l10n` (also runs on `flutter pub get` / build since `generate: true`). Generated output is `lib/l10n/app_localizations*.dart` — never edit it by hand.
- The active locale is driven by `AppState.locale` (`null` = follow system) and persisted via `SettingsService.getLocale`/`setLocale`. The user switches it in the Appearance settings page. Default is the user's system language.
- `ToolModel` names/descriptions and `ToolSection` titles are **localized per-tool**. In `config.dart`, set the optional `nameL10n` / `descriptionL10n` resolvers (and `titleL10n` on a `ToolSection`): `nameL10n: (l10n) => l10n.toolNameMyTool`. These take `AppLocalizations`, never a `BuildContext`. The raw `name` / `description` strings stay as fallbacks. Display code reads the localized value via `tool.localizedName(l10n)` / `tool.localizedDescription(l10n)` / `section.localizedTitle(l10n)` — never `.name` / `.description` / `.title` directly for UI. Add the matching keys to both ARB files. There is no central id→string switch: a new tool only edits its own `config.dart` + the ARB files.

---

## Verification Procedures

*Note: Formatting and static analysis are only required when Dart/source code files are changed. They are not necessary when only markdown documentation, images, or static assets are modified.*
