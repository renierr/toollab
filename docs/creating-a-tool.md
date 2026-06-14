# Tool Development Guide (Architecture, Adaptation & Creation)

This guide outlines how to build, adapt, and register tools within the ToolLab ecosystem. It details layout patterns, fullscreen configuration, responsive layout adaptations, and the usage of standard reusable widgets.

---

## 1. Tool Folder Structure

Each tool lives in its own directory under `lib/tools/<name>/`. Component widgets ALWAYS go in a `widgets/` subfolder:
```
lib/tools/<name>/
  config.dart           - Metadata (id, name, description, icon, route, colors, fullscreen)
  <name>_page.dart      - Coordinator page widget (composes extracted widgets, no inline helper build methods)
  <name>_state.dart     - Optional ChangeNotifier for tool-specific state management
  <name>_colors.dart    - Optional tool-specific color palette
  widgets/              - REQUIRED: every tool-specific component widget gets its own file here
    <name>_display.dart
    <name>_toolbar.dart
```
Only `config.dart`, `<name>_page.dart`, the optional `<name>_state.dart` / `<name>_colors.dart`, and non-widget files (enums, models) sit at the tool root — all widget files live under `widgets/`.

---

## 2. Fullscreen Configuration

By default, pages are wrapped in a standard `Scaffold` with an `AppBar`. However, for complex tools (e.g. calculator, drawing grids), you can enable `fullscreen` to hide the top app bar and reclaim vertical space.

### Enabling Fullscreen
Set `fullscreen: true` in the tool's `ToolModel` configuration within `config.dart`:
```dart
static const ToolModel config = ToolModel(
  id: 'calculator',
  name: 'Calculator',
  description: 'Proportional responsive calculator',
  icon: Icons.calculate_outlined,
  route: '/calculator',
  accentColor: AppTheme.accentBlue,
  sectionId: 'utilities',
  fullscreen: true, // <-- Enables fullscreen mode
);
```

### Fullscreen Layout Behavior
When `fullscreen: true` is set:
- The standard `AppBar` is hidden.
- The `ToolLayout` widget automatically overlays a circular `FloatingBackButton` in the top-left corner.
- If any `actions` (such as settings/refresh buttons) are provided to `ToolLayout`, they are automatically formatted and overlaid as floating circular buttons in the top-right corner, matching the back button.

---

## 3. Responsive Adaptation

All tools must handle phone rotation, split-screen mode, and landscape views seamlessly without UI overflows.

### Adaptive Layout Strategy
1. **Aspect Ratio / Constraint Switching**:
   Do **not** use `MediaQuery.of(context).orientation` to check orientation. Instead, wrap layout configurations in `ResponsiveOrientationLayout` (defined in `lib/widgets/responsive_orientation_layout.dart`), which switches layouts based on width-to-height aspect ratio constraints.
   
2. **Handling Restrained Height (Landscape / Small Screens)**:
   - Make headers, displays, and padding shrink proportionally or hide when vertical height is limited (detect with `constraints.maxHeight < 400`).
   - Use `FittedBox` or flex sizing on text inside buttons to avoid vertical squishing.
   - Use compact modes on toolbar elements (e.g. hide text labels and only show icons).

Example of adapting layouts based on dimensions:
```dart
LayoutBuilder(
  builder: (context, constraints) {
    final isShort = constraints.maxHeight < 400;
    final isWide = constraints.maxWidth >= 500;
    final displayHeight = isShort ? 44.0 : 95.0;

    return Column(
      children: [
        SizedBox(height: displayHeight, child: CalculatorDisplay(isShort: isShort)),
        CalculatorToolbar(isShort: isShort),
        Expanded(child: CalculatorGrid()),
      ],
    );
  }
)
```

---

## 4. Reusable Common Widgets

Always reuse existing custom widgets in `lib/widgets/` to ensure visual consistency and avoid duplicate presentation logic.

### Standard Shared Widgets
- **`ToolLayout`** (`lib/widgets/tool_layout.dart`):
  The standard scaffold wrapper. Mandated for all tool pages.
  ```dart
  ToolLayout(
    title: 'My Tool',
    fullscreen: MyTool.config.fullscreen,
    actions: [
      IconButton(icon: const Icon(Icons.refresh), onPressed: _onReset),
    ],
    child: MyToolContent(),
  )
  ```
- **`ToolChip`** (`lib/widgets/tool_chip.dart`):
  A clean action chip button for toolbars. Supports selection states, optional icons, and conditional labels.
  ```dart
  ToolChip(
    icon: Icons.science_outlined,
    label: 'SCI',
    selected: _showScientific,
    onTap: _toggleSci,
    showLabel: !isShort, // Automatically hides label to save horizontal space
  )
  ```
