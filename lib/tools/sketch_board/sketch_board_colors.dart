/// Static palette + stroke widths for the Sketch Board toolbar.
class SketchBoardColors {
  SketchBoardColors._();

  /// Stroke colour swatches (hex). First entry is the default ink.
  static const List<String> strokeSwatches = [
    '#1E1E1E',
    '#E03131',
    '#2F9E44',
    '#1971C2',
    '#F08C00',
    '#9C36B5',
    '#FFFFFF',
  ];

  /// Fill swatches. `transparent` means "no fill".
  static const List<String> fillSwatches = [
    'transparent',
    '#FFC9C9',
    '#B2F2BB',
    '#A5D8FF',
    '#FFEC99',
    '#EEBEFA',
  ];

  /// Selectable stroke widths (world units).
  static const List<double> strokeWidths = [2, 4, 8];

  static const String defaultStroke = '#1E1E1E';
}
