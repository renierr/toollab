import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

import '../api/local_station_client.dart';
import '../api/weather_http.dart';
import '../models/local_station_manifest.dart';
import '../weather_state.dart';
import 'weather_coordinates_link.dart';

/// Adds a local station server by its address after reading its manifest.
class WeatherLocalStationDialog extends StatefulWidget {
  const WeatherLocalStationDialog({super.key});

  static Future<void> show(BuildContext context) => showDialog<void>(
    context: context,
    builder: (_) => const WeatherLocalStationDialog(),
  );

  @override
  State<WeatherLocalStationDialog> createState() =>
      _WeatherLocalStationDialogState();
}

class _WeatherLocalStationDialogState extends State<WeatherLocalStationDialog>
    with DisposeCleanup {
  final TextEditingController _controller = TextEditingController();
  LocalStationManifest? _manifest;
  String? _error;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    onDispose(_controller.dispose);
  }

  Future<void> _check() async {
    final l10n = AppLocalizations.of(context);
    final url = LocalStationClient.manifestUrl(_controller.text);
    if (url == null) {
      setState(() => _error = l10n.weatherLocalStationInvalidAddress);
      return;
    }
    setState(() {
      _checking = true;
      _error = null;
      _manifest = null;
    });
    String? error;
    LocalStationManifest? manifest;
    try {
      manifest = await context.read<WeatherState>().inspectLocalStation(url);
    } on LocalStationVersionException catch (e) {
      error = l10n.weatherLocalStationVersion(e.version);
    } on WeatherException catch (e) {
      error = switch (e.error) {
        WeatherError.notFound => l10n.weatherLocalStationNotFound,
        WeatherError.invalidData => l10n.weatherLocalStationInvalid,
        _ => l10n.weatherLocalStationUnreachable,
      };
    }
    if (!mounted) return;
    setState(() {
      _checking = false;
      _manifest = manifest;
      _error = error;
    });
  }

  Future<void> _add(LocalStationManifest manifest) async {
    final state = context.read<WeatherState>();
    Navigator.pop(context);
    await state.addLocalStation(manifest);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final manifest = _manifest;
    return ResponsiveAlertDialog(
      icon: const Icon(Icons.sensors),
      title: Text(l10n.weatherLocalStation),
      scrollable: true,
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.url,
              autocorrect: false,
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => _check(),
              onChanged: (_) {
                if (_manifest != null || _error != null) {
                  setState(() {
                    _manifest = null;
                    _error = null;
                  });
                }
              },
              decoration: InputDecoration(
                labelText: l10n.weatherLocalStationAddress,
                hintText: 'http://192.168.1.50:8080',
                helperText: l10n.weatherLocalStationHelper,
                helperMaxLines: 2,
                errorText: _error,
                errorMaxLines: 3,
                border: const OutlineInputBorder(),
              ),
            ),
            if (_checking)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: LinearProgressIndicator(),
              ),
            if (manifest != null) _ManifestSummary(manifest: manifest),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        if (manifest == null)
          FilledButton(
            onPressed: _checking ? null : _check,
            child: Text(l10n.weatherLocalStationCheck),
          )
        else
          FilledButton(
            onPressed: () => _add(manifest),
            child: Text(l10n.weatherLocalStationAdd),
          ),
      ],
    );
  }
}

class _ManifestSummary extends StatelessWidget {
  const _ManifestSummary({required this.manifest});

  final LocalStationManifest manifest;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final elevation = manifest.elevation;
    String label(LocalStationSection section) => switch (section) {
      LocalStationSection.observations => l10n.weatherLocalStationMeasurements,
      LocalStationSection.forecast => l10n.weatherLocalStationForecast,
      LocalStationSection.warnings => l10n.weatherLocalStationWarnings,
      LocalStationSection.days => l10n.weatherLocalStationDays,
    };
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(manifest.name, style: theme.textTheme.titleMedium),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              WeatherCoordinatesLink(
                latitude: manifest.latitude,
                longitude: manifest.longitude,
              ),
              if (elevation != null)
                Text(
                  '${elevation.round()} m',
                  style: theme.textTheme.bodySmall,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            l10n.weatherLocalStationOffers,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          for (final entry in manifest.sections.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.value.fields.isEmpty
                          ? label(entry.key)
                          : '${label(entry.key)} · '
                                '${l10n.weatherLocalStationFields(entry.value.fields.length)}',
                    ),
                  ),
                ],
              ),
            ),
          if (manifest.sections.length < LocalStationSection.values.length) ...[
            const SizedBox(height: 8),
            Text(
              l10n.weatherLocalStationFallback,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
