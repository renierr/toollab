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
- **Git Write Consent**: Never run git write operations without fresh explicit approval.
- Never mention AI agents in commit messages or code.
- **Resilience to Rejected Commands**: Continue task if a command is rejected.
- **State Management & Data Flow**: Always channel app state through providers in `lib/providers/`.
- **Small Screen Fitting**: Use responsive layouts (`Wrap`, scrollable/grid metrics) in dialogs/modals/cards.
- **Cross-Platform Checks**: Check platform before using platform-specific APIs (sensors, battery, etc.).
- **Prevent Duplicated UI/Dialog Code**: Extract custom dialogs/overlays to `lib/widgets/`.
- **Use Existing Custom Widgets**: Reuse existing widgets rather than writing from scratch.

---

## PREFER

- Short, concise answers. English for code/docs.
- Explicit return types. Reference colors from `AppTheme` in `lib/theme/theme.dart`.
- Bind UI with `Consumer<AppState>`, `context.watch<AppState>()`, or `context.read<AppState>()`.
- Extract dialogs/cards to `lib/widgets/`.
- **Private Widgets over Helpers**: Prefer private `StatelessWidget` classes over helper methods returning `Widget`.
- **Const Constructors**: Use `const` constructors where possible.
- **Lazy Lists**: Prefer `ListView.builder` or slivers for dynamic lists.

---

## Core Guardrails

### 1. State Management & UI Binding
- Standard: `provider` + `ChangeNotifier` (`AppState` in `lib/providers/app_state.dart`).

### 2. Styling & Layouts
- Theme: `AppTheme` variables (`background`, `surface`, `accentBlue`, `accentGreen`, `accentAmber`, `accentRed`).
- Responsive container: `ResponsiveLayout`.

### 3. Navigation
- Standard: `go_router` for declarative routing.

---

## Dependencies

Dependencies in `pubspec.yaml`. Check there before adding new packages.

---

## Verification Procedures

1. **Formatting**: `dart format ./lib`
2. **Analysis**: `flutter analyze`
