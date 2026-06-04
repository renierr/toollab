import 'package:flutter/material.dart';

class ToolModel {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final String route;
  final Color accentColor;
  final String sectionId;
  final bool fullscreen;

  const ToolModel({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.route,
    required this.accentColor,
    required this.sectionId,
    this.fullscreen = false,
  });
}

class ToolSection {
  final String id;
  final String title;
  final IconData icon;
  final String? description;

  const ToolSection({
    required this.id,
    required this.title,
    required this.icon,
    this.description,
  });
}
