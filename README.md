# ToolLab

Welcome to **ToolLab**, a lightweight, multi-platform utility toolkit that puts a curated set of practical tools at your fingertips. Use your device's built-in sensors to measure the world around you, perform quick calculations, and inspect system information — all in one clean, responsive app.

Designed for Android, Windows, and Linux. No accounts. No tracking. Just tools.

---

## The ToolLab Kit

### 🧮 Calculator
A clean 4-function calculator with percentage, sign toggle, and decimal support. Designed for quick, no-fuss arithmetic with haptic feedback on every press.

### 📐 Bubble Level
Turn your device into a precision spirit level using the built-in accelerometer. A real-time animated bubble shows pitch and tilt angles. Calibrate by feel — the bubble turns green when level.

### 📡 EMF Detector
Measure electromagnetic field strength using the device's magnetometer. Displays live X/Y/Z axis readings and total magnitude in microteslas (µT) with a color-coded severity scale and peak-hold tracking.

### 📱 Device Info
Inspect your device's hardware and software. Displays battery level and charging status alongside system details — model, OS version, build info — tailored per platform (Android / Windows / Linux).

---

## Developer Guide & Development Setup

### Codebase Architecture

Overview of key files and directories under `lib/`:

* **`lib/main.dart`**: Application entry point and provider initialization.
* **`lib/app.dart`**: GoRouter configuration and MaterialApp.router setup.
* **`lib/constants.dart`**: Application-wide constants.
* **`lib/models/`**: Data models (`ToolModel` with tool metadata).
* **`lib/providers/`**: State management via `ChangeNotifier` (`AppState`).
* **`lib/pages/`**: Main views — Overview grid and each tool page.
* **`lib/theme/`**: Material 3 theme definitions (light/dark).
* **`lib/widgets/`**: Reusable widgets (`ToolCard`, `ResponsiveLayout`).

### State Management

* **Provider + ChangeNotifier** — lightweight, standard Flutter state management.
* State is centralized in `AppState` (`lib/providers/app_state.dart`).

### Sensor Architecture

* **`sensors_plus`** — cross-platform accelerometer and magnetometer streams.
* Bubble Level subscribes to the accelerometer stream (50ms interval) and applies a simple low-pass filter (0.7/0.3 blend) for smooth bubble movement.
* EMF Detector subscribes to the magnetometer stream (100ms interval) with the same smoothing approach, tracking peak values during the session.

### Navigation

* **`go_router`** — declarative, type-safe routing.
* Routes: `/` (overview), `/calculator`, `/bubble-level`, `/emf-detector`, `/device-info`.
* Each tool is a self-contained page under `lib/pages/<tool>/`.

---

### How to Build & Run

Ensure you are in the project workspace directory.

#### 1. Run the App

* **Windows Desktop**:
  ```bash
  flutter run -d windows
  ```
* **Linux Desktop**:
  ```bash
  flutter run -d linux
  ```
* **Android (Device or Emulator)**:
  ```bash
  flutter run -d android
  ```

#### 2. Run Automated Tests
```bash
flutter test
```

#### 3. Build Release Packages

* **Windows Desktop**:
  ```bash
  flutter build windows --release
  ```
  *Output: `build/windows/x64/runner/Release/`*

* **Linux Desktop**:
  ```bash
  flutter build linux --release
  ```
  *Output: `build/linux/x64/release/bundle/`*

* **Android (Release APK)**:
  ```bash
  flutter build apk --release
  ```
  *Output: `build/app/outputs/flutter-apk/app-release.apk`*

#### 4. Build Script

A convenience `build.sh` script is included (adapted from the parent project):
```bash
./build.sh apk        # Android universal APK
./build.sh apks       # Android split APKs (per-ABI)
./build.sh bundle     # Android App Bundle
./build.sh windows    # Windows Desktop
./build.sh linux      # Linux Desktop
./build.sh clean      # Clean build artifacts
```

All outputs land in `dist/`.

---

### Verification

```bash
dart format ./lib
flutter analyze
```

Both must pass cleanly before committing.
