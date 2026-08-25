import 'package:tool_lab/l10n/app_localizations.dart';

import 'renpho_assessment.dart';
import 'renpho_independent_analysis.dart';

extension RenphoFindingLabel on RenphoFindingKind {
  String label(AppLocalizations l10n) => switch (this) {
    RenphoFindingKind.bmi => l10n.renphoMetricBmi,
    RenphoFindingKind.bodyFat => l10n.renphoMetricBodyFat,
    RenphoFindingKind.fatMassIndex => l10n.renphoMetricFatMassIndex,
    RenphoFindingKind.fatFreeMassIndex => l10n.renphoMetricFatFreeMassIndex,
    RenphoFindingKind.muscleIndex => l10n.renphoMetricAppendicularLeanIndex,
    RenphoFindingKind.visceralFat => l10n.renphoMetricVisceralFat,
    RenphoFindingKind.hydration => l10n.renphoMetricHydration,
    RenphoFindingKind.segmentBalance => l10n.renphoFindingSegmentBalance,
    RenphoFindingKind.conductionSpread => l10n.renphoFindingConductionSpread,
    RenphoFindingKind.agreement => l10n.renphoFindingAgreement,
  };

  /// What the value means for health, in one sentence. The agreement check
  /// describes the two calculations rather than the body, so it has none.
  String? guidance(AppLocalizations l10n) => switch (this) {
    RenphoFindingKind.bmi => l10n.renphoGuidanceBmi,
    RenphoFindingKind.bodyFat => l10n.renphoGuidanceBodyFat,
    RenphoFindingKind.fatMassIndex => l10n.renphoGuidanceFatMassIndex,
    RenphoFindingKind.fatFreeMassIndex => l10n.renphoGuidanceFatFreeMassIndex,
    RenphoFindingKind.muscleIndex => l10n.renphoGuidanceMuscleIndex,
    RenphoFindingKind.visceralFat => l10n.renphoGuidanceVisceralFat,
    RenphoFindingKind.hydration => l10n.renphoGuidanceHydration,
    RenphoFindingKind.segmentBalance => l10n.renphoGuidanceSegmentBalance,
    RenphoFindingKind.conductionSpread => l10n.renphoGuidanceConductionSpread,
    RenphoFindingKind.agreement => null,
  };
}

extension RenphoComparisonLabel on RenphoComparisonMetric {
  String label(AppLocalizations l10n) => switch (this) {
    RenphoComparisonMetric.fatFreeMass => l10n.renphoMetricFatFreeMass,
    RenphoComparisonMetric.fatMass => l10n.renphoMetricFatMass,
    RenphoComparisonMetric.bodyFatPercent => l10n.renphoMetricBodyFat,
    RenphoComparisonMetric.skeletalMuscleMass =>
      l10n.renphoMetricSkeletalMuscleMass,
    RenphoComparisonMetric.bodyWater => l10n.renphoMetricTotalBodyWater,
    RenphoComparisonMetric.muscleIndex => l10n.renphoMetricSmi,
  };
}

extension RenphoOverallStatusLabel on RenphoOverallStatus {
  String label(AppLocalizations l10n) => switch (this) {
    RenphoOverallStatus.excellent => l10n.renphoOverallExcellent,
    RenphoOverallStatus.good => l10n.renphoOverallGood,
    RenphoOverallStatus.fair => l10n.renphoOverallFair,
    RenphoOverallStatus.attention => l10n.renphoOverallAttention,
  };
}

extension RenphoRatingLabel on RenphoRating {
  String label(AppLocalizations l10n) => switch (this) {
    RenphoRating.low => l10n.renphoRatingLow,
    RenphoRating.optimal => l10n.renphoRatingOptimal,
    RenphoRating.elevated => l10n.renphoRatingElevated,
    RenphoRating.high => l10n.renphoRatingHigh,
  };
}

extension RenphoAssessmentMetricLabel on RenphoAssessmentMetric {
  String label(AppLocalizations l10n) => switch (this) {
    RenphoAssessmentMetric.bmi => l10n.renphoMetricBmi,
    RenphoAssessmentMetric.bodyFat => l10n.renphoMetricBodyFat,
    RenphoAssessmentMetric.visceralFat => l10n.renphoMetricVisceralFat,
    RenphoAssessmentMetric.bodyWater => l10n.renphoMetricBodyWater,
    RenphoAssessmentMetric.skeletalMuscleIndex => l10n.renphoMetricSmi,
    RenphoAssessmentMetric.segmentMuscle => l10n.renphoAssessmentSegmentMuscle,
    RenphoAssessmentMetric.symmetry => l10n.renphoAssessmentSymmetry,
  };

  String? guidance(AppLocalizations l10n) => switch (this) {
    RenphoAssessmentMetric.bmi => l10n.renphoGuidanceBmi,
    RenphoAssessmentMetric.bodyFat => l10n.renphoGuidanceBodyFat,
    RenphoAssessmentMetric.visceralFat => l10n.renphoGuidanceVisceralFat,
    RenphoAssessmentMetric.bodyWater => l10n.renphoGuidanceHydration,
    RenphoAssessmentMetric.skeletalMuscleIndex =>
      l10n.renphoGuidanceMuscleIndex,
    RenphoAssessmentMetric.segmentMuscle => null,
    RenphoAssessmentMetric.symmetry => l10n.renphoGuidanceSegmentBalance,
  };
}
