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
- **Use Existing Custom Widgets**: Always reuse existing custom widgets in `lib/widgets/` (such as `ToolCard`, `ResponsiveLayout`) rather than writing from scratch. Check the codebase for existing reusable options before writing presentation code.

---

## PREFER

- Keep answers extremely short and concise. English for code/docs.
- Use explicit return types for methods.
- Reference colors from `AppTheme` in `lib/theme/theme.dart`. No hardcoded hex codes.
- Bind UI screens to state using `Consumer<AppState>`, `context.watch<AppState>()`, or `context.read<AppState>()`. Prefer `context.watch<T>()` over `Provider.of<T>(context)` and `context.read<T>()` over `Provider.of<T>(context, listen: false)`. Use `context.read<T>()` in button callbacks and lifecycle methods.
- Log errors with clear service or page context prefixes to make debugging easy.
- Extract dialogs, detailed cards, or list items to `lib/widgets/` to promote modular codebase structure.
- Extract repetitive visual components to shared reusable widgets to maintain consistency.
- **Private Widgets over Helpers**: Prefer declaring private `StatelessWidget` classes instead of helper methods returning `Widget` to optimize element tree lifecycles and rebuilds.
- **Const Constructors**: Prefer using `const` constructors for widgets and in `build()` methods where possible to reduce rebuilds.
- **Lazy Lists**: Prefer `ListView.builder` or slivers for dynamic or performance-sensitive lists.

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
