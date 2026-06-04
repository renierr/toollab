import 'package:flutter/material.dart';
import 'package:tool_lab/theme/theme.dart';

class ToolModel {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final String route;
  final Color accentColor;

  const ToolModel({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.route,
    required this.accentColor,
  });

  static const List<ToolModel> all = [
    ToolModel(
      id: 'calculator',
      name: 'Calculator',
      description: 'Basic and scientific calculations',
      icon: Icons.calculate_outlined,
      route: '/calculator',
      accentColor: AppTheme.accentBlue,
    ),
    ToolModel(
      id: 'bubble-level',
      name: 'Bubble Level',
      description: 'Precision spirit level using sensors',
      icon: Icons.sensors_outlined,
      route: '/bubble-level',
      accentColor: AppTheme.accentGreen,
    ),
    ToolModel(
      id: 'emf-detector',
      name: 'EMF Detector',
      description: 'Detect electromagnetic fields',
      icon: Icons.wifi_tethering_outlined,
      route: '/emf-detector',
      accentColor: AppTheme.accentAmber,
    ),
    ToolModel(
      id: 'device-info',
      name: 'Device Info',
      description: 'Battery, sensors, and system information',
      icon: Icons.phone_android_outlined,
      route: '/device-info',
      accentColor: AppTheme.accentPurple,
    ),
  ];
}
