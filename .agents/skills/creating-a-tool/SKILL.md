---
name: creating-a-tool
description: Guidelines and playbook for designing, developing, and integrating new tools into the ToolLab application. Use this skill when you need to create a tool, add a new tool, or add tools to the project.
triggers:
  - create a tool
  - new tool
  - add tool
  - tool design
  - tool template
  - register tool
  - share target
  - open chooser
  - share chooser
---

# Creating a New Tool in ToolLab

This guide describes how to create, integrate, and customize a new tool within the **ToolLab** application. It covers metadata configuration, file sharing target definitions, in-app open/share handlers, back navigation, and common widgets.

> [!IMPORTANT]
> Code examples in this playbook can get outdated. Always check the real code of existing registered tools (e.g. `lib/tools/pdf_viewer/config.dart`, `lib/tools/calculator/config.dart`, or `lib/tools/notes/config.dart`) to reference up-to-date config structures, shared handlers, and dependencies.

---

## 1. Tool Folder Structure

Every tool must live in its own directory under `lib/tools/<name>/` and should maintain clean modular separation of code:

```
lib/tools/<name>/
  ├── config.dart             - Tool metadata (ToolModel) and configurations
  ├── <name>_page.dart        - Coordinator page widget (Stateless/Stateful coordinations)
  ├── <name>_state.dart       - Optional ChangeNotifier for tool-specific state management
  ├── widgets/                - Private widgets for page components (never inline builder methods in page)
  │    ├── <name>_display.dart
  │    └── <name>_toolbar.dart
  └── <name>_colors.dart      - Optional. Cyberpunk/tool-specific custom color definitions
```

---

## 2. Configuration & Metadata (`config.dart`)

Define the tool's `ToolModel` inside `lib/tools/<name>/config.dart`. Use a `static ToolModel get config =>` getter (not `const`) — the localization resolvers below are closures, so the model can't be `const`:

```dart
import 'package:flutter/material.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';

class MyNewTool {
  MyNewTool._();

  static ToolModel get config => ToolModel(
    id: 'my-new-tool',
    name: 'My New Tool',                          // raw English fallback
    description: 'A brief explanation of what it does', // raw English fallback
    icon: Icons.star_outlined,
    route: '/my-new-tool',
    accentColor: AppTheme.accentTeal,
    sectionId: 'utilities', // 'utilities', 'sensors', etc.
    // Localized name/description — see §2.2. Add the matching keys to both ARB files.
    nameL10n: (l10n) => l10n.toolNameMyNewTool,
    descriptionL10n: (l10n) => l10n.toolDescMyNewTool,
    fullscreen: true,       // Hides default AppBar, overlays floating back buttons
    shareTarget: ShareTargetConfig(
      accept: ['application/pdf', 'text/markdown'], // MIME types accepted by this tool
    ),
  );
}
```

### 2.1. ToolModel Configuration Properties

> [!NOTE]
> This properties table can get outdated. Always check `lib/core/tool_model.dart` for the actual up-to-date constructor properties of the `ToolModel` class.

| Property | Type | Description |
| :--- | :--- | :--- |
| `id` | `String` | Unique string identifying the tool (used in routing and database namespaces). |
| `name` | `String` | Raw English display name. Acts as a fallback — the UI shows `nameL10n` when set. |
| `description` | `String` | Raw English summary (fallback for `descriptionL10n`). |
| `icon` | `IconData` | Icon representing the tool in drawers and chooser dialogs. |
| `route` | `String` | Path mapping for GoRouter (e.g. `/my-new-tool`). |
| `accentColor` | `Color` | Base thematic color (must reference AppTheme). |
| `sectionId` | `String` | Category section in launchers (e.g. `'utilities'`, `'sensors'`). |
| `nameL10n` | `String Function(AppLocalizations)?` | Localized name resolver, e.g. `(l10n) => l10n.toolNameMyTool`. Takes `AppLocalizations`, never a `BuildContext`. |
| `descriptionL10n` | `String Function(AppLocalizations)?` | Localized description resolver. |
| `fullscreen` | `bool` | Set `true` to hide standard AppBar and enable floating overlay buttons. |
| `shareTarget` | `ShareTargetConfig?` | Declares accepted MIME types. Matches files shared natively or internally. |
| `stateProviders` | `List<SingleChildWidget> Function()?` | Optional factory returning tool-specific `ChangeNotifierProvider`s. Auto-collected by `ToolRegistry.all` into `main.dart`. |
| `androidProcessIsolated` | `bool` | Set `true` to run this tool in a separate Android OS process and task for split-screen/multi-window. |

