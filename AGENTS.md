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
- **Git Write Consent**: Never run git write operations (`git add`, `git commit`, `git push`) without fresh explicit approval for each write command. "Fix it" or "proceed" is not approval to commit or push — ask first. A single "commit" or "push" in a prompt does not authorize further commits later in the same session — each requires its own explicit approval.
- Never mention AI agents in commit messages or code. This includes `Co-Authored-By: Claude ...` trailers and any "Generated with Claude Code" attribution in commits or PR descriptions — omit them entirely.
- **Resilience to Rejected Commands**: If a user rejects or stops a command execution, continue the task and provide the alternative results or plan. A rejected command must not abort the overall execution.
- **State Management & Data Flow**: Always channel app state through providers. Global state goes in `lib/providers/app_state.dart`; tool-specific state goes in a standalone `ChangeNotifier` at `lib/tools/<name>/<name>_state.dart`. Never update local state variables in views for persistent data.
- **Small Screen Fitting**: Always use responsive layouts (like `Wrap` instead of horizontal `Row` for actions, and scrollable/grid metrics) in dialogs/modals/cards to prevent overflow on mobile.
- **Cross-Platform Checks**: Check platform before using platform-specific APIs (sensors, battery, etc.).
- **Prevent Duplicated UI/Dialog Code**: Extract custom dialogs, overlays, or recurring visual elements to `lib/widgets/` immediately. Never copy-paste presentation logic across views.
- **Use Existing Custom Widgets**: Always reuse existing custom widgets in `lib/widgets/` (such as `ToolCard`, `ToolLayout`, `ResponsiveLayout`, `ResponsiveAlertDialog`, `InfoCard` — check the directory for other reusable options) rather than writing from scratch. Check the codebase for existing reusable options before writing presentation code.
- **Share Cross-Tool Widgets**: Any widget, component, or utility pattern used by 2+ different tools must be extracted to `lib/widgets/` as a shared widget. Tool-specific private widgets (`_SomeWidget`) stay in the tool's own folder under `lib/tools/<name>/`. This includes common patterns like sensor data display rows, status badges, action icon buttons, loading indicators, info cards, and value readouts.
- **Tool Cleanup on Dispose**: Every tool page must use the `DisposeCleanup` mixin (`lib/core/tool_page_state.dart`) and register all cleanup via `onDispose()` in `initState` — sensor subscriptions, wakelocks, controllers, listeners. Never override `dispose()` manually.
- **No Useless Comments**: Do not add code comments that are not useful, such as comments explaining the prompt or user requests.
- **Latest Dependencies & Modern APIs**: Always use the latest version of a dependency available at the time of adding it. Do not add outdated versions. Avoid deprecated method calls (e.g. always use `.withValues(alpha: ...)` instead of `.withOpacity(...)` to prevent precision loss, and use new and modern code).
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
- **Private Widgets over Helpers**: Always declare private `StatelessWidget` classes instead of helper methods returning `Widget`. Each builder method like `_buildSomething(ThemeData)` must be its own widget in a separate file under `lib/tools/<name>/` or `lib/widgets/`. Never write inline `Widget _buildFoo(...)` methods in a stateful widget — they break element tree diffing, prevent const optimization, and bloat the page file. Extract `FooWidget` into its own file with a clean constructor API.
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
- **`widgets/` subfolder** — ALWAYS place tool-specific component widgets here (e.g. `widgets/<name>_display.dart`, `widgets/<name>_toolbar.dart`, `widgets/<name>_panel.dart`). Never inline builders in the page file, and never scatter widget files at the tool root. Only `config.dart`, `<name>_page.dart`, optional `<name>_colors.dart`, and non-widget files (enums, models) sit at the tool root.

### 2. Tool Development, Adaptation & Creation
See the comprehensive guide at [`docs/creating-a-tool.md`](docs/creating-a-tool.md) for details on:
- Folder structure and naming conventions.
- Fullscreen config (`fullscreen: true` in `ToolModel`) to hide standard `AppBar` and enable auto-styled floating overlays.
- Responsive layout adaptations (aspect-ratio constraint switching using `ResponsiveOrientationLayout`, adapting to constrained height).
- Shared common widgets usage (`ToolLayout`, `ToolChip`, etc.).
- Step-by-step instructions for creating a new tool.

### 3. Tool Config Pattern
```dart
class MyNewTool {
  MyNewTool._();
  static const ToolModel config = ToolModel(
    id: 'my-new-tool',
    name: 'My New Tool',
    description: 'What it does',
    icon: Icons.star_outlined,
    route: '/my-new-tool',
    accentColor: AppTheme.accentTeal,
    sectionId: 'utilities',
    stateProviders: () => [ // optional: tool-specific ChangeNotifier
      ChangeNotifierProvider<MyNewToolState>(
        create: (_) => MyNewToolState(),
      ),
    ],
  );
}
```

### 4. Routing
Routes are auto-generated from `ToolRegistry.all` in `lib/app.dart`. Each tool's `route` field becomes a GoRouter path. Page creation uses `ToolModel.createPage` — no manual switch needed in `app.dart`.

Tool state providers declared via `stateProviders` are auto-collected into `main.dart`'s `MultiProvider` — no manual provider registration needed either.

