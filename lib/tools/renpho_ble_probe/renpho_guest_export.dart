import 'dart:convert';

import 'renpho_body_metrics.dart';
import 'renpho_measurement.dart';

/// Everything one reading yields, as JSON: what the scale reported, every
/// derived figure, the per-segment breakdown and the profile the figures were
/// computed under. A guest reading is never stored, so this export is the only
/// way it leaves the app.
String renphoMeasurementJson(
  RenphoMeasurement measurement, {
  bool guest = false,
  DateTime? exportedAt,
}) {
  final derived = RenphoDerived(measurement);
  final export = exportedAt ?? DateTime.now();
  final map = <String, Object?>{
    'scan': {
      'guest': guest,
      'measuredAt': measurement.measuredAt.toIso8601String(),
      'exportedAt': export.toIso8601String(),
      'stored': measurement.stored,
      'imported': measurement.imported,
      'persisted': !guest,
      'rawPacketHex': measurement.packetHex,
    },
    'profile': {
      'name': measurement.profileName,
      'sex': measurement.profileSex,
      'heightCm': measurement.profileHeightCm,
      'age': measurement.profileAge,
    },
    'reported': {
      'weightKg': measurement.weightKg,
      'bmi': measurement.bmi,
      'bodyFatPercent': measurement.bodyFatPercent,
      'musclePercent': measurement.musclePercent,
      'visceralFat': measurement.visceralFat,
      'impedanceOhm': measurement.impedance,
    },
    'exact': {
      'bmi': derived.bmi,
      'fatMassKg': derived.fatMassKg,
      'fatFreeMassKg': derived.fatFreeMassKg,
      'skeletalMuscleMassKg': derived.skeletalMuscleMassKg,
    },
    'model': {
      'calibratedForThisProfile': derived.modelCalibrated,
      'bodyWaterPercent': derived.bodyWaterPercent,
      'bodyWaterMassKg': derived.bodyWaterMassKg,
      'proteinPercent': derived.proteinPercent,
      'proteinMassKg': derived.proteinMassKg,
      'leanSoftTissuePercent': derived.leanSoftTissuePercent,
      'leanSoftTissueKg': derived.leanSoftTissueKg,
      'subcutaneousFatPercent': derived.subcutaneousFatPercent,
      'boneMassKg': derived.boneMassKg,
      'bmrKcalPerDay': derived.bmrRenphoKcal,
      'bodyScore': derived.bodyScore,
      'bodyType': derived.bodyType,
      'obesityDegreePercent': derived.obesityDegreePercent,
      'weightControlKg': derived.weightControlKg,
      'targetWeightKg': derived.targetWeightKg,
      'skeletalMuscleIndex': derived.skeletalMuscleIndex,
    },
    'segments': {
      for (final segment in derived.segments)
        segment.segment.name: {
          'muscleMassKg': segment.muscleMassKg,
          'muscleOfStandardPercent': segment.muscleOfStandardPercent,
          'fatMassKg': segment.fatMassKg,
          'fatOfStandardPercent': segment.fatOfStandardPercent,
          'impedance20Ohm': segment.impedance20,
          'impedance100Ohm': segment.impedance100,
          'impedanceRatio': segment.impedanceRatio,
        },
    },
    'impedanceAnalysis': {
      'wholeBody20Ohm': derived.wholeBodyImpedance20,
      'wholeBody100Ohm': derived.wholeBodyImpedance100,
      'interpolated50Ohm': derived.interpolatedImpedance50,
      'ratio': derived.impedanceRatio,
      'armDifferenceOhm': derived.armImpedanceDifference,
      'legDifferenceOhm': derived.legImpedanceDifference,
    },
    'energy': {
      'mifflinStJeorKcalPerDay': derived.bmrMifflinKcal,
      'katchMcArdleKcalPerDay': derived.bmrKatchMcArdleKcal,
    },
    'publishedEstimates': [
      for (final estimate in derived.publishedEstimates)
        {
          'equation': estimate.equation,
          'unit': estimate.unit,
          'at20kHz': estimate.at20kHz,
          'at50kHz': estimate.at50kHz,
          'at100kHz': estimate.at100kHz,
        },
    ],
  };
  return const JsonEncoder.withIndent('  ').convert(map);
}
