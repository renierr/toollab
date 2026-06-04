# Creating a New Tool

## 1. Create the tool folder

```
lib/tools/<name>/
  config.dart
  <name>_page.dart
```

## 2. Write `config.dart`

All tools must belong to a section defined in `ToolRegistry.sections`
(`lib/core/tool_registry.dart`). Reuse existing sections if the tool fits;
add a new section only if it doesn't fit any existing one.

```dart
import 'package:flutter/material.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';

class MyNewTool {
  MyNewTool._();
  static const ToolModel config = ToolModel(
    id: 'my-new-tool',
    name: 'My New Tool',
    description: 'What it does',
    icon: Icons.star_outlined,
    route: '/my-new-tool',
    accentColor: AppTheme.accentTeal,
    sectionId: 'utilities',          // must match a key in ToolRegistry.sections
  );
}
```

## 3. Write `<name>_page.dart`

- Extend `StatefulWidget` or `StatelessWidget`.
- Use `ToolLayout` from `lib/widgets/tool_layout.dart` for the shared scaffold wrapper.
- Use platform checks (`Platform.isWindows`, etc.) before calling platform-specific APIs.
- Subscribe to app state via `context.watch<AppState>()` / `context.read<AppState>()`.
- Store per-tool settings via `DatabaseService.instance.setSetting(toolId, key, value)`.
- Extract widgets used by 2+ tools to `lib/widgets/`.

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/widgets/tool_layout.dart';

class MyNewToolPage extends StatelessWidget {
  const MyNewToolPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ToolLayout(
      title: 'My New Tool',
      child: Center(child: Text('Hello')),
    );
  }
}
```

## 4. Register in `lib/core/tool_registry.dart`

```dart
import 'package:tool_lab/tools/my_new_tool/config.dart';

class ToolRegistry {
  static const List<ToolModel> all = [
    CalculatorTool.config,
    BubbleLevelTool.config,
    EmfDetectorTool.config,
    DeviceInfoTool.config,
    MyNewTool.config,  // <-- add here
  ];
}
```

If the tool needs a new section, add it to `ToolRegistry.sections`.

## 5. Add route in `lib/app.dart`

Import the page and add a `case` to the `_pageForTool()` switch:

```dart
import 'package:tool_lab/tools/my_new_tool/my_new_tool_page.dart';

Widget _pageForTool(String id) {
  return switch (id) {
    'calculator' => const CalculatorPage(),
    'bubble-level' => const BubbleLevelPage(),
    'emf-detector' => const EmfDetectorPage(),
    'device-info' => const DeviceInfoPage(),
    'my-new-tool' => const MyNewToolPage(),  // <-- add here
    _ => const OverviewPage(),
  };
}
```

Routes are auto-generated from `ToolRegistry.all` — GoRouter picks up each
tool's `route` field automatically.

## 6. Storage per tool

Database is already available via `DatabaseService.instance`:

```dart
import 'package:tool_lab/services/database_service.dart';

// Save setting
await DatabaseService.instance.setSetting('my-new-tool', 'key', 'value');

// Read setting
final val = await DatabaseService.instance.getSetting('my-new-tool', 'key');

// Read all settings for this tool
final allSettings = await DatabaseService.instance.getAllSettings('my-new-tool');
```

Global settings (theme, compact mode, sort order) go through `AppState`
which persists them via `SharedPreferences`.

## 7. Verification

Before submitting, run both formatting and analysis:

```bash
dart format ./lib
flutter analyze
```
