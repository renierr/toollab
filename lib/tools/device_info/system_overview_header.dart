import 'package:flutter/material.dart';
import 'package:tool_lab/theme/theme.dart';

class SystemOverviewHeader extends StatelessWidget {
  final String osName;
  final String osVersion;
  final String deviceName;
  final String modelName;

  const SystemOverviewHeader({
    super.key,
    required this.osName,
    required this.osVersion,
    required this.deviceName,
    required this.modelName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Choose visual representation based on OS
    final bool isWindows = osName.toLowerCase().contains('windows');
    final bool isAndroid = osName.toLowerCase().contains('android');
    final bool isLinux = osName.toLowerCase().contains('linux');

    final IconData osIcon = isWindows
        ? Icons.desktop_windows_outlined
        : isAndroid
        ? Icons.phone_android_outlined
        : isLinux
        ? Icons.terminal_outlined
        : Icons.device_unknown_outlined;

    final Color brandColor = isWindows
        ? AppTheme.statusBlue
        : isAndroid
        ? AppTheme.statusGreen
        : isLinux
        ? AppTheme.statusOrange
        : theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: brandColor.withAlpha(20),
              border: Border.all(color: brandColor.withAlpha(50), width: 2),
              boxShadow: [
                BoxShadow(
                  color: brandColor.withAlpha(10),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(osIcon, size: 48, color: brandColor),
          ),
          const SizedBox(height: 16),
          Text(
            modelName.isNotEmpty ? modelName : deviceName,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: brandColor,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                osName,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withAlpha(200),
                ),
              ),
              if (osVersion.isNotEmpty) ...[
                Text(
                  ' ($osVersion)',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(140),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