### 2.2. Localizing the Tool Name & Description

Tool names, descriptions, and section titles are **localized per-tool** — there is no central `id → string` switch. A new tool only edits its own `config.dart` plus the ARB files.

1. Add keys to **both** `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb` (template `en` first, e.g. `toolNameMyNewTool`, `toolDescMyNewTool`). German names may stay partly English where that reads better (`NFC Tag Lab`, `Fast Drop`).
2. Set `nameL10n` / `descriptionL10n` in `config.dart` (see example above). Run `flutter gen-l10n`.
3. Keep the raw `name` / `description` as sensible English fallbacks — they show if a resolver is omitted.
4. **Never read `.name` / `.description` directly for UI.** Display code resolves the localized value via `tool.localizedName(l10n)` / `tool.localizedDescription(l10n)`. The tool's own page title (`ToolLayout(title: ...)`) must use `MyNewTool.config.localizedName(l10n)` too. Non-UI uses (DB keys, logs) may keep the raw `name`.
5. Sections are localized the same way via `titleL10n` on `ToolSection` in `lib/core/tool_registry.dart`; read with `section.localizedTitle(l10n)`. You usually reuse an existing `sectionId` and don't touch this.

---

## 3. External & Internal Shared File Handling

To allow other tools or the operating system to share/open files in this tool, the coordinator page widget must support receiving a `SharedFile` parameter:

```dart
class MyNewToolPage extends StatefulWidget {
  final SharedFile? sharedFile;

  const MyNewToolPage({super.key, this.sharedFile});

  @override
  State<MyNewToolPage> createState() => _MyNewToolPageState();
}
```

### 3.1. Registering the Route in `lib/app.dart`
Map the router route definition in `_pageForTool` in `lib/app.dart`:
```dart
Widget _pageForTool(String id, Object? extra) {
  return switch (id) {
    'my-new-tool' => MyNewToolPage(sharedFile: extra as SharedFile?),
    // ... other tools
    _ => const OverviewPage(),
  };
}
```

### 3.2. Popped Navigation Requirement
When navigating internally to open/share files (e.g. clicking "Open" on the export success screen or sharing from a note), the app uses `GoRouter.of(context).push('/my-new-tool', extra: file)` instead of root replacement (`context.go`). This leaves the originating page in the stack.

To handle this, the tool's close/back button must check if it was opened from outside and pop the stack:
```dart
void _onClose() {
  if (widget.sharedFile != null) {
    // Opened internally/externally from outside the tool, pop back to note editor/overview
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/'); // Fallback
    }
  } else {
    // Opened manually via FileDropZone, clear state to display the drop zone again
    setState(() {
      _fileContent = null;
      _fileName = null;
    });
  }
}
```

### 3.3. Invoking Internal Open/Share Choosers
When exposing file "Open" or "Share" actions to users inside your tool, use `FileSaveHelper` to support in-app routing (extremely useful on Desktop where OS sharing is unsupported or fails):

- **Opening Files**:
  ```dart
  await FileSaveHelper.showOpenChooser(
    context: context,
    path: filePath,
    mimeType: mimeType,
  );
  ```
- **Sharing Files**:
  ```dart
  await FileSaveHelper.showShareChooser(
    context: context,
    path: filePath,
    mimeType: mimeType,
  );
  ```

