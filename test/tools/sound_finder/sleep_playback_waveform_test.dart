import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/tools/sound_finder/sleep_session_data.dart';
import 'package:tool_lab/tools/sound_finder/widgets/sf_sleep_playback_waveform.dart';

void main() {
  testWidgets('waveform fills its available width even before loading', (
    tester,
  ) async {
    final start = DateTime(2026, 10, 25);
    final head = ValueNotifier<DateTime?>(start);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            child: SfSleepPlaybackWaveform(
              event: SleepEvent(
                fileName: 'missing.wav',
                startedAt: start,
                endedAt: start.add(const Duration(seconds: 15)),
                peakAmplitude: 0.1,
              ),
              file: File('missing.wav'),
              playhead: head,
            ),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(SfSleepPlaybackWaveform)).width, 300);
    expect(tester.getSize(find.byType(SfSleepPlaybackWaveform)).height, 36);
    await tester.pumpWidget(const SizedBox.shrink());
    head.dispose();
  });
}
