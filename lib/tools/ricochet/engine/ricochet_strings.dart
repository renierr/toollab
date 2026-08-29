/// Every player-visible string the simulation itself produces — score popups,
/// status toasts, the level banner, the charge chips.
///
/// The engine paints these onto the board, so it needs the text; it must not
/// need a `BuildContext` to get it. The page builds this from `AppLocalizations`
/// and hands it over, rebuilding it when the locale changes.
class RicochetStrings {
  final String pierceArmed;
  final String bombArmed;
  final String recalled;
  final String rowCleared;
  final String plusOneBall;
  final String dragToAim;
  final String pierceLabel;
  final String bombLabel;

  final String Function(int count) plusBalls;
  final String Function(int multiplier) speedBoost;
  final String Function(int multiplier) autoSpeed;
  final String Function(int level) levelBanner;
  final String Function(int points) scorePopup;
  final String Function(int points) scorePopupDoubled;
  final String Function(String label, int count) chargeChip;

  const RicochetStrings({
    required this.pierceArmed,
    required this.bombArmed,
    required this.recalled,
    required this.rowCleared,
    required this.plusOneBall,
    required this.dragToAim,
    required this.pierceLabel,
    required this.bombLabel,
    required this.plusBalls,
    required this.speedBoost,
    required this.autoSpeed,
    required this.levelBanner,
    required this.scorePopup,
    required this.scorePopupDoubled,
    required this.chargeChip,
  });

  /// Placeholder used before the first localized build, and by headless tests
  /// that exercise the simulation without a widget tree.
  static RicochetStrings fallback() => RicochetStrings(
    pierceArmed: 'PIERCE ARMED',
    bombArmed: 'BOMB ARMED',
    recalled: 'RECALLED',
    rowCleared: 'ROW CLEARED',
    plusOneBall: '+1 BALL',
    dragToAim: 'Drag to aim',
    pierceLabel: 'PIERCE',
    bombLabel: 'BOMB',
    plusBalls: (count) => '+$count BALLS',
    speedBoost: (multiplier) => 'SPEED x$multiplier',
    autoSpeed: (multiplier) => 'AUTO SPEED x$multiplier',
    levelBanner: (level) => 'LEVEL $level',
    scorePopup: (points) => '+$points',
    scorePopupDoubled: (points) => '+$points x2!',
    chargeChip: (label, count) => count > 1 ? '$label ×$count' : label,
  );
}
