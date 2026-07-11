# ToolLab

**ToolLab** is a privacy-first, multi-platform utility toolkit for **Android** and **Windows**. No accounts. No tracking. Just tools.

---

## Tools

### Sensors
| Tool | Description |
|------|-------------|
| **Bubble Level** | Precision spirit level using the accelerometer with real-time animated bubble |
| **EMF Detector** | Electromagnetic field readings via magnetometer with peak-hold tracking |
| **Sound Finder** | Locate unwanted sounds with FFT spectrum analysis, spectrogram, and counter-tone generator |
| **NFC Tag Lab** | Read and write NFC tags |
| **GPS Location Store** | Save and manage GPS waypoints with map view |
| **Bluetooth Scanner** | Discover and inspect nearby Bluetooth devices |
| **Treadmill Control** | Control treadmill speed and incline over Bluetooth |

### Utilities
| Tool | Description |
|------|-------------|
| **Calculator** | Clean 4-function calculator with haptic feedback |
| **PDF Viewer** | View PDF documents |
| **Notes** | Rich text notes with cloud sync |
| **Grocery List** | Shared grocery lists with sync |
| **Markdown Viewer** | Render and preview Markdown files |
| **Image Viewer** | Browse and inspect images with metadata |
| **Fast Drop** | Share files between devices on the same network |
| **Images to PDF** | Convert image sequences to PDF documents |
| **Chiptune Player** | Play tracker modules and chiptune audio files |
| **Focus Noise** | Ambient soundscapes and breathing exercises |
| **Signature Creator** | Draw and export signatures with sync |
| **QR Code** | Scan and generate QR codes |
| **Document Scanner** | Scan documents using the camera |
| **AI Chat** | Conversational AI with local model support |
| **Hex Editor** | Inspect and edit binary files |
| **File Converter** | Convert between file formats |
| **Sketch Board** | Freeform drawing canvas with sync |
| **Unit Converter** | Convert between measurement units |
| **Code Highlight & Edit** | Syntax-highlighted code viewer and editor |
| **String Transformer** | Transform text with various operations |

### Information
| Tool | Description |
|------|-------------|
| **Device Info** | Hardware, software, battery, and system details |

---

## Developer Guide

### Architecture

```
lib/
  app.dart              — GoRouter + MaterialApp.router setup
  main.dart             — Entry point with MultiProvider initialization
  constants.dart        — App version and name constants
  core/
    tool_model.dart       — ToolModel, ToolSection definitions
    tool_registry.dart    — Central registry of all tools (3 sections, 28 tools)
    tool_page_state.dart  — DisposeCleanup mixin for tool pages
  helpers/              — File save, temp files, WAV encoding, etc.
  l10n/                 — Localization (en, de) via ARB + gen_l10n
  pages/                — Routing shell pages (overview, settings, about, maintenance)
  providers/
    app_state.dart        — Global ChangeNotifier (language, theme, sync state)
  services/             — Database, settings, sync, wake lock, foreground service
  theme/                — Material 3 light/dark theme, AppTheme colors
  tools/                — 28 tool directories, each with a self-contained layout
  widgets/              — Shared reusable widgets (ToolCard, ResponsiveLayout, etc.)
```

Each tool lives under `lib/tools/<name>/` and follows a standard layout:
```
lib/tools/<name>/
  config.dart            — ToolModel metadata (id, name, icon, route, section)
  <name>_page.dart       — Coordinator page (composes widgets, no inline builders)
  <name>_state.dart      — Optional tool-specific ChangeNotifier
  widgets/               — Component widgets in separate files
```

### State Management

- **Global state**: `AppState` (`lib/providers/app_state.dart`) — theme, locale, compact mode, sync.
- **Tool state**: Each tool that needs mutable state gets its own `ChangeNotifier` at `lib/tools/<name>/<name>_state.dart`, registered via `stateProviders` in the tool's `ToolModel`.
- UI binds via `context.watch<T>()` / `context.read<T>()`.

### Navigation

- **`go_router`** — declarative, type-safe routing.
- Tool routes are auto-generated from `ToolRegistry.all` in `lib/app.dart`. Adding a new tool to the registry automatically adds its route — no manual routing config needed.

### Localization

- English (`en`) and German (`de`) via `flutter_localizations` + `intl`.
- ARB sources: `lib/l10n/app_en.arb` (template), `lib/l10n/app_de.arb`.
- New UI strings must be added to both ARB files and read via `AppLocalizations.of(context).<key>`.

### Data & Sync

- Tool settings are stored per-tool via `DatabaseService` (SQLite).
- Global settings (theme, locale) use `SharedPreferences` via `SettingsService`.
- Select tools support bidirectional cloud sync via `SyncDelegate` (Notes, Grocery List, Signatures, Sketch Board, Chiptune, and others).

---

## How to Build & Run

### Run the App
```bash
flutter run -d windows    # Windows Desktop
flutter run -d android    # Android Device or Emulator
```

### Run Tests
```bash
flutter test
```

### Build Release Packages
```bash
./build.sh apk           # Android universal APK
./build.sh apks          # Android split APKs (per-ABI)
./build.sh bundle        # Android App Bundle
./build.sh windows       # Windows Desktop
./build.sh clean         # Clean build artifacts
```

Outputs land in `dist/`.

### Verification
```bash
dart format ./lib
flutter analyze
```