> [!IMPORTANT]
> **Temp File Manager**: When creating temp files for open/share, always use `TempFileManager.createFile()` (`lib/helpers/temp_file_manager.dart`). It tracks the file and cleans up on page dispose (`cleanTracked()`) or app close (`cleanSession()`). Register cleanup via `onDispose(() => TempFileManager.cleanTracked())` — external apps get their own copy/handle, and internal tools read into memory immediately.

---

## 4. SQLite Storage & Cloud Syncing

### 4.1. SQLite Persistence
- **Per-Tool Settings**: For basic key-value preferences, use `DatabaseService.instance` (`lib/services/database_service.dart`). It provides a simple API to read/write settings scoped to a tool/section:
  ```dart
  // Save a preference
  await DatabaseService.instance.setSetting('my-tool', 'enable_feature_x', 'true');
  
  // Read a preference
  final isEnabled = await DatabaseService.instance.getSetting('my-tool', 'enable_feature_x');
  ```
- **Custom SQL Tables**: If your tool stores complex structured records (like a notes tool or history logs), define a database schema migration inside `DatabaseService` and write direct SQLite queries using the active database instance.

### 4.2. Bidirectional Cloud Sync (`SyncDelegate`)
To enable automatic, bidirectional cloud sync with the backend server for a tool's records:
1. Implement the `SyncDelegate` interface (`lib/services/sync_service.dart`) in your data manager or provider class:
   - `getLocalSyncRecords()`: Return all local active and deleted records (with `id`, `updatedAt`, `deleted` fields).
   - `getLocalRecordData(id)`: Return the full details of a specific record to push.
   - `savePulledRecord(...)`: Save or update a pulled record from the server.
   - `finalizeLocalSync(...)`: Mark the record as successfully synchronized.
2. Register it via `syncDelegateFactory: MyToolSyncDelegate.new` in the tool's `config.dart`. `AppState` collects it from `ToolRegistry.all` automatically — there is no manual registration step, and the global "Sync Now" button picks the tool up from there.

#### Per-Tool Sync Switch
Declaring `syncDelegateFactory` also makes the tool appear in the per-tool switch list on the sync settings page (`lib/widgets/tool_sync_switches.dart`), driven off the registry — nothing to add there.

- The switch is stored as a per-tool setting, `DatabaseService.setSetting(<tool id>, 'sync_enabled', ...)`, and **defaults to on**: a missing value reads as enabled, so a tool never loses sync on upgrade. Do not write a default at startup — the absence is the default.
- **Never call `SyncService.sync` directly.** Go through `AppState.syncWithBackend`, which filters disabled tools out before touching the network. That is the only gate, and it also covers tools that pass their own delegate instance.
- If the tool has its own sync button or an auto-sync-on-open, check `appState.isToolSyncEnabled(MyTool.config.id)` at the call site too — otherwise `syncWithBackend` returns `null` and the page reports "configure your server URL" when the real reason is the switch. Use the `coreSyncToolDisabled` string for the message.
- Device-local side effects must sit **outside** the gate. The treadmill Health Connect publisher is the reference case: it runs whether or not the treadmill tool takes part in backend sync, because writing a finished workout to Health Connect has nothing to do with the backend.

---

## 5. Reusable Common Widgets

> [!IMPORTANT]
> **Share & Extract Cross-Tool Widgets**: Always check `lib/widgets/` before building any UI component from scratch. Any presentation pattern, card style, toolbar row, status badge, or widget layout used by **two or more** different tools must be extracted into `lib/widgets/` as a shared, reusable widget. Tool-specific private widgets (prefixed with `_` or built locally) must stay in the tool's own folder under `lib/tools/<name>/widgets/`.

Avoid writing presentation logic or dropzones from scratch. Use existing widgets inside `lib/widgets/`:

