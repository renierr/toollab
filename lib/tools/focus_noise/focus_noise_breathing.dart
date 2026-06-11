enum FocusBreathingMode { box, relax, calm }

class BreathingStep {
  final String label;
  final Duration duration;
  final double scale;

  const BreathingStep({
    required this.label,
    required this.duration,
    required this.scale,
  });
}

class FocusBreathingPattern {
  final FocusBreathingMode mode;
  final String label;
  final List<BreathingStep> steps;

  const FocusBreathingPattern({
    required this.mode,
    required this.label,
    required this.steps,
  });
}

class FocusBreathingCatalog {
  FocusBreathingCatalog._();

  static const FocusBreathingPattern box = FocusBreathingPattern(
    mode: FocusBreathingMode.box,
    label: 'Box 4-4-4-4',
    steps: [
      BreathingStep(
        label: 'Inhale',
        duration: Duration(seconds: 4),
        scale: 1.8,
      ),
      BreathingStep(label: 'Hold', duration: Duration(seconds: 4), scale: 1.8),
      BreathingStep(
        label: 'Exhale',
        duration: Duration(seconds: 4),
        scale: 1.0,
      ),
      BreathingStep(label: 'Hold', duration: Duration(seconds: 4), scale: 1.0),
    ],
  );

  static const FocusBreathingPattern relax = FocusBreathingPattern(
    mode: FocusBreathingMode.relax,
    label: 'Relax 4-7-8',
    steps: [
      BreathingStep(
        label: 'Inhale',
        duration: Duration(seconds: 4),
        scale: 1.8,
      ),
      BreathingStep(label: 'Hold', duration: Duration(seconds: 7), scale: 1.8),
      BreathingStep(
        label: 'Exhale',
        duration: Duration(seconds: 8),
        scale: 1.0,
      ),
    ],
  );

  static const FocusBreathingPattern calm = FocusBreathingPattern(
    mode: FocusBreathingMode.calm,
    label: 'Calm 5-5',
    steps: [
      BreathingStep(
        label: 'Inhale',
        duration: Duration(seconds: 5),
        scale: 1.8,
      ),
      BreathingStep(
        label: 'Exhale',
        duration: Duration(seconds: 5),
        scale: 1.0,
      ),
    ],
  );

  static const List<FocusBreathingPattern> patterns = [box, relax, calm];

  static FocusBreathingPattern byMode(FocusBreathingMode mode) {
    return patterns.firstWhere(
      (pattern) => pattern.mode == mode,
      orElse: () => relax,
    );
  }
}
