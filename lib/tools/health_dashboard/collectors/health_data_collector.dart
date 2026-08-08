import '../health_record.dart';

abstract class HealthDataCollector {
  HealthSource get source;
  Future<List<HealthRecord>> collect();
}
