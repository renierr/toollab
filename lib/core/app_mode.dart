/// True when the app is running as a single-tool standalone build (produced by
/// `tool/build_standalone.dart`), false in the full multi-tool ToolLab app.
///
/// The standalone entry point (`lib/main_standalone.dart`) sets this to `true`
/// at startup. Shared widgets use it to adapt behaviour that only makes sense
/// in the full app — e.g. [ToolBackButton] exposes a settings shortcut instead
/// of a home button when there is no overview to return to.
bool isStandaloneMode = false;
