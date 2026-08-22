import 'dart:io';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../core/tool_model.dart';
import '../services/sharing_service.dart';
import '../widgets/tool_chooser_dialog.dart';
import '../providers/app_state.dart';
import '../widgets/custom_notification.dart';
import '../theme/theme.dart';

import 'mime_type_helper.dart';
import 'temp_file_manager.dart';

class FileSaveHelper {
  static const _channel = MethodChannel('de.renier.tool_lab/file_save');

  static Future<String> createAndroidDownloadsFilePath(String fileName) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError(
        'A public Downloads path is only available on Android.',
      );
    }
    final path = await _channel.invokeMethod<String>(
      'createDownloadsFilePath',
      {'fileName': fileName},
    );
    if (path == null || path.isEmpty) {
      throw StateError('Could not create the Downloads export path.');
    }
    return path;
  }

  /// Resolves the save path for a file, writes [bytes] to it, and automatically
  /// handles the success or error notifications internally.
  /// On Android, uses MediaStore to save to public Downloads and posts a native notification.
  /// On Desktop, uses native Save As dialog.
  /// Returns the resolved save path, or null if cancelled or failed.
  static Future<String?> saveFile({
    required BuildContext context,
    required String suggestedName,
    Uint8List? bytes,
    List<XTypeGroup>? acceptedTypeGroups,
    String? successMessageAndroid,
    String Function(String displayPath)? successMessageGeneralBuilder,
    String Function(String error)? errorMessageBuilder,
  }) async {
    try {
      String? destPath;
      final mimeType = _mimeTypeFromName(suggestedName);

      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        final FileSaveLocation? location = await getSaveLocation(
          suggestedName: suggestedName,
          acceptedTypeGroups: acceptedTypeGroups ?? const <XTypeGroup>[],
        );
        if (location == null) return null;
        destPath = location.path;
        if (bytes != null) {
          final File file = File(destPath);
          await file.writeAsBytes(bytes);
        }

        if (context.mounted) {
          final displayPath = destPath.length > 40
              ? '...${destPath.substring(destPath.length - 37)}'
              : destPath;

          showSuccessDialog(
            context: context,
            displayPath: displayPath,
            actualPath: destPath,
            mimeType: mimeType,
            message:
                successMessageGeneralBuilder?.call(displayPath) ??
                "File saved to $displayPath",
          );
        }
      } else if (Platform.isAndroid) {
        if (bytes == null) return null;

        // Use MediaStore via platform channel for proper Downloads access (returns uri and filePath)
        final Map? result = await _channel.invokeMethod<Map>(
          'saveToDownloads',
          {'bytes': bytes, 'fileName': suggestedName, 'mimeType': mimeType},
        );

        if (result == null) return null;

        final uriString = result['uri'] as String?;
        final filePath = result['filePath'] as String?;
        final savedFileName = result['fileName'] as String? ?? suggestedName;
        destPath = filePath;

        if (context.mounted && uriString != null && filePath != null) {
          final systemNotificationsEnabled = context
              .read<AppState>()
              .systemNotificationsEnabled;
          if (systemNotificationsEnabled) {
            // Trigger native Android system notification (if enabled)
            try {
              await _channel.invokeMethod('showSystemNotification', {
                'fileName': savedFileName,
                'uri': uriString,
                'mimeType': mimeType,
              });
            } catch (e) {
              errorLog("Failed to show native system notification: $e");
            }
          }

          // Write bytes to a temporary file to enable secure in-app sharing
          String sharePath = uriString;
          try {
            sharePath = await TempFileManager.createFile(
              'share_$suggestedName',
              bytes: bytes,
            );
          } catch (e) {
            errorLog("Failed to create temporary file for sharing: $e");
          }

          // Show in-app success dialog
          if (context.mounted) {
            showSuccessDialog(
              context: context,
              displayPath: filePath,
              actualPath: sharePath,
              mimeType: mimeType,
              message:
                  successMessageAndroid ?? "File saved to Downloads folder",
            );
          }
        }
      } else {
        // iOS or other platforms
        final Directory docDir = await getApplicationDocumentsDirectory();
        final File file = File('${docDir.path}/$suggestedName');
        if (bytes != null) {
          await file.writeAsBytes(bytes);
        }
        destPath = file.path;

        if (context.mounted) {
          final displayPath = destPath.length > 40
              ? '...${destPath.substring(destPath.length - 37)}'
              : destPath;

          showSuccessDialog(
            context: context,
            displayPath: displayPath,
            actualPath: destPath,
            mimeType: mimeType,
            message:
                successMessageGeneralBuilder?.call(displayPath) ??
                "File saved to $displayPath",
          );
        }
      }

      return destPath;
    } catch (e) {
      if (context.mounted) {
        showErrorNotification(
          context: context,
          errorMessage:
              errorMessageBuilder?.call(e.toString()) ??
              "Failed to save file: $e",
        );
      }
      return null;
    }
  }

  static Future<String?> saveFileFromPath({
    required BuildContext context,
    required String suggestedName,
    required String sourcePath,
    List<XTypeGroup>? acceptedTypeGroups,
    String? successMessageAndroid,
    String Function(String displayPath)? successMessageGeneralBuilder,
    String Function(String error)? errorMessageBuilder,
  }) async {
    try {
      String? destPath;
      final mimeType = _mimeTypeFromName(suggestedName);

      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        final FileSaveLocation? location = await getSaveLocation(
          suggestedName: suggestedName,
          acceptedTypeGroups: acceptedTypeGroups ?? const <XTypeGroup>[],
        );
        if (location == null) return null;
        destPath = location.path;
        await File(sourcePath).copy(destPath);

        if (context.mounted) {
          final displayPath = destPath.length > 40
              ? '...${destPath.substring(destPath.length - 37)}'
              : destPath;

          showSuccessDialog(
            context: context,
            displayPath: displayPath,
            actualPath: destPath,
            mimeType: mimeType,
            message:
                successMessageGeneralBuilder?.call(displayPath) ??
                'File saved to $displayPath',
          );
        }
      } else if (Platform.isAndroid) {
        final Map? result = await _channel.invokeMethod<Map>(
          'saveToDownloadsFromPath',
          {
            'sourcePath': sourcePath,
            'fileName': suggestedName,
            'mimeType': mimeType,
          },
        );

        if (result == null) return null;

        final uriString = result['uri'] as String?;
        final filePath = result['filePath'] as String?;
        final savedFileName = result['fileName'] as String? ?? suggestedName;
        destPath = filePath;

        if (context.mounted && uriString != null && filePath != null) {
          final systemNotificationsEnabled = context
              .read<AppState>()
              .systemNotificationsEnabled;
          if (systemNotificationsEnabled) {
            try {
              await _channel.invokeMethod('showSystemNotification', {
                'fileName': savedFileName,
                'uri': uriString,
                'mimeType': mimeType,
              });
            } catch (e) {
              errorLog('Failed to show native system notification: $e');
            }
          }

          if (context.mounted) {
            showSuccessDialog(
              context: context,
              displayPath: filePath,
              actualPath: sourcePath,
              mimeType: mimeType,
              message:
                  successMessageAndroid ?? 'File saved to Downloads folder',
            );
          }
        }
      } else {
        final Directory docDir = await getApplicationDocumentsDirectory();
        final File file = File('${docDir.path}/$suggestedName');
        await File(sourcePath).copy(file.path);
        destPath = file.path;

        if (context.mounted) {
          final displayPath = destPath.length > 40
              ? '...${destPath.substring(destPath.length - 37)}'
              : destPath;

          showSuccessDialog(
            context: context,
            displayPath: displayPath,
            actualPath: destPath,
            mimeType: mimeType,
            message:
                successMessageGeneralBuilder?.call(displayPath) ??
                'File saved to $displayPath',
          );
        }
      }

      return destPath;
    } catch (e) {
      if (context.mounted) {
        showErrorNotification(
          context: context,
          errorMessage:
              errorMessageBuilder?.call(e.toString()) ??
              'Failed to save file: $e',
        );
      }
      return null;
    }
  }

  /// Copies a finished file into the public Downloads folder with no UI at all,
  /// for long work that may complete while the app is in the background. Returns
  /// the saved path, or null when the copy failed.
  static Future<String?> saveToDownloadsHeadless({
    required String sourcePath,
    required String fileName,
    bool notify = true,
  }) async {
    try {
      final mimeType = _mimeTypeFromName(fileName);
      if (!Platform.isAndroid) {
        final docDir = await getApplicationDocumentsDirectory();
        final dest = '${docDir.path}/$fileName';
        await File(sourcePath).copy(dest);
        return dest;
      }
      final Map? result = await _channel.invokeMethod<Map>(
        'saveToDownloadsFromPath',
        {'sourcePath': sourcePath, 'fileName': fileName, 'mimeType': mimeType},
      );
      if (result == null) return null;
      final uriString = result['uri'] as String?;
      if (notify && uriString != null) {
        try {
          await _channel.invokeMethod('showSystemNotification', {
            'fileName': result['fileName'] as String? ?? fileName,
            'uri': uriString,
            'mimeType': mimeType,
          });
        } catch (e) {
          errorLog('Failed to show native system notification: $e');
        }
      }
      return result['filePath'] as String?;
    } catch (e) {
      errorLog('Failed to save file to Downloads: $e');
      return null;
    }
  }

  /// Opens the file using the default native system app.
  static Future<void> openFile(String path, String mimeType) async {
    try {
      if (Platform.isAndroid) {
        await _channel.invokeMethod('openFile', {
          'uri': path,
          'mimeType': mimeType,
        });
      } else if (Platform.isWindows) {
        await Process.run('explorer.exe', [path]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [path]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [path]);
      }
    } catch (e) {
      errorLog("Error opening file: $e");
    }
  }

  /// Shares the file natively using share_plus on all platforms (mobile & desktop).
  static Future<void> shareFile(String path, String mimeType) async {
    try {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(path, mimeType: mimeType)]),
      );
    } catch (e) {
      errorLog("Error sharing file: $e");
    }
  }

  /// Shows a chooser to open a file internally or externally.
  static Future<void> showOpenChooser({
    required BuildContext context,
    required String path,
    required String mimeType,
    SharedFileOrigin? origin,
  }) async {
    final name = path.split(Platform.pathSeparator).last.split('/').last;
    final file = SharedFile(
      path: path,
      name: name,
      mimeType: mimeType,
      origin: origin,
    );
    final matchingTools = SharingService.instance.getMatchingTools(file);

    if (matchingTools.isEmpty) {
      await openFile(path, mimeType);
      return;
    }

    final systemDefaultTool = ToolModel(
      id: 'system-default',
      name: 'System Default App',
      description: 'Open in the device\'s default viewer application',
      icon: Icons.open_in_new,
      route: '',
      accentColor: Colors.grey,
      sectionId: '',
    );

    if (!context.mounted) return;

    final result = await showDialog<(ToolModel, bool)>(
      context: context,
      builder: (context) => ToolChooserDialog(
        tools: [...matchingTools, systemDefaultTool],
        fileName: name,
        showRememberChoice: false,
      ),
    );

    if (result != null) {
      final (selectedTool, remember) = result;
      if (selectedTool.id == 'system-default') {
        await openFile(path, mimeType);
      } else {
        if (remember) {
          await SharingService.instance.setDefaultTool(
            file.mimeType,
            selectedTool.id,
          );
        }
        if (context.mounted) {
          GoRouter.of(
            context,
          ).push(selectedTool.route, extra: SharedData.single(file));
        }
      }
    }
  }

  /// Shows a chooser to share a file internally or externally.
  static Future<void> showShareChooser({
    required BuildContext context,
    required String path,
    required String mimeType,
  }) async {
    final name = path.split(Platform.pathSeparator).last.split('/').last;
    final file = SharedFile(path: path, name: name, mimeType: mimeType);
    final matchingTools = SharingService.instance.getMatchingTools(file);

    if (matchingTools.isEmpty) {
      await shareFile(path, mimeType);
      return;
    }

    final systemShareTool = ToolModel(
      id: 'system-share',
      name: 'System Share',
      description: 'Share file externally using the system share sheet',
      icon: Icons.share,
      route: '',
      accentColor: AppTheme.accentBlue,
      sectionId: '',
    );

    if (!context.mounted) return;

    final result = await showDialog<(ToolModel, bool)>(
      context: context,
      builder: (context) => ToolChooserDialog(
        tools: [...matchingTools, systemShareTool],
        fileName: name,
        showRememberChoice: false,
      ),
    );

    if (result != null) {
      final (selectedTool, remember) = result;
      if (selectedTool.id == 'system-share') {
        await shareFile(path, mimeType);
      } else {
        if (remember) {
          await SharingService.instance.setDefaultTool(
            file.mimeType,
            selectedTool.id,
          );
        }
        if (context.mounted) {
          GoRouter.of(
            context,
          ).push(selectedTool.route, extra: SharedData.single(file));
        }
      }
    }
  }

  /// Displays an interactive success dialog allowing the user to open or share/locate the exported file.
  static void showSuccessDialog({
    required BuildContext context,
    required String displayPath,
    required String actualPath,
    required String mimeType,
    required String message,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black38,
      builder: (BuildContext ctx) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          color: AppTheme.accentGreen,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Export Successful",
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      message,
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                          },
                          icon: Icon(
                            Icons.close,
                            size: 18,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          label: Text(
                            "Close",
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () async {
                            Navigator.of(ctx).pop();
                            if (context.mounted) {
                              await showOpenChooser(
                                context: context,
                                path: actualPath,
                                mimeType: mimeType,
                              );
                            }
                          },
                          icon: const Icon(
                            Icons.open_in_new,
                            size: 18,
                            color: Colors.white,
                          ),
                          label: const Text(
                            "Open",
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentGreen,
                            elevation: 0,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () async {
                            Navigator.of(ctx).pop();
                            if (context.mounted) {
                              await showShareChooser(
                                context: context,
                                path: actualPath,
                                mimeType: mimeType,
                              );
                            }
                          },
                          icon: const Icon(
                            Icons.share,
                            size: 18,
                            color: Colors.white,
                          ),
                          label: const Text(
                            "Share",
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentBlue,
                            elevation: 0,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static String _mimeTypeFromName(String fileName) {
    return MimeTypeHelper.getMimeType(fileName);
  }

  /// Formats the success message and shows a custom notification dialog.
  static void showSuccessNotification({
    required BuildContext context,
    required String savedPath,
    required String androidDownloadMessage,
    required String Function(String displayPath) generalMessageBuilder,
  }) {
    String message;
    if (Platform.isAndroid) {
      message = androidDownloadMessage;
    } else {
      final displayPath = savedPath.length > 40
          ? '...${savedPath.substring(savedPath.length - 37)}'
          : savedPath;
      message = generalMessageBuilder(displayPath);
    }

    showNotificationDialog(context, message, isError: false);
  }

  /// Shows an error notification dialog.
  static void showErrorNotification({
    required BuildContext context,
    required String errorMessage,
  }) {
    showNotificationDialog(context, errorMessage, isError: true);
  }
}
