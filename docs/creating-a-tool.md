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
`config.dart`, `<name>_page.dart`, and the optional `<name>_state.dart` / `<name>_colors.dart` sit at the tool root. Non-widget files (enums, models, codecs, parsers, services) may sit at the tool root or, when it improves clarity, be grouped into descriptively named subfolders (e.g. `converters/`, `models/`). All widget files live under `widgets/` — subfolders are for non-widget logic only.

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
    name: 'My New Tool',                 // raw English fallback
    description: 'What it does',         // raw English fallback
    icon: Icons.star_outlined,
    route: '/my-new-tool',
    accentColor: AppTheme.accentTeal,
    sectionId: 'utilities',
    nameL10n: (l10n) => l10n.toolNameMyNewTool,        // localized; add keys to both ARB files
    descriptionL10n: (l10n) => l10n.toolDescMyNewTool,
    fileExtensions: ['ext1', 'ext2'],   // for local file picker
    shareTarget: ShareTargetConfig(       // for incoming shared files
      accept: ['application/octet-stream'],
    ),
    createPage: (sf) => const MyNewToolPage(),  // route auto-wired
    syncDelegateFactory: MyNewToolSyncDelegate.new,  // if sync needed
    backgroundTasks: () => [MyNewToolBackground.task],  // if it runs on a schedule
    stateProviders: () => [                // if tool needs state management
      ChangeNotifierProvider<MyNewToolState>(
        create: (_) => MyNewToolState(),
      ),
    ],
  );
}
```

> **Localization:** names, descriptions, and section titles are localized per-tool — no central switch. Set `nameL10n` / `descriptionL10n` (and `titleL10n` on a `ToolSection`), add the matching keys to both `app_en.arb` and `app_de.arb`, then run `flutter gen-l10n`. The raw `name` / `description` stay as fallbacks. UI must read `tool.localizedName(l10n)` / `tool.localizedDescription(l10n)` / `section.localizedTitle(l10n)` — including the tool's own `ToolLayout(title: MyNewTool.config.localizedName(l10n))`. Never render `.name` / `.description` / `.title` directly.

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

### Step 4: Create the Android Launcher Icon
Create a transparent `512x512` PNG at
`assets/logo/standalone/<tool-id>.png`. Existing icons are generated from the
tool's Material icon glyph and use its configured accent color.

Regenerate all Android tool icons after adding or replacing a source PNG:
```bash
dart run tool/sync_launcher_icons.dart
```

The script creates legacy PNG fallbacks and Android 8+ adaptive-icon resources.
The latter prevents Pixel Launcher from applying legacy-icon normalization that
makes drawer icons look smaller.

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

---

## 8. Sync-Capable Tools & the Per-Tool Switch

Declaring a `syncDelegateFactory` in `config.dart` does two things: it registers the delegate with the global "Sync Now" button, and it makes the tool appear in the per-tool switch list on the sync settings page. Both are automatic — there is nothing to register by hand, and no edit to `tool_sync_switches.dart` or `sync_settings_page.dart`.

**The switch defaults to on.** A tool with no stored value counts as enabled, so a newly sync-capable tool participates immediately and an existing one is never silently switched off by an upgrade.

**Never call `SyncService.sync` directly.** Always go through `AppState.syncWithBackend`, which filters out disabled tools before touching the network. This is the only gate, and it covers the tools that pass their own delegate instance too. The one exception is a background task (section 10): there is no widget tree there to read a provider from, so it repeats the same gate itself.

If the tool has its own sync button or an auto-sync-on-open, respect the switch at the call site as well, so the user gets an honest message instead of a silent no-op:

```dart
// auto-sync on open — skip quietly
if (appState.syncEnabled &&
    appState.syncServerUrl.isNotEmpty &&
    appState.isToolSyncEnabled(MyNewTool.config.id)) {
  appState.syncWithBackend([MyNewToolSyncDelegate()]);
}

// manual button — say why nothing happened
if (!appState.isToolSyncEnabled(MyNewTool.config.id)) {
  _toast(l10n.coreSyncToolDisabled);
  return;
}
```

Without the call-site check, `syncWithBackend` returns `null`, which existing pages report as "configure your server URL" — misleading when the real reason is the switch.

---

## 9. Background Tasks (Running While the App Is Closed)

A tool that has to act on an interval — pull new data, publish something, clean up — declares a `BackgroundTask` and lets `BackgroundTaskService` (`lib/services/background_task_service.dart`) schedule it on Android WorkManager. Do not add a plugin, a service or a timer of your own.

```dart
// my_new_tool_background.dart
static final BackgroundTask task = BackgroundTask(
  id: '${MyNewTool.config.id}-refresh',
  defaultInterval: const Duration(hours: 4),
  requiresNetwork: true,          // hold the run back until there is a connection
  run: _run,
);

