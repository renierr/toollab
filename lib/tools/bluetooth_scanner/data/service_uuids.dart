class ServiceInfo {
  final String uuid;
  final String name;
  final String category;
  const ServiceInfo({
    required this.uuid,
    required this.name,
    required this.category,
  });
}

const Map<String, ServiceInfo> serviceUuids = {
  '1800': ServiceInfo(
    uuid: '1800',
    name: 'Generic Access',
    category: 'Generic',
  ),
  '1801': ServiceInfo(uuid: '1801', name: 'GAP Service', category: 'Generic'),
  '1802': ServiceInfo(uuid: '1802', name: 'GATT Service', category: 'Generic'),
  '1803': ServiceInfo(uuid: '1803', name: 'Heart Rate', category: 'Health'),
  '1804': ServiceInfo(uuid: '1804', name: 'Blood Pressure', category: 'Health'),
  '1805': ServiceInfo(
    uuid: '1805',
    name: 'Environmental Sensing',
    category: 'Environment',
  ),
  '1806': ServiceInfo(
    uuid: '1806',
    name: 'Device Information',
    category: 'Generic',
  ),
  '1807': ServiceInfo(
    uuid: '1807',
    name: 'Continuous Glucose Monitoring',
    category: 'Health',
  ),
  '1808': ServiceInfo(
    uuid: '1808',
    name: 'Blood Pressure Profile',
    category: 'Health',
  ),
  '1809': ServiceInfo(uuid: '1809', name: 'User Data', category: 'Health'),
  '180a': ServiceInfo(
    uuid: '180a',
    name: 'Phone Alert Status',
    category: 'Phone',
  ),
  '180d': ServiceInfo(uuid: '180d', name: 'Heart Rate', category: 'Health'),
  '180f': ServiceInfo(
    uuid: '180f',
    name: 'Battery Service',
    category: 'Generic',
  ),
  '1810': ServiceInfo(uuid: '1810', name: 'Blood Pressure', category: 'Health'),
  '1811': ServiceInfo(
    uuid: '1811',
    name: 'Alert Notification',
    category: 'Phone',
  ),
  '1812': ServiceInfo(
    uuid: '1812',
    name: 'Human Interface Device',
    category: 'Input',
  ),
  '1813': ServiceInfo(
    uuid: '1813',
    name: 'Scan Parameters',
    category: 'Generic',
  ),
  '1814': ServiceInfo(
    uuid: '1814',
    name: 'Cycling Speed and Cadence',
    category: 'Fitness',
  ),
  '1815': ServiceInfo(uuid: '1815', name: 'Cycling Power', category: 'Fitness'),
  '1816': ServiceInfo(
    uuid: '1816',
    name: 'Running Speed and Cadence',
    category: 'Fitness',
  ),
  '1817': ServiceInfo(uuid: '1817', name: 'User Data', category: 'Health'),
  '1818': ServiceInfo(uuid: '1818', name: 'Weight Scale', category: 'Health'),
  '1819': ServiceInfo(
    uuid: '1819',
    name: 'Bond Management',
    category: 'Security',
  ),
  '181a': ServiceInfo(
    uuid: '181a',
    name: 'Location and Navigation',
    category: 'Navigation',
  ),
  '181b': ServiceInfo(
    uuid: '181b',
    name: 'Body Composition',
    category: 'Health',
  ),
  '181c': ServiceInfo(uuid: '181c', name: 'User Data', category: 'Health'),
  '181d': ServiceInfo(uuid: '181d', name: 'Weight Scale', category: 'Health'),
  '181e': ServiceInfo(
    uuid: '181e',
    name: 'Bond Management',
    category: 'Security',
  ),
  '181f': ServiceInfo(
    uuid: '181f',
    name: 'Sensor Location',
    category: 'Fitness',
  ),
  '1820': ServiceInfo(
    uuid: '1820',
    name: 'Ambient Light',
    category: 'Environment',
  ),
  '1821': ServiceInfo(uuid: '1821', name: 'Keyboard', category: 'Input'),
  '1822': ServiceInfo(uuid: '1822', name: 'Touchpad', category: 'Input'),
  '1823': ServiceInfo(uuid: '1823', name: 'Automation IO', category: 'IoT'),
  '1824': ServiceInfo(
    uuid: '1824',
    name: 'Odor Sensor',
    category: 'Environment',
  ),
  '1825': ServiceInfo(uuid: '1825', name: 'Motion Sensor', category: 'Motion'),
  '1826': ServiceInfo(
    uuid: '1826',
    name: 'Fitness Machine',
    category: 'Fitness',
  ),
  '1827': ServiceInfo(
    uuid: '1827',
    name: 'Mesh Provisioning',
    category: 'Mesh',
  ),
  '1828': ServiceInfo(uuid: '1828', name: 'Mesh Proxy', category: 'Mesh'),
  '1829': ServiceInfo(
    uuid: '1829',
    name: 'Reconnection Configuration',
    category: 'Generic',
  ),
  '182a': ServiceInfo(
    uuid: '182a',
    name: 'Insulin Delivery',
    category: 'Health',
  ),
  '182b': ServiceInfo(uuid: '182b', name: 'Binary Sensor', category: 'IoT'),
  '182c': ServiceInfo(
    uuid: '182c',
    name: 'Emergency Alert',
    category: 'Health',
  ),
  '182d': ServiceInfo(uuid: '182d', name: 'Microphone', category: 'Audio'),
  '182e': ServiceInfo(
    uuid: '182e',
    name: 'Traffic Direction',
    category: 'Navigation',
  ),
  '182f': ServiceInfo(uuid: '182f', name: 'Audio Control', category: 'Audio'),
  '1830': ServiceInfo(uuid: '1830', name: 'Volume Control', category: 'Audio'),
  '1831': ServiceInfo(
    uuid: '1831',
    name: 'Audio Input Control',
    category: 'Audio',
  ),
  '1832': ServiceInfo(
    uuid: '1832',
    name: 'Volume Offset Control',
    category: 'Audio',
  ),
  '1833': ServiceInfo(
    uuid: '1833',
    name: 'Audio Description',
    category: 'Audio',
  ),
  '1834': ServiceInfo(uuid: '1834', name: 'Hearing Aid', category: 'Health'),
  '1835': ServiceInfo(
    uuid: '1835',
    name: 'Hearing Aid Preset',
    category: 'Health',
  ),
  '1836': ServiceInfo(uuid: '1836', name: 'Fuel', category: 'Vehicle'),
  '1837': ServiceInfo(uuid: '1837', name: 'RFU Test', category: 'Testing'),
  '1838': ServiceInfo(uuid: '1838', name: 'Baking', category: 'Health'),
  '1839': ServiceInfo(uuid: '1839', name: 'PIV', category: 'Security'),
  '183a': ServiceInfo(
    uuid: '183a',
    name: 'Visual Impairment',
    category: 'Health',
  ),
  '183b': ServiceInfo(
    uuid: '183b',
    name: 'Hearing Accessibility',
    category: 'Health',
  ),
  '183c': ServiceInfo(uuid: '183c', name: 'Time', category: 'Generic'),
  '183d': ServiceInfo(uuid: '183d', name: 'Broadcast Audio', category: 'Audio'),
  '183e': ServiceInfo(
    uuid: '183e',
    name: 'Supported Sample Rate',
    category: 'Audio',
  ),
  '183f': ServiceInfo(uuid: '183f', name: 'HMAC', category: 'Security'),
  '1840': ServiceInfo(uuid: '1840', name: 'APS', category: 'Security'),
  '1841': ServiceInfo(uuid: '1841', name: 'RDK', category: 'Security'),
  '1842': ServiceInfo(uuid: '1842', name: 'Time Profile', category: 'Generic'),
  '1843': ServiceInfo(
    uuid: '1843',
    name: 'Nurse Station',
    category: 'Healthcare',
  ),
  '1844': ServiceInfo(
    uuid: '1844',
    name: 'Visual Impairment VO',
    category: 'Health',
  ),
  '1845': ServiceInfo(
    uuid: '1845',
    name: 'Fitness Machine',
    category: 'Fitness',
  ),
  '1846': ServiceInfo(
    uuid: '1846',
    name: 'Continuous Glucose',
    category: 'Health',
  ),
  'feaa': ServiceInfo(uuid: 'feaa', name: 'Eddystone', category: 'Beacon'),
  'febc': ServiceInfo(uuid: 'febc', name: 'Tile', category: 'IoT'),
  'febf': ServiceInfo(
    uuid: 'febf',
    name: 'Google Fast Pair',
    category: 'Generic',
  ),
  'fec8': ServiceInfo(uuid: 'fec8', name: 'Samsung SmartTag', category: 'IoT'),
  'fef5': ServiceInfo(uuid: 'fef5', name: 'Samsung', category: 'IoT'),
  'fee0': ServiceInfo(uuid: 'fee0', name: 'Samsung Health', category: 'Health'),
  'fd6f': ServiceInfo(uuid: 'fd6f', name: 'Xiaomi', category: 'IoT'),
  'fd61': ServiceInfo(uuid: 'fd61', name: 'Matter', category: 'IoT'),
  'fd5b': ServiceInfo(uuid: 'fd5b', name: 'HomeKit', category: 'IoT'),
};

