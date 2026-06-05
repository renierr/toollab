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
- Never mention AI agents in commit messages or code.
- **Resilience to Rejected Commands**: If a user rejects or stops a command execution, continue the task and provide the alternative results or plan. A rejected command must not abort the overall execution.
- **State Management & Data Flow**: Always channel app state through providers in `lib/providers/`. Never update local state variables in views for persistent data.
- **Small Screen Fitting**: Always use responsive layouts (like `Wrap` instead of horizontal `Row` for actions, and scrollable/grid metrics) in dialogs/modals/cards to prevent overflow on mobile.
- **Cross-Platform Checks**: Check platform before using platform-specific APIs (sensors, battery, etc.).
- **Prevent Duplicated UI/Dialog Code**: Extract custom dialogs, overlays, or recurring visual elements to `lib/widgets/` immediately. Never copy-paste presentation logic across views.
- **Use Existing Custom Widgets**: Always reuse existing custom widgets in `lib/widgets/` (such as `ToolCard`, `ToolLayout`, `ResponsiveLayout`) rather than writing from scratch. Check the codebase for existing reusable options before writing presentation code.
- **Share Cross-Tool Widgets**: Any widget, component, or utility pattern used by 2+ different tools must be extracted to `lib/widgets/` as a shared widget. Tool-specific private widgets (`_SomeWidget`) stay in the tool's own folder under `lib/tools/<name>/`. This includes common patterns like sensor data display rows, status badges, action icon buttons, loading indicators, info cards, and value readouts.
- **Tool Cleanup on Dispose**: Every tool page must use the `DisposeCleanup` mixin (`lib/core/tool_page_state.dart`) and register all cleanup via `onDispose()` in `initState` — sensor subscriptions, wakelocks, controllers, listeners. Never override `dispose()` manually.
- **No Useless Comments**: Do not add code comments that are not useful, such as comments explaining the prompt or user requests.
- **Latest Dependencies**: Always use the latest version of a dependency available at the time of adding it. Do not add outdated versions.
- **Database Test Isolation**: Database unit/widget tests must never read or write to the standard persistent database. Always set `dbPathOverride` to `inMemoryDatabasePath` on `DatabaseService.instance` and close the connection in `tearDownAll` to ensure test state is clean and fully isolated in memory.

---

## PREFER

- Keep answers extremely short and concise. English for code/docs.
- Use explicit return types for methods.
- Reference colors from `AppTheme` in `lib/theme/theme.dart`. No hardcoded hex codes.
- Bind UI screens to state using `Consumer<AppState>`, `context.watch<AppState>()`, or `context.read<AppState>()`. Prefer `context.watch<T>()` over `Provider.of<T>(context)` and `context.read<T>()` over `Provider.of<T>(context, listen: false)`. Use `context.read<T>()` in button callbacks and lifecycle methods.
- Log errors with clear service or page context prefixes to make debugging easy.
- Extract dialogs, detailed cards, or list items to `lib/widgets/` to promote modular codebase structure.
- Extract repetitive visual components to shared reusable widgets to maintain consistency.
- **Private Widgets over Helpers**: Always declare private `StatelessWidget` classes instead of helper methods returning `Widget`. Each builder method like `_buildSomething(ThemeData)` must be its own widget in a separate file under `lib/tools/<name>/` or `lib/widgets/`. Never write inline `Widget _buildFoo(...)` methods in a stateful widget — they break element tree diffing, prevent const optimization, and bloat the page file. Extract `FooWidget` into its own file with a clean constructor API.
- **Const Constructors**: Prefer using `const` constructors for widgets and in `build()` methods where possible to reduce rebuilds.
- **Lazy Lists**: Prefer `ListView.builder` or slivers for dynamic or performance-sensitive lists.

---

## Tool Architecture

### 1. Tool Structure
Each tool lives in its own folder under `lib/tools/<name>/` with exactly:
- **`config.dart`** — Tool metadata (name, icon, route, color). Exports a static `const ToolModel` via a tool class.
- **`<name>_page.dart`** — Tool entry point page. Must be a thin coordinator — only `StatefulWidget` state + build method that composes extracted widgets. No inline `Widget _buildFoo(...)` methods.
- **Additional widget files** — Every visual component gets its own file (e.g. `<name>_display.dart`, `<name>_grid.dart`, `<name>_toolbar.dart`, `<name>_history_panel.dart`). Never inline builders in the page file.

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
  );
}
```

### 4. Routing
Routes are auto-generated from `ToolRegistry.all` in `lib/app.dart`. Each tool's `route` field becomes a GoRouter path. The `_pageForTool()` switch maps tool IDs to page widgets.

### 5. Storage
- **Per-tool settings**: use `DatabaseService.instance` (`lib/services/database_service.dart`) — singleton with `setSetting`/`getSetting`/`getAllSettings`.
- **Global settings** (theme, compact mode, sort): go through `AppState`, which persists via `SharedPreferences` (`lib/services/settings_service.dart`).

### 6. Bidirectional Sync
- Tools that require data syncing can implement `SyncDelegate` and register with `SyncService`. For database storage tracking, protocol flows, and serialization requirements, see the detailed technical specification in [AGENTS.detail.md](file:///C:/dev/flutter/toolkit/AGENTS.detail.md).


---

## Core Guardrails

### 1. State Management & UI Binding
- Standard: `provider` + `ChangeNotifier` (`AppState` in `lib/providers/app_state.dart`).
- Ensure UI automatically rebuilds by binding via standard consumers.

### 2. Styling & Layouts
- Theme variables from `AppTheme`: `background`, `surface`, `accentBlue`, `accentGreen`, `accentAmber`, `accentRed`.
- Responsive layout container: `ResponsiveLayout` (`lib/widgets/responsive_layout.dart`).

### 3. Navigation
- Standard: `go_router` for declarative routing.

---

## Dependencies

Dependencies in `pubspec.yaml`. Check there before adding new packages.

---

## Verification Procedures

*Note: Formatting and static analysis are only required when Dart/source code files are changed. They are not necessary when only markdown documentation, images, or static assets are modified.*

1. **Formatting**: `dart format ./lib`
2. **Analysis**: `flutter analyze`
