import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../sf_format.dart';
import '../sound_finder_colors.dart';
import '../sound_finder_state.dart';
import 'sf_readout.dart';
import 'sf_spectrum_view.dart';

/// Enlarged, zoomable spectrum for pinpointing a frequency. Pinch to zoom the
/// log-frequency axis and drag to pan; double-tap resets to the full range.
class SfSpectrumFullscreen extends StatefulWidget {
  const SfSpectrumFullscreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SfSpectrumFullscreen()),
    );
  }

  @override
  State<SfSpectrumFullscreen> createState() => _SfSpectrumFullscreenState();
}

class _SfSpectrumFullscreenState extends State<SfSpectrumFullscreen> {
  static const double _minHz = 20;
  static const double _defaultMaxHz = 22050;
  static const double _minSpan = 0.26; // ~1.3× narrowest visible range

  double? _logLo;
  double? _logHi;
  bool _maxHold = true;

  double _startLo = 0;
  double _startSpan = 1;
  double _startFocalLog = 0;

  double get _fullMin => math.log(_minHz);

  double _fullMax(double nyquist) =>
      math.log(nyquist > _minHz ? nyquist : _defaultMaxHz);

  void _ensureInit(double nyquist) {
    _logLo ??= _fullMin;
    _logHi ??= _fullMax(nyquist);
  }

  void _reset(double nyquist) {
    setState(() {
      _logLo = _fullMin;
      _logHi = _fullMax(nyquist);
    });
  }

  /// Zooms the visible range by [factor] (>1 zooms in) anchored at [focalX],
  /// keeping the frequency under the cursor fixed. Used for mouse-wheel zoom.
  void _zoomAt(double factor, double focalX, double width, double nyquist) {
    final double lo = _logLo!;
    final double span = _logHi! - lo;
    final double fullSpan = _fullMax(nyquist) - _fullMin;
    final double newSpan = (span / factor).clamp(_minSpan, fullSpan);
    final double frac = (focalX / width).clamp(0.0, 1.0);
    final double focalLog = lo + frac * span;
    final double maxLo = math.max(_fullMin, _fullMax(nyquist) - newSpan);
    final double newLo = (focalLog - frac * newSpan).clamp(_fullMin, maxLo);
    setState(() {
      _logLo = newLo;
      _logHi = newLo + newSpan;
    });
  }

  void _onScaleStart(ScaleStartDetails d, double width) {
    _startLo = _logLo!;
    _startSpan = _logHi! - _logLo!;
    final double frac = (d.localFocalPoint.dx / width).clamp(0.0, 1.0);
    _startFocalLog = _startLo + frac * _startSpan;
  }

  void _onScaleUpdate(ScaleUpdateDetails d, double width, double nyquist) {
    final double fullSpan = _fullMax(nyquist) - _fullMin;
    final double newSpan = (_startSpan / d.scale).clamp(_minSpan, fullSpan);
    final double frac = (d.localFocalPoint.dx / width).clamp(0.0, 1.0);
    // math.max guards against float rounding making the upper bound dip just
    // below _fullMin when fully zoomed out (clamp throws if lower > upper).
    final double maxLo = math.max(_fullMin, _fullMax(nyquist) - newSpan);
    final double lo = (_startFocalLog - frac * newSpan).clamp(_fullMin, maxLo);
    setState(() {
      _logLo = lo;
      _logHi = lo + newSpan;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = context.watch<SoundFinderState>();
    final analysis = state.analysis;
    final double nyquist = analysis.maxFreqHz > _minHz
        ? analysis.maxFreqHz
        : _defaultMaxHz;
    _ensureInit(nyquist);

    final double visMin = math.exp(_logLo!);
    final double visMax = math.exp(_logHi!);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.sfSpectrum),
        actions: [
          IconButton(
            icon: Icon(
              _maxHold ? Icons.trending_up : Icons.trending_up_outlined,
              color: _maxHold ? SoundFinderColors.violet : null,
            ),
            tooltip: l10n.sfMaxHold,
            onPressed: () => setState(() => _maxHold = !_maxHold),
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out_map),
            tooltip: l10n.sfResetZoom,
            onPressed: () => _reset(nyquist),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SfReadout(
                  label: l10n.sfDominant,
                  value: formatHz(state.smoothPeakHz),
                  valueColor: SoundFinderColors.spectrumHigh,
                ),
                SfReadout(
                  label: l10n.sfLevel,
                  value: '${state.smoothDb.toStringAsFixed(0)} dB',
                ),
                SfReadout(
                  label: l10n.sfRange,
                  value: '${formatHz(visMin)} – ${formatHz(visMax)}',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.4,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final double width = constraints.maxWidth;
                      return Listener(
                        onPointerSignal: (event) {
                          if (event is PointerScrollEvent) {
                            final double factor = event.scrollDelta.dy < 0
                                ? 1.2
                                : 1 / 1.2;
                            _zoomAt(
                              factor,
                              event.localPosition.dx,
                              width,
                              nyquist,
                            );
                          }
                        },
                        child: GestureDetector(
                          onScaleStart: (d) => _onScaleStart(d, width),
                          onScaleUpdate: (d) =>
                              _onScaleUpdate(d, width, nyquist),
                          onDoubleTap: () => _reset(nyquist),
                          child: SfSpectrumView(
                            magnitudes: analysis.magnitudes,
                            binHz: analysis.binHz,
                            peakFreqHz: state.smoothPeakHz,
                            minHz: visMin,
                            maxHz: visMax,
                            showAxes: true,
                            maxHold: _maxHold,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.sfZoomHint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