String? getServiceName(String uuid) {
  final normalized = uuid.toLowerCase().replaceAll('-', '');
  if (normalized.length == 32) {
    final short = normalized.substring(4, 8);
    return serviceUuids[short]?.name;
  }
  return serviceUuids[normalized]?.name;
}

const Map<String, List<String>> serviceFilterMap = {
  'heart_rate': ['180d'],
  'blood_pressure': ['1810'],
  'glucose': ['180f', '1810', '1804'],
  'cycling_speed_cadence': ['1814'],
  'running_cadence': ['1816'],
  'user_data': ['1809', '1817', '181c'],
  'bond_management': ['1819', '181e'],
  'audio': ['182d', '182f', '1830', '1831', '1832', '1833'],
  'ventilator': ['1838'],
  'automation_io': ['1823'],
  'beacon': ['feaa'],
};

List<String> getMatchingServiceFilters(List<String> uuids) {
  if (uuids.isEmpty) return [];
  final normalized = <String>{};
  for (final uuid in uuids) {
    final n = uuid.toLowerCase().replaceAll('-', '');
    normalized.add(n);
    if (n.length == 32) {
      normalized.add(n.substring(4, 8));
    }
  }
  final matched = <String>[];
  for (final entry in serviceFilterMap.entries) {
    if (entry.value.any((s) => normalized.contains(s))) {
      matched.add(entry.key);
    }
  }
  return matched;
}
