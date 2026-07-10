import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';
import 'package:tool_lab/helpers/clipboard_helper.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';

import '../audio/mic_analyzer.dart';
import '../sf_format.dart';
import '../sound_finder_colors.dart';
import '../sound_finder_state.dart';
import 'sf_readout.dart';
import 'sf_spectrogram_view.dart';
import 'sf_spectrum_view.dart';

/// Encodes captured RGBA frames into an animated PNG (APNG) — lossless and
/// full-color, unlike GIF's 256-color palette. Runs in a background isolate
/// (via [compute]) so zlib compression never blocks the UI. [args] carries
/// `fps` (int) and `frames` (list of {w, h, bytes}).
Uint8List _encodeSpectrumApng(Map<String, dynamic> args) {
  final int fps = args['fps'] as int;
  final List<dynamic> frames = args['frames'] as List<dynamic>;
  final int durationMs = (1000 / fps).round();
  final encoder = img.PngEncoder()..start(frames.length);
  for (final dynamic f in frames) {
    final Map<dynamic, dynamic> m = f as Map<dynamic, dynamic>;
    final image = img.Image.fromBytes(
      width: m['w'] as int,
      height: m['h'] as int,
      bytes: (m['bytes'] as Uint8List).buffer,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    )..frameDuration = durationMs;
    encoder.addFrame(image);
  }
  return encoder.finish() ?? Uint8List(0);
}

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

  final GlobalKey _shotKey = GlobalKey();

  double? _logLo;
  double? _logHi;
  bool _maxHold = true;
  bool _showSpectrogram = true;

  // APNG recording of the live visualization.
  static const int _recFps = 10;
  static const int _recMaxFrames = 200; // ~20 s hard cap
  static const double _recMaxWidth =
      540; // cap capture width (APNG is lossless, so keep it crisp)
  bool _recording = false;
  bool _saving = false;
  bool _capturing = false;
  Timer? _recTimer;
  final List<Map<String, dynamic>> _frames = [];

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

  /// Renders the spectrum graph to PNG bytes at the display pixel ratio.
  Future<Uint8List?> _capturePng() async {
    final RenderRepaintBoundary? boundary =
        _shotKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final double ratio = MediaQuery.of(context).devicePixelRatio;
    final ui.Image image = await boundary.toImage(pixelRatio: ratio);
    try {
      final ByteData? data = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      return data?.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  Future<void> _copyImage() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final Uint8List? bytes = await _capturePng();
    if (bytes == null) return;
    final bool ok = await ClipboardHelper.copyImageBytes(bytes);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text(ok ? l10n.sfImageCopied : l10n.sfImageCopyFailed)),
    );
  }

  Future<void> _saveImage() async {
    final Uint8List? bytes = await _capturePng();
    if (bytes == null || !mounted) return;
    await FileSaveHelper.saveFile(
      context: context,
      suggestedName: 'spectrum.png',
      bytes: bytes,
    );
  }

  void _toggleRecording() {
    if (_saving) return;
    if (_recording) {
      _stopRecording();
    } else {
      _startRecording();
    }
  }

  void _startRecording() {
    _frames.clear();
    setState(() => _recording = true);
    _recTimer = Timer.periodic(
      Duration(milliseconds: (1000 / _recFps).round()),
      (_) => _captureFrame(),
    );
  }

  /// Grabs the current visualization as raw RGBA (downscaled to bound size).
  /// Cheap GPU→CPU readback only — encoding is deferred to [_stopRecording].
  Future<void> _captureFrame() async {
    if (_capturing || !_recording) return;
    _capturing = true;
    try {
      final RenderRepaintBoundary? boundary =
          _shotKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final double ratio = (_recMaxWidth / boundary.size.width).clamp(0.1, 1.0);
      final ui.Image image = await boundary.toImage(pixelRatio: ratio);
      final int w = image.width;
      final int h = image.height;
      final ByteData? data = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      image.dispose();
      if (data == null || !_recording) return;
      _frames.add({
        'w': w,
        'h': h,
        'bytes': Uint8List.fromList(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        ),
      });
      if (mounted) setState(() {});
      if (_frames.length >= _recMaxFrames) _stopRecording();
    } finally {
      _capturing = false;
    }
  }

  Future<void> _stopRecording() async {
    _recTimer?.cancel();
    _recTimer = null;
    if (!_recording) return;
    setState(() => _recording = false);
    if (_frames.isEmpty) return;

    setState(() => _saving = true);
    final Uint8List apng = await compute(_encodeSpectrumApng, <String, dynamic>{
      'fps': _recFps,
      'frames': List<Map<String, dynamic>>.from(_frames),
    });
    _frames.clear();
    if (!mounted) return;
    setState(() => _saving = false);
    if (apng.isEmpty) return;
    await FileSaveHelper.saveFile(
      context: context,
      suggestedName: 'spectrum-clip.png',
      bytes: apng,
    );
  }

  @override
  void dispose() {
    _recTimer?.cancel();
    super.dispose();
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
            icon: Icon(
              _showSpectrogram ? Icons.gradient : Icons.gradient_outlined,
              color: _showSpectrogram ? SoundFinderColors.spectrumHigh : null,
            ),
            tooltip: l10n.sfSpectrogram,
            onPressed: () =>
                setState(() => _showSpectrogram = !_showSpectrogram),
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out_map),
            tooltip: l10n.sfResetZoom,
            onPressed: () => _reset(nyquist),
          ),
          IconButton(
            icon: Icon(
              _recording ? Icons.stop_circle : Icons.fiber_manual_record,
              color: _recording ? AppTheme.statusRed : null,
            ),
            tooltip: _recording ? l10n.sfStopRecording : l10n.sfRecordClip,
            onPressed: _saving ? null : _toggleRecording,
          ),
          PopupMenuButton<int>(
            icon: const Icon(Icons.photo_camera_outlined),
            tooltip: l10n.sfScreenshot,
            onSelected: (v) => v == 0 ? _copyImage() : _saveImage(),
            itemBuilder: (context) => [
              PopupMenuItem<int>(
                value: 0,
                child: Row(
                  children: [
                    const Icon(Icons.copy, size: 20),
                    const SizedBox(width: 12),
                    Text(l10n.sfCopyImage),
                  ],
                ),
              ),
              PopupMenuItem<int>(
                value: 1,
                child: Row(
                  children: [
                    const Icon(Icons.download, size: 20),
                    const SizedBox(width: 12),
                    Text(l10n.sfSaveImage),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // One FittedBox around the whole row so all three readouts shrink
            // by the same factor on narrow screens instead of independently.
            SizedBox(
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SfReadout(
                      label: l10n.sfDominant,
                      value: formatHz(state.smoothPeakHz),
                      valueColor: SoundFinderColors.spectrumHigh,
                    ),
                    const SizedBox(width: 24),
                    SfReadout(
                      label: l10n.sfLevel,
                      value: '${state.smoothDb.toStringAsFixed(0)} dB',
                    ),
                    const SizedBox(width: 24),
                    SfReadout(
                      label: l10n.sfRange,
                      value: '${formatHz(visMin)} – ${formatHz(visMax)}',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<SpectrumResolution>(
              showSelectedIcon: false,
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              segments: [
                ButtonSegment(
                  value: SpectrumResolution.fast,
                  label: Text(l10n.sfResFast),
                ),
                ButtonSegment(
                  value: SpectrumResolution.balanced,
                  label: Text(l10n.sfResBalanced),
                ),
                ButtonSegment(
                  value: SpectrumResolution.fine,
                  label: Text(l10n.sfResFine),
                ),
              ],
              selected: {state.spectrumResolution},
              onSelectionChanged: (sel) => context
                  .read<SoundFinderState>()
                  .setSpectrumResolution(sel.first),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.sfBinWidth(
                state.spectrumResolution.binHz.toStringAsFixed(1),
              ),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Stack(
                children: [
                  // The RepaintBoundary is the sole capture source; the REC and
                  // saving overlays are siblings so they never land in a frame.
                  Positioned.fill(
                    child: RepaintBoundary(
                      key: _shotKey,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          // Opaque equivalent of the 0.4 surface tint over the
                          // scaffold — looks identical on screen but keeps
                          // captured frames/screenshots free of partial alpha.
                          color: Color.alphaBlend(
                            theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.4),
                            theme.scaffoldBackgroundColor,
                          ),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final double width = constraints.maxWidth;
                              return Listener(
                                onPointerSignal: (event) {
                                  if (event is PointerScrollEvent) {
                                    final double factor =
                                        event.scrollDelta.dy < 0
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
                                  behavior: HitTestBehavior.opaque,
                                  onScaleStart: (d) => _onScaleStart(d, width),
                                  onScaleUpdate: (d) =>
                                      _onScaleUpdate(d, width, nyquist),
                                  onDoubleTap: () => _reset(nyquist),
                                  child: Column(
                                    children: [
                                      Expanded(
                                        flex: _showSpectrogram ? 5 : 10,
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
                                      if (_showSpectrogram)
                                        Expanded(
                                          flex: 5,
                                          child: SfSpectrogramView(
                                            magnitudes: analysis.magnitudes,
                                            binHz: analysis.binHz,
                                            minHz: visMin,
                                            maxHz: visMax,
                                            fullMaxHz: nyquist,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_recording)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: _RecBadge(seconds: _frames.length / _recFps),
                    ),
                  if (_saving) const Positioned.fill(child: _SavingOverlay()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Recording indicator overlaid on the spectrum (outside the capture boundary).
class _RecBadge extends StatelessWidget {
  final double seconds;

  const _RecBadge({required this.seconds});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.fiber_manual_record,
            color: AppTheme.statusRed,
            size: 12,
          ),
          const SizedBox(width: 6),
          Text(
            '${l10n.sfRecordingLabel} ${seconds.toStringAsFixed(1)}s',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dimmed overlay with a spinner shown while the GIF is being encoded.
class _SavingOverlay extends StatelessWidget {
  const _SavingOverlay();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.45),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(l10n.sfSavingClip, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}
