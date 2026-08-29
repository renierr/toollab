/// The board's fixed logical resolution.
///
/// Every physics constant, stencil and saved coordinate is expressed in these
/// units; the view scales the whole board to fit whatever room it gets. Keeping
/// the simulation resolution-independent means a phone and a maximized desktop
/// window play the exact same game, and a save moves between them unchanged.
class Board {
  Board._();

  static const double width = 480;
  static const double height = 760;
  static const int columns = 13;

  /// Tiles sit flush against each other — the grid is seamless by design, so
  /// the cell size *is* the tile size.
  static const double cell = width / columns;

  /// Where the launcher sits and where balls are considered returned.
  static const double launchY = height - 34;

  /// Cross this with a brick and the run ends.
  static const double dangerY = height - 80;

  static const double ballRadius = 7;
}