- **`ToolLayout`** (`lib/widgets/tool_layout.dart`): Wraps the page, handles fullscreen floating buttons, overlays, and drawer states automatically.
- **`FileDropZone`** (`lib/widgets/file_drop_zone.dart`): Standard drag-and-drop file target container supporting custom icons, extensions, and styling parameters.
- **`ToolChip`** (`lib/widgets/tool_chip.dart`): toolbar action chip representing select state and optional label hiding.
- **`ResponsiveOrientationLayout`** (`lib/widgets/responsive_orientation_layout.dart`): Changes components/layouts based on aspect-ratio constraint thresholds rather than screen orientation.

---

## 6. Pain Points & Best Practices

1. **No Inline Build Helpers**: Never declare helper methods like `Widget _buildRow()`. Build tree diffing and performance require extracting them into separate files as private `StatelessWidget` classes (e.g., `widgets/my_tool_row.dart`).
2. **Dispose Cleanup**: Every stateful tool page must mix in `DisposeCleanup` (`lib/core/tool_page_state.dart`) and register cleanup inside `initState` via `onDispose(...)` instead of overriding `dispose()`.
3. **AppTheme Colors**: Reference colors via `AppTheme` (e.g. `AppTheme.accentTeal`) or context `Theme.of(context).colorScheme` rather than hardcoded hex codes.
4. **Android Integration**: For every new tool, maintain launcher entry points in `AndroidManifest.xml` (alias configuration), `MainActivity.kt` (routing handler), and `ShortcutHelper.kt` (icon control).
5. **Platform Support & Responsiveness**:
   - **Target Platforms**: Tools must support and run reliably on Android (the primary target OS), Windows, and Linux. iOS and macOS are not supported. Always verify platform scope before utilizing any native system API.
   - **Screen Sizes & Layouts**: Design defensively against different screen sizes, split-screen modes, and orientations. Re-use `ResponsiveOrientationLayout` and wrap inputs/actions in scrollable/wrapping views (e.g. `Wrap` or scrollable dialog layouts) to prevent UI overflow on smaller screens.
6. **Dependencies & Version Management**:
   - Always check `pubspec.yaml` to see if a suitable dependency is already available before proposing to add a new package.
   - If a new dependency is absolutely necessary, only use well-maintained, modern packages and always target their latest stable versions.
   - Never add or modify dependencies in `pubspec.yaml` directly—always present the proposed package and version to the user first and ask them to add it.
7. **Database Test Isolation**: If a new tool adds database tables, any unit/widget tests must override the database path using `inMemoryDatabasePath` on `DatabaseService.instance` and close the connection in `tearDownAll` to ensure test state is clean and fully isolated in memory.
8. **Const Constructors**: Prefer using `const` constructors for widgets and in `build()` methods where possible to reduce rebuild cycles.
9. **Lazy Lists**: Prefer `ListView.builder` or slivers for dynamic or performance-sensitive lists to keep frame rates high.
10. **State Management & UI Binding**:
    - **Global state** (theme, sync config, favorites): bind via `context.watch<AppState>()` / `context.read<AppState>()`.
    - **Tool-specific state**: extract into `<name>_state.dart` as a standalone `ChangeNotifier`, register via `stateProviders` in `ToolModel`. Pages then use `context.watch<MyToolState>()` instead of polling `AppState` for tool data.
    - Never update local state variables inside views for persistent/syncable data.
11. **Temporary Files**: Use `TempFileManager` (`lib/helpers/temp_file_manager.dart`) for all temp file creation — never raw `getTemporaryDirectory()`. Temp files are auto-tracked. Register cleanup via `onDispose(() => TempFileManager.cleanTracked())` on any StatefulWidget that creates temp files. Files from StatelessWidgets or static helpers are cleaned by `cleanSession()` on app close. External apps get their own copy/handle, and internal tools read into memory immediately — so cleanup on dispose is always safe.
12. **Tool ID References**: Never hardcode tool ID strings (e.g. `'fast-drop'`, `'notes'`) outside of `config.dart`. Reference them via `MyTool.config.id` everywhere else — pages, sync delegates, DB helpers, archive classes. This keeps IDs in a single source of truth and prevents drift.
13. **Android Process Isolation**: To run a tool in its own OS process/task on Android (enabling crash-free split-screen/multi-window usage alongside the main app), set `androidProcessIsolated: true` in `config.dart`, define a subclass in `MainActivity.kt` (e.g., `class MyToolActivity : MainActivity()`), register it in `AndroidManifest.xml` with its own `process` and `taskAffinity`, and add it to `ShortcutHelper.kt`'s `isolatedTools` list.

