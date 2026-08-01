import 'package:flutter/material.dart';
import 'package:tool_lab/tools/file_manager/file_manager_entry.dart';

class FileManagerEntryIcon extends StatelessWidget {
  final FileManagerEntry entry;
  final double size;

  const FileManagerEntryIcon({super.key, required this.entry, this.size = 24});

  @override
  Widget build(BuildContext context) =>
      Icon(iconFor(entry), size: size, color: colorFor(context, entry));

  static IconData iconFor(FileManagerEntry entry) {
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
