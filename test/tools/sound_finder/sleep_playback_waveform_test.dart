import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/helpers/wav_pcm16_encoder.dart';
import 'package:tool_lab/tools/sound_finder/sleep_session_data.dart';
import 'package:tool_lab/tools/sound_finder/widgets/sf_sleep_playback_waveform.dart';

void main() {
  testWidgets('quiet WAV loads a full-width non-flat waveform', (tester) async {
    final file = File(
      '.agents/temp/sleep-waveform-widget-${DateTime.now().microsecondsSinceEpoch}.wav',
    );
    file.parent.createSync(recursive: true);
    final samples = Float32List.fromList([
      for (var i = 0; i < 8000; i++) i < 4000 ? (i.isEven ? 0.008 : -0.008) : 0,
    ]);
    file.writeAsBytesSync(
      WavPcm16Encoder.encode(
        samples,
        frames: samples.length,
        sampleRate: 8000,
        channels: 1,
      ),
    );
    final start = DateTime(2026, 10, 25);
    final head = ValueNotifier<DateTime?>(start);
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              child: SfSleepPlaybackWaveform(
                event: SleepEvent(
                  fileName: file.uri.pathSegments.last,
                  startedAt: start,
                  endedAt: start.add(const Duration(seconds: 1)),
                  peakAmplitude: 0.008,
                ),
                file: file,
                playhead: head,
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();
      final waveform = find.descendant(
        of: find.byType(SfSleepPlaybackWaveform),
        matching: find.byType(CustomPaint),
      );
      final painter = tester.widget<CustomPaint>(waveform).painter as dynamic;
      expect(tester.getSize(waveform).width, 292);
      expect(painter.peaks, isNotNull);
      expect(painter.peaks.first, greaterThan(0.9));
      expect(painter.peaks.last, 0);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      head.dispose();
      if (file.existsSync()) file.deleteSync();
    }
  });
}
