import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/data_row.dart'; // InfoRow
import 'package:tool_lab/widgets/info_card.dart';
import 'package:tool_lab/widgets/tool_layout.dart';

class GpsInfoPage extends StatefulWidget {
  const GpsInfoPage({super.key});

  @override
  State<GpsInfoPage> createState() => _GpsInfoPageState();
}

class _GpsInfoPageState extends State<GpsInfoPage> with DisposeCleanup {
  static const _channel = MethodChannel('de.renier.tool_lab/gps_info');

  Position? _currentPosition;
  StreamSubscription<Position>? _positionSubscription;
  bool _permissionDenied = false;

  int _satelliteCount = 0;
  int _usedInFixCount = 0;
  List<Map<String, dynamic>> _satellites = [];
  List<Map<String, dynamic>> _providers = [];

  @override
  void initState() {
    super.initState();
    _initLocation();

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onGnssStatusChanged') {
        final data = Map<String, dynamic>.from(call.arguments as Map);
        final count = data['satelliteCount'] as int;
        final used = data['usedInFixCount'] as int;
        final list = List<dynamic>.from(data['satellites'] as List);

        final parsed = list
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

        if (mounted) {
          setState(() {
            _satelliteCount = count;
            _usedInFixCount = used;
            _satellites = parsed;
          });
        }
      }
    });

    onDispose(() {
      _positionSubscription?.cancel();
      if (Platform.isAndroid) {
        _channel.invokeMethod('stopGpsInfoUpdates');
      }
    });
  }

  Future<void> _initLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Location services disabled
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _permissionDenied = true;
          });
        }
        return;
      }

      if (!mounted) return;

      _positionSubscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.best,
              distanceFilter: 0,
            ),
          ).listen(
            (position) {
              if (mounted) {
                setState(() {
                  _currentPosition = position;
                });
              }
            },
            onError: (e) {
              debugPrint('[GpsInfoPage] Geolocator stream error: $e');
            },
          );

      if (Platform.isAndroid) {
        if (!mounted) {
          _channel.invokeMethod('stopGpsInfoUpdates');
          return;
        }
        await _channel.invokeMethod('startGpsInfoUpdates');
        if (!mounted) {
          _channel.invokeMethod('stopGpsInfoUpdates');
          return;
        }
        await _loadProviders();
      }
    } catch (e) {
      debugPrint('[GpsInfoPage] initLocation error: $e');
    }
  }

  Future<void> _loadProviders() async {
    try {
      final List<dynamic> providersList =
          await _channel.invokeMethod('getProviders') as List<dynamic>;
      if (mounted) {
        setState(() {
          _providers = providersList
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('[GpsInfoPage] loadProviders error: $e');
    }
  }

  String _getConstellationName(BuildContext context, int type) {
    final l10n = AppLocalizations.of(context);
    switch (type) {
      case 1:
        return l10n.gpsInfoConstellationGps;
      case 2:
        return l10n.gpsInfoConstellationSbas;
      case 3:
        return l10n.gpsInfoConstellationGlonass;
      case 4:
        return l10n.gpsInfoConstellationQzss;
      case 5:
        return l10n.gpsInfoConstellationBeidou;
      case 6:
        return l10n.gpsInfoConstellationGalileo;
      case 7:
        return l10n.gpsInfoConstellationIrnss;
      default:
        return l10n.gpsInfoConstellationUnknown;
    }
  }

  Color _getConstellationColor(int type) {
    switch (type) {
      case 1:
        return AppTheme.accentBlue;
      case 3:
        return AppTheme.accentRed;
      case 5:
        return AppTheme.accentAmber;
      case 6:
        return AppTheme.accentGreen;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final detectedConstellations = _satellites
        .map((s) => s['constellationType'] as int)
        .toSet()
        .toList();

    return ToolLayout(
      title: l10n.gpsInfoTitle,
      child: _permissionDenied
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  l10n.gpsStoreCaptureFailed,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppTheme.accentRed,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // 1. Current Position Details
                InfoCard(
                  icon: Icons.my_location,
                  title: l10n.gpsInfoPositionDetails,
                  titleColor: AppTheme.accentBlue,
                  child: Column(
                    children: [
                      InfoRow(
                        label: l10n.gpsInfoLatitude,
                        value: _currentPosition != null
                            ? _currentPosition!.latitude.toStringAsFixed(7)
                            : '--',
                      ),
                      const Divider(height: 16),
                      InfoRow(
                        label: l10n.gpsInfoLongitude,
                        value: _currentPosition != null
                            ? _currentPosition!.longitude.toStringAsFixed(7)
                            : '--',
                      ),
                      const Divider(height: 16),
                      InfoRow(
                        label: l10n.gpsInfoAltitude,
                        value: _currentPosition != null
                            ? '${_currentPosition!.altitude.toStringAsFixed(1)} m'
                            : '--',
                      ),
                      const Divider(height: 16),
                      InfoRow(
                        label: l10n.gpsInfoAccuracy,
                        value: _currentPosition != null
                            ? '±${_currentPosition!.accuracy.toStringAsFixed(1)} m'
                            : '--',
                      ),
                      const Divider(height: 16),
                      InfoRow(
                        label: l10n.gpsInfoSpeed,
                        value: _currentPosition != null
                            ? '${(_currentPosition!.speed * 3.6).toStringAsFixed(1)} km/h'
                            : '--',
                      ),
                      const Divider(height: 16),
                      InfoRow(
                        label: l10n.gpsInfoHeading,
                        value: _currentPosition != null
                            ? '${_currentPosition!.heading.toStringAsFixed(1)}°'
                            : '--',
                      ),
                      const Divider(height: 16),
                      InfoRow(
                        label: l10n.gpsInfoTimestamp,
                        value: _currentPosition != null
                            ? DateFormat.yMMMd().add_Hms().format(
                                _currentPosition!.timestamp,
                              )
                            : '--',
                      ),
                      const Divider(height: 16),
                      InfoRow(
                        label: l10n.gpsInfoMocked,
                        value: _currentPosition != null
                            ? (_currentPosition!.isMocked
                                  ? l10n.commonYes
                                  : l10n.commonNo)
                            : '--',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Hardware / Satellites / Constellations Info
                if (Platform.isAndroid) ...[
                  InfoCard(
                    icon: Icons.satellite_alt_outlined,
                    title: l10n.gpsInfoHardwareDetails,
                    titleColor: AppTheme.accentGreen,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InfoRow(
                          label: l10n.gpsInfoSatelliteCount,
                          value: _satelliteCount.toString(),
                        ),
                        const Divider(height: 16),
                        InfoRow(
                          label: l10n.gpsInfoSatelliteCountUsed,
                          value: _usedInFixCount.toString(),
                        ),
                        if (detectedConstellations.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            l10n.gpsInfoHardwareDetails,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8.0,
                            runSpacing: 8.0,
                            children: detectedConstellations.map((type) {
                              final name = _getConstellationName(context, type);
                              final color = _getConstellationColor(type);
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.15),
                                  border: Border.all(
                                    color: color.withValues(alpha: 0.4),
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  name,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: color,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. Detailed Satellite List
                  if (_satellites.isNotEmpty) ...[
                    InfoCard(
                      icon: Icons.list_alt_outlined,
                      title: l10n.gpsInfoSatelliteList,
                      titleColor: AppTheme.accentAmber,
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 300),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: 530,
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: _satellites.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final sat = _satellites[index];
                                final svid = sat['svid'] as int;
                                final type = sat['constellationType'] as int;
                                final cn0 = (sat['cn0DbHz'] as num).toDouble();
                                final used = sat['usedInFix'] as bool;
                                final elevation =
                                    (sat['elevationDegrees'] as num).toDouble();
                                final azimuth = (sat['azimuthDegrees'] as num)
                                    .toDouble();

                                final constellationName = _getConstellationName(
                                  context,
                                  type,
                                );
                                final color = _getConstellationColor(type);

                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8.0,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: color,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      SizedBox(
                                        width: 170,
                                        child: Text(
                                          '$constellationName - ${l10n.gpsInfoSatelliteSvid(svid)}',
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      SizedBox(
                                        width: 100,
                                        child: Text(
                                          l10n.gpsInfoSatelliteCn0(cn0),
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                fontFamily: 'monospace',
                                                fontWeight: FontWeight.w600,
                                              ),
                                          maxLines: 1,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      SizedBox(
                                        width: 75,
                                        child: Text(
                                          l10n.gpsInfoSatelliteElevation(
                                            elevation,
                                          ),
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: theme
                                                    .colorScheme
                                                    .onSurface
                                                    .withValues(alpha: 0.6),
                                              ),
                                          maxLines: 1,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      SizedBox(
                                        width: 75,
                                        child: Text(
                                          l10n.gpsInfoSatelliteAzimuth(azimuth),
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: theme
                                                    .colorScheme
                                                    .onSurface
                                                    .withValues(alpha: 0.6),
                                              ),
                                          maxLines: 1,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      SizedBox(
                                        width: 60,
                                        child: used
                                            ? Container(
                                                alignment: Alignment.center,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 4,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.statusGreen
                                                      .withValues(alpha: 0.15),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  l10n.gpsInfoSatelliteUsed,
                                                  style: theme
                                                      .textTheme
                                                      .labelSmall
                                                      ?.copyWith(
                                                        color: AppTheme
                                                            .statusGreen,
                                                        fontSize: 9,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                  maxLines: 1,
                                                ),
                                              )
                                            : const SizedBox.shrink(),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 4. System Location Providers
                  if (_providers.isNotEmpty) ...[
                    InfoCard(
                      icon: Icons.settings_input_antenna_outlined,
                      title: l10n.gpsInfoLocationProviders,
                      titleColor: AppTheme.accentBlue,
                      child: Column(
                        children: _providers.map((provider) {
                          final name = provider['name'] as String;
                          final enabled = provider['enabled'] as bool;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  name.toUpperCase(),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        (enabled
                                                ? AppTheme.statusGreen
                                                : AppTheme.statusRed)
                                            .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    enabled
                                        ? l10n.gpsInfoProviderEnabled
                                        : l10n.gpsInfoProviderDisabled,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: enabled
                                          ? AppTheme.statusGreen
                                          : AppTheme.statusRed,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ] else ...[
                  InfoCard(
                    icon: Icons.info_outline,
                    title: l10n.gpsInfoHardwareDetails,
                    titleColor: AppTheme.accentAmber,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        l10n.gpsInfoStatusNotAvailable,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
