/// What a generated data set can contain. One group is one coherent slice of a
/// day, so a preset is just the set of groups it switches on.
enum HealthDebugGroup {
  /// Steps, distance, energy, floors and elevation across waking hours.
  activity,

  /// A day-long heart rate series plus resting heart rate and HRV.
  heart,

  /// One night per day with light/deep/REM/awake stages.
  sleep,

  /// Three sessions a week with their own speed, distance, energy and steps.
  workouts,

  /// Weight, body fat, lean/bone/water mass, height.
  body,

  /// Oxygen saturation, respiratory rate, blood pressure, temperature, glucose.
  vitals,

  /// A few drinks spread over the day.
  hydration,
}

enum HealthDebugPreset {
  /// What a phone plus a fitness band would produce.
  everyday,

  /// Adds structured training on top of everyday.
  athlete,

  /// Measurements rather than movement.
  clinical,

  /// Every group at once.
  everything,
}

extension HealthDebugPresetGroups on HealthDebugPreset {
  Set<HealthDebugGroup> get groups => switch (this) {
    HealthDebugPreset.everyday => const {
      HealthDebugGroup.activity,
      HealthDebugGroup.heart,
      HealthDebugGroup.sleep,
      HealthDebugGroup.body,
    },
    HealthDebugPreset.athlete => const {
      HealthDebugGroup.activity,
      HealthDebugGroup.heart,
      HealthDebugGroup.sleep,
      HealthDebugGroup.workouts,
      HealthDebugGroup.body,
      HealthDebugGroup.hydration,
    },
    HealthDebugPreset.clinical => const {
      HealthDebugGroup.heart,
      HealthDebugGroup.body,
      HealthDebugGroup.vitals,
    },
    HealthDebugPreset.everything => const {
      HealthDebugGroup.activity,
      HealthDebugGroup.heart,
      HealthDebugGroup.sleep,
      HealthDebugGroup.workouts,
      HealthDebugGroup.body,
      HealthDebugGroup.vitals,
      HealthDebugGroup.hydration,
    },
  };
}
