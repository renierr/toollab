/// How a stored location's coordinates were obtained.
enum LocationSource {
  /// Precise device GPS / platform location services.
  gps,

  /// Approximate position derived from the device's public IP address.
  ip;

  String get dbValue => name;

  static LocationSource fromDb(String? value) => value == ip.name ? ip : gps;
}