---

## 7. Standalone & Drawer App Icon Guidelines

When adding a new tool, a custom transparent launcher/drawer icon must be created and registered:

### 7.1. Generate the Transparent Icon
* Standalone builds and Android drawer aliases expect a clean, high-resolution (`512x512`), transparent-background PNG icon saved under `assets/logo/standalone/<tool-id>.png` (using the kebab-case tool ID, e.g. `sound-finder.png`).
* The icon should render the tool's configured accent color and corresponding `MaterialIcons` glyph.

> [!TIP]
> **Generating Icons Programmatically from MaterialIcons Font**:
> You can easily render a new high-quality transparent PNG icon using a simple headless Dart unit test. Load the font dynamically from the local Flutter SDK cache and paint the glyph onto a centered canvas:
> ```dart
> final flutterRoot = Platform.environment['FLUTTER_ROOT'];
> final fontPath = p.join(flutterRoot, 'bin', 'cache', 'artifacts', 'material_fonts', 'materialicons-regular.otf');
> final fontLoader = FontLoader('MaterialIcons');
> fontLoader.addFont(Future.value(ByteData.sublistView(await File(fontPath).readAsBytes())));
> await fontLoader.load();
> 
> final recorder = ui.PictureRecorder();
> final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 512, 512));
> final textPainter = TextPainter(
>   text: TextSpan(
>     text: String.fromCharCode(toolIconCodePoint),
>     style: TextStyle(fontSize: 420.0, fontFamily: 'MaterialIcons', color: accentColor),
>   ),
>   textDirection: TextDirection.ltr,
> );
> textPainter.layout();
> textPainter.paint(canvas, Offset((512 - textPainter.width) / 2, (512 - textPainter.height) / 2));
> 
> final img = await recorder.endRecording().toImage(512, 512);
> final pngBytes = (await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
> await File('assets/logo/standalone/my-new-tool.png').writeAsBytes(pngBytes);
> ```
> Put this code in a standard `test('description', () async { ... })` block (not `testWidgets`) so that async file and image tasks run on the real event loop without hanging, and run the generator using `flutter test <path_to_test_file>`.

### 7.2. Copy to Android Mipmap Directories
Copy the generated PNG file to all Android density mipmap folders under `android/app/src/main/res/` using the snake-case tool name:
* `mipmap-mdpi/ic_launcher_<tool_id_in_snake_case>.png`
* `mipmap-hdpi/ic_launcher_<tool_id_in_snake_case>.png`
* `mipmap-xhdpi/ic_launcher_<tool_id_in_snake_case>.png`
* `mipmap-xxhdpi/ic_launcher_<tool_id_in_snake_case>.png`
* `mipmap-xxxhdpi/ic_launcher_<tool_id_in_snake_case>.png`

### 7.3. Configure Manifest & Shortcuts
1. **AndroidManifest.xml**: Locate the tool's `<activity-alias>` and update `android:icon` to reference the newly copied mipmap:
   ```xml
   android:icon="@mipmap/ic_launcher_my_new_tool"
   ```
2. **ShortcutHelper.kt**: Pinned home screen shortcuts automatically resolve the icon dynamically by looking up `"ic_launcher_" + toolId.replace("-", "_")` in the mipmap resources. By following this snake-case naming scheme, shortcuts will automatically use the custom icon.


