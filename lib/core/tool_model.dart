import 'package:flutter/material.dart';

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
}