### 5. Storage
- **Per-tool settings**: use `DatabaseService.instance` (`lib/services/database_service.dart`) — singleton with `setSetting`/`getSetting`/`getAllSettings`.
- **Global settings** (theme, compact mode, sort): go through `AppState`, which persists via `SharedPreferences` (`lib/services/settings_service.dart`).

### 6. Bidirectional Sync
- Tools that require data syncing can implement `SyncDelegate`. Register it via `syncDelegateFactory` in the tool's `ToolModel` config — this auto-registers in `AppState` via `ToolRegistry.all` iteration, making the global Settings "Sync Now" button cover that tool. For database storage tracking, protocol flows, and serialization requirements, see the detailed technical specification in [AGENTS.detail.md](AGENTS.detail.md#1-bidirectional-cloud-synchronization).
- **Binary blob handling**: The browser-toolkit backend uses a `__type: 'blob'` wire format for binary fields. `SyncService._unwrapBlobData` centrally unwraps incoming blobs for all tools. Tools wrapping binary data in `getRecordData` must emit `{__type: 'blob', mimeType, data: <base64>}`. Store binary data as native SQLite `BLOB` columns — never as base64 `TEXT`. See [AGENTS.detail.md §1.5](AGENTS.detail.md#15-binary-data--blob-handling-in-sync).

### 7. File Saving & Sharing
- Use `FileSaveHelper` (`lib/helpers/file_save_helper.dart`) to download/export files (such as database backups, reports, or JSON exports). For cross-platform file saving architecture, platform-specific providers, and implementation details, see [AGENTS.detail.md](AGENTS.detail.md#2-database-backup-export--file-downloading-specifications).

### 8. Launcher Shortcuts & App Drawer Icons (Android)
For every tool added to the app, launcher entry points must be maintained:
- **AndroidManifest.xml**: Define a corresponding `<activity-alias>` under `<application>` pointing to `.MainActivity`, named `de.renier.tool_lab.<ToolNamePascalCase>Alias`, marked `android:enabled="false"` (disabled by default) with standard launcher intent-filters.
- **MainActivity.kt**: Map the alias class name to the tool's GoRouter route in `handleIntent` (e.g., `de.renier.tool_lab.CalculatorAlias` maps to `/calculator`).
- **ShortcutHelper.kt**: Add the tool mapping in `setDrawerIconEnabled` to enable/disable the activity-alias component.


---

## Core Guardrails

### 1. State Management & UI Binding
- Standard: `provider` + `ChangeNotifier` (`AppState` in `lib/providers/app_state.dart`).
- Tool-specific state: standalone `ChangeNotifier` in `lib/tools/<name>/<name>_state.dart`, registered via `stateProviders` in `ToolModel`.
- Ensure UI automatically rebuilds by binding via standard consumers.

### 2. Styling & Layouts
- Theme variables from `AppTheme`: `background`, `surface`, `accentBlue`, `accentGreen`, `accentAmber`, `accentRed`.
- Responsive layout container: `ResponsiveLayout` (`lib/widgets/responsive_layout.dart`).

### 3. Navigation
- Standard: `go_router` for declarative routing.

### 4. Localization (i18n)
- The app supports **English (`en`)** and **German (`de`)** via Flutter's `gen_l10n` (`flutter_localizations` + `intl`). ARB sources live in `lib/l10n/app_en.arb` (template) and `lib/l10n/app_de.arb`; config is `l10n.yaml` at the project root.
- **All new user-facing strings must be localized.** Never hardcode UI text (`Text('...')`, tooltips, hints, labels, snackbars, dialog titles). Add a key to **both** ARB files and read it via `AppLocalizations.of(context).<key>` (import `package:tool_lab/l10n/app_localizations.dart`). `en` is the template — every key added there must also exist in `de`.
- After editing ARB files, regenerate with `flutter gen-l10n` (also runs on `flutter pub get` / build since `generate: true`). Generated output is `lib/l10n/app_localizations*.dart` — never edit it by hand.
- The active locale is driven by `AppState.locale` (`null` = follow system) and persisted via `SettingsService.getLocale`/`setLocale`. The user switches it in the Appearance settings page. Default is the user's system language.
- `ToolModel` names/descriptions and `ToolSection` titles are **localized per-tool**. In `config.dart`, set the optional `nameL10n` / `descriptionL10n` resolvers (and `titleL10n` on a `ToolSection`): `nameL10n: (l10n) => l10n.toolNameMyTool`. These take `AppLocalizations`, never a `BuildContext`. The raw `name` / `description` strings stay as fallbacks. Display code reads the localized value via `tool.localizedName(l10n)` / `tool.localizedDescription(l10n)` / `section.localizedTitle(l10n)` — never `.name` / `.description` / `.title` directly for UI. Add the matching keys to both ARB files. There is no central id→string switch: a new tool only edits its own `config.dart` + the ARB files.

---

## Dependencies

Dependencies in `pubspec.yaml`. Check there before adding new packages.

---

## Verification Procedures

*Note: Formatting and static analysis are only required when Dart/source code files are changed. They are not necessary when only markdown documentation, images, or static assets are modified.*

1. **Formatting**: `dart format ./lib`
2. **Analysis**: `flutter analyze`
