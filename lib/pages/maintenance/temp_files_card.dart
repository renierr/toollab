import 'package:flutter/material.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/helpers/format_helper.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';

class TempFilesCard extends StatelessWidget {
  const TempFilesCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.cleaning_services_outlined,
                  color: AppTheme.statusAmber,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Temp Files',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FutureBuilder<int>(
              future: TempFileManager.trackedBytes(),
              builder: (context, snapshot) {
                final count = TempFileManager.trackedCount;
                final size = snapshot.hasData
                    ? FormatHelper.fileSize(snapshot.data!)
                    : '...';

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$count file(s) using $size',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.statusRed,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () async {
                          await TempFileManager.cleanAll();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                const SnackBar(
                                  content: Text('Temp files cleaned up'),
                                ),
                              );
                            (context as Element).markNeedsBuild();
                          }
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text(
                          'Clean Up Temp Files',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