- **`ResponsiveOrientationLayout`** (`lib/widgets/responsive_orientation_layout.dart`):
  Aspect-ratio constraint switcher providing `portrait` and `landscape` layout options.
- **`FloatingBackButton`** (`lib/widgets/floating_back_button.dart`):
  Used by `ToolLayout` for fullscreen navigation overlay.
- **`ToolCard`** (`lib/widgets/tool_card.dart`):
  Standardized card presentation layout for selection interfaces.

---

## 5. Tool-Specific State Management

Tools with significant internal state (loading states, item lists, upload progress, etc.) should extract their own `ChangeNotifier` instead of polluting `AppState`.

### Creating a State Provider

Create `<name>_state.dart` at the tool root:

```dart
import 'package:flutter/material.dart';
import 'package:tool_lab/services/database_service.dart';

class MyNewToolState extends ChangeNotifier {
  List<MyItem> _items = [];
  bool _isLoading = false;

  List<MyItem> get items => _items;
  bool get isLoading => _isLoading;

  Future<void> loadItems() async {
    _isLoading = true;
    notifyListeners();
    try {
      // load from DB or API
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
```

### Auto-Registration via `config.dart`

Add the `stateProviders` field to your `ToolModel` — providers are auto-collected by `ToolRegistry.all` into `main.dart`'s `MultiProvider`. No manual wiring needed.

```dart
stateProviders: () => [
  ChangeNotifierProvider<MyNewToolState>(
    create: (_) => MyNewToolState(),
  ),
],
```

### Accessing in Pages

Pages read from their own provider instead of `AppState`:

```dart
final myState = context.watch<MyNewToolState>();    // reactivity
context.read<MyNewToolState>().loadItems();           // one-shot
```

For global sync config (`syncEnabled`, `syncServerUrl`), still read from `AppState`:

```dart
final appState = context.watch<AppState>();
final syncOk = appState.syncEnabled && appState.syncServerUrl.isNotEmpty;
```

### Standalone by Design

Tool state providers should read sync config directly from `DatabaseService.instance` (async) rather than depending on `AppState`. This keeps them fully standalone and auto-registerable.

---

## 6. Creating a New Tool (Step-by-Step)

### Step 1: Write `config.dart`
```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';

import 'my_new_tool_page.dart';
import 'my_new_tool_state.dart';        // if tool has its own state

class MyNewTool {
  MyNewTool._();
  static ToolModel get config => ToolModel(
    id: 'my-new-tool',
    name: 'My New Tool',
    description: 'What it does',
    icon: Icons.star_outlined,
    route: '/my-new-tool',
    accentColor: AppTheme.accentTeal,
    sectionId: 'utilities',
    fileExtensions: ['ext1', 'ext2'],   // for local file picker
    shareTarget: ShareTargetConfig(       // for incoming shared files
      accept: ['application/octet-stream'],
    ),
    createPage: (sf) => const MyNewToolPage(),  // route auto-wired
    syncDelegateFactory: MyNewToolSyncDelegate.new,  // if sync needed
    stateProviders: () => [                // if tool needs state management
      ChangeNotifierProvider<MyNewToolState>(
        create: (_) => MyNewToolState(),
      ),
    ],
  );
}
```

### Step 2: Write `<name>_page.dart`
```dart
import 'package:flutter/material.dart';
import 'package:tool_lab/widgets/tool_layout.dart';
import 'config.dart';

class MyNewToolPage extends StatelessWidget {
  const MyNewToolPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ToolLayout(
      title: MyNewTool.config.name,
      fullscreen: MyNewTool.config.fullscreen,
      child: Center(child: Text('Hello World')),
    );
  }
}
```

### Step 3: Register in `lib/core/tool_registry.dart`
Add the import and config to the list — **this is the only manual wiring needed** (routing, sync delegate registration, and file extensions are all auto-discovered from `ToolModel`):
```dart
import 'package:tool_lab/tools/my_new_tool/config.dart';

class ToolRegistry {
  static List<ToolModel> get all => [
    ...
    MyNewTool.config,
  ];
}
```

### Step 5: Verify & Clean
Before committing, always run:
```bash
dart format ./lib
flutter analyze
```

## 7. Tool ID Hygiene

**Rule:** The tool ID string lives in exactly one place — `config.dart`. Every other file that needs to reference the tool ID must import `config.dart` and use `MyTool.config.id` instead of hardcoding the string.

```dart
// ✓ CORRECT — references the single source of truth
await DatabaseService.instance.getToolDatabase(NotesTool.config.id);

// ✗ WRONG — duplicates the ID string
await DatabaseService.instance.getToolDatabase('notes');
```

This applies everywhere: pages, sync delegates, DB helpers, archive classes, and any other file referencing the tool's namespace. A grep for the literal tool ID string should return only the `config.dart` definition.
