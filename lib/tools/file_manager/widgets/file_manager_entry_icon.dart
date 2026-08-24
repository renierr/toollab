import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tool_lab/tools/file_manager/file_manager_entry.dart';

class FileManagerEntryIcon extends StatelessWidget {
  final FileManagerEntry entry;
  final double size;
  final bool showPreview;

  const FileManagerEntryIcon({
    super.key,
    required this.entry,
    this.size = 48,
    this.showPreview = true,
  });

  @override
  Widget build(BuildContext context) {
    if (showPreview && isImage(entry)) {
      // Only cacheWidth: constraining both axes squashes the decode instead of
      // letting BoxFit.cover crop. Decoding at 2x keeps cropped wide images
      // sharp; height stays proportional, so a thumbnail is still tiny.
      final cacheWidth = (size * 2 * MediaQuery.devicePixelRatioOf(context))
          .round();
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          width: size,
          height: size,
          child: Image.file(
            File(entry.path),
            cacheWidth: cacheWidth,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => _fallbackIcon(context),
          ),
        ),
      );
    }
    return _fallbackIcon(context);
  }

  Widget _fallbackIcon(BuildContext context) =>
      Icon(iconFor(entry), size: size * 0.85, color: colorFor(context, entry));

  static bool isImage(FileManagerEntry entry) {
    if (entry.isDirectory || entry.isArchiveEntry || entry.isBrokenLink) {
      return false;
    }
    return switch (entry.name.split('.').last.toLowerCase()) {
      'jpg' || 'jpeg' || 'png' || 'gif' || 'webp' || 'bmp' => true,
      _ => false,
    };
  }

  static IconData iconFor(FileManagerEntry entry) {
    if (entry.isBrokenLink) return Icons.link_off;
    if (entry.isDirectory) return Icons.folder;
    final extension = entry.name.split('.').last.toLowerCase();
    return switch (extension) {
      'apk' => Icons.android_outlined,
      'pdf' => Icons.picture_as_pdf_outlined,
      'md' || 'markdown' || 'txt' || 'rtf' => Icons.article_outlined,
      'doc' || 'docx' || 'odt' => Icons.description_outlined,
      'xls' || 'xlsx' || 'ods' || 'csv' => Icons.table_chart_outlined,
      'ppt' || 'pptx' || 'odp' => Icons.slideshow_outlined,
      'jpg' ||
      'jpeg' ||
      'png' ||
      'gif' ||
      'webp' ||
      'bmp' ||
      'svg' => Icons.image_outlined,
      'mp3' ||
      'wav' ||
      'ogg' ||
      'flac' ||
      'm4a' ||
      'aac' => Icons.audio_file_outlined,
      'mp4' || 'webm' || 'mov' || 'avi' || 'mkv' => Icons.video_file_outlined,
      'zip' || '7z' || 'rar' || 'tar' || 'gz' => Icons.folder_zip_outlined,
      'dart' ||
      'kt' ||
      'java' ||
      'js' ||
      'ts' ||
      'py' ||
      'json' ||
      'yaml' ||
      'yml' ||
      'xml' ||
      'html' ||
      'css' ||
      'sh' => Icons.code_outlined,
      'exe' || 'msi' || 'bat' => Icons.terminal_outlined,
      _ => Icons.insert_drive_file_outlined,
    };
  }

  static Color colorFor(BuildContext context, FileManagerEntry entry) {
    final colors = Theme.of(context).colorScheme;
    if (entry.isBrokenLink) return colors.error;
    if (entry.isDirectory) return colors.primary;
    final extension = entry.name.split('.').last.toLowerCase();
    return switch (extension) {
      'apk' => colors.primary,
      'pdf' => colors.error,
      'jpg' ||
      'jpeg' ||
      'png' ||
      'gif' ||
      'webp' ||
      'bmp' ||
      'svg' => colors.tertiary,
      'mp3' || 'wav' || 'ogg' || 'flac' || 'm4a' || 'aac' => colors.secondary,
      _ => colors.onSurfaceVariant,
    };
  }
}