static Future<BackgroundTaskResult> _run() async {
  // ... work ...
  return const BackgroundTaskResult.done('42 refreshed');
}
```

```dart
// config.dart
backgroundTasks: () => [MyNewToolBackground.task],
```

That is the whole registration: `BackgroundTaskService.init()` in `main.dart` collects tasks from `ToolRegistry.all` and applies each stored schedule, and the same registry resolves the task id in the headless isolate.

**Give the user the switch.** Drop a `BackgroundTaskTile` (`lib/widgets/background_task_tile.dart`) into the tool's settings page, guarded by `BackgroundTaskService.isSupported` (Android only). It renders the interval picker, a "Run now" action and the last run's outcome; the intervals themselves come from `BackgroundTaskService.intervalChoices`, so every tool offers the same steps.

**What a scheduled run may and may not do.** It executes in a headless Flutter engine — plugins are registered, so platform channels work, but:

- **No UI, so no permission requests.** No Activity exists; asking throws or hangs. A missing grant must degrade to doing less, never to a prompt.
- **No providers and no localizations.** Reach state through services (`DatabaseService`, `SettingsService`), never through `AppState`. A gate that lives in `AppState` has to be repeated.
- **It is a second isolate with its own database connection.** The service takes a settings-table lock so a task cannot run twice at once, but any cooldown or "last run" marker of your own must be persisted, not static.
- **Ten minutes, then killed.** Only incremental work belongs here; long imports stay on the tool's own screen where a `BackgroundWorkLease` can hold the process.
- **Be idempotent.** The platform can stop and retry a run at any point, and `BackgroundTaskResult.failed` asks it to.

**The interval is a ceiling, not a schedule.** WorkManager's floor is 15 minutes, and in Doze a run waits for the next maintenance window — hours, on an idle phone. Nothing short of a foreground service changes that, so never build a feature that depends on a run happening *at* a particular time.

---

## 10. Android Multi-Process Isolation (Running in Parallel)

To allow a tool (such as `calculator` or `pdf-viewer`) to run in parallel with the main app or other tools on Android (e.g. in native split-screen or multi-window mode) without FFI crashes (`rhttp`/`flutter_rust_bridge`) or SQLite database locks, configure it to run in a separate process:

1. **Enable isolated property in Dart**:
   Set `androidProcessIsolated: true` in the tool's `ToolModel` config inside `config.dart`.

2. **Add Activity in Kotlin**:
   In [MainActivity.kt](file:///C:/dev/flutter/toolkit/android/app/src/main/kotlin/de/renier/tool_lab/MainActivity.kt), declare a subclass of `MainActivity` at the bottom of the file:
   ```kotlin
   class MyToolActivity : MainActivity()
   ```

3. **Update Manifest**:
   In [AndroidManifest.xml](file:///C:/dev/flutter/toolkit/android/app/src/main/AndroidManifest.xml), declare the new activity with a unique process name and task affinity:
   ```xml
   <activity
       android:name="de.renier.tool_lab.MyToolActivity"
       android:exported="false"
       android:launchMode="singleTask"
       android:process=":my_tool"
       android:taskAffinity="de.renier.tool_lab.my_tool"
       android:theme="@style/LaunchTheme"
       android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
       android:hardwareAccelerated="true"
       android:windowSoftInputMode="adjustResize">
       <meta-data
         android:name="io.flutter.embedding.android.NormalTheme"
         android:resource="@style/NormalTheme"
         />
   </activity>
   ```
   Then change the tool's `<activity-alias>` to point to this target activity:
   ```xml
   <activity-alias
       android:name="de.renier.tool_lab.MyToolAlias"
       android:targetActivity="de.renier.tool_lab.MyToolActivity"
       ...
   ```

4. **Register in Kotlin shortcut helper**:
   In [ShortcutHelper.kt](file:///C:/dev/flutter/toolkit/android/app/src/main/kotlin/de/renier/tool_lab/ShortcutHelper.kt), add the tool ID to the `isolatedTools` set inside `toolIdToActivityClassName()`.
