import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:tool_lab/constants.dart';
import 'package:tool_lab/theme/theme.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _packageInfo = info);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final version = _packageInfo != null
        ? '${_packageInfo!.version} (build ${_packageInfo!.buildNumber})'
        : '${AppConstants.appVersion} (build ?)';

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 24),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  'assets/logo/logo.png',
                  width: 80,
                  height: 80,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppConstants.appName,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.accentBlue.withAlpha(30),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'v$version',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                    color: AppTheme.accentBlue,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: AppTheme.accentBlue,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'About',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'ToolLab is a collection of utility tools for your device. '
                              'It includes sensors, calculator, device information, '
                              'NFC tag reading/writing, PDF viewing, note taking, '
                              'and more — all in one app.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: AppTheme.accentAmber,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Disclaimer',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'This app is provided "as is" without warranty of any kind. '
                              'The developer shall not be held liable for any damages, '
                              'data loss, or issues arising from the use of this software.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: Icon(
                    Icons.description_outlined,
                    color: AppTheme.accentBlue,
                  ),
                  title: const Text('Third-Party Licenses'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: AppConstants.appName,
                    applicationVersion: version,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
