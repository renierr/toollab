/// Shared value types and BLE GATT identifiers for the treadmill tool.
library;

enum WorkoutStatus { inactive, starting, running, paused, stopped }

enum TreadmillType { ftms, pitpat, none }

class HeartRateHistoryPoint {
  final DateTime timestamp;
  final int heartRate;

  HeartRateHistoryPoint({required this.timestamp, required this.heartRate});
}

class DiscoveredBleDevice {
  final String id;
  final String name;
  final List<String> services;
  final int rssi;

  DiscoveredBleDevice({
    required this.id,
    required this.name,
    required this.services,
    required this.rssi,
  });
}

// GATT service / characteristic UUIDs (standard Bluetooth base form).
const String ftmsService = '00001826-0000-1000-8000-00805f9b34fb';
const String ftmsDataChar = '00002acd-0000-1000-8000-00805f9b34fb';
const String ftmsFeatureChar = '00002acc-0000-1000-8000-00805f9b34fb';
const String ftmsControlPointChar = '00002ad9-0000-1000-8000-00805f9b34fb';

const String pitpatService = '0000fba0-0000-1000-8000-00805f9b34fb';
const String pitpatNotifyChar = '0000fba2-0000-1000-8000-00805f9b34fb';
const String pitpatWriteChar = '0000fba1-0000-1000-8000-00805f9b34fb';

const String rscService = '00001814-0000-1000-8000-00805f9b34fb';
const String rscChar = '00002a53-0000-1000-8000-00805f9b34fb';

const String hrService = '0000180d-0000-1000-8000-00805f9b34fb';
const String hrChar = '00002a37-0000-1000-8000-00805f9b34fb';

const String batteryService = '0000180f-0000-1000-8000-00805f9b34fb';
const String batteryChar = '00002a19-0000-1000-8000-00805f9b34fb';
