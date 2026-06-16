/// Tool-specific pen-color palette for the Signature Creator.
///
/// These are signature ink choices (content), kept as a tool palette per the
/// project's color strategy rather than abstracted into the app theme.
class SignaturesColors {
  SignaturesColors._();

  /// Default ink color (deep navy), also the [SignatureSettings] default.
  static const String defaultPen = '#0B3D91';

  /// Selectable ink presets shown in the quick controls.
  static const List<String> penPresets = [
    '#0B3D91',
    '#111111',
    '#1565C0',
    '#C62828',
    '#2E7D32',
  ];
}
