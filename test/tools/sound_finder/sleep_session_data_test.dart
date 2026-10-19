import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/tools/sound_finder/sleep_session_data.dart';
import 'package:tool_lab/tools/sound_finder/sleep_session_store.dart';

void main() {
  SleepSessionData session() => SleepSessionData(
    path: '/root/session-20261018-230000',
    startedAt: DateTime(2026, 10, 18, 23),
    endedAt: DateTime(2026, 10, 19, 7),
    targetMinutes: 480,
    threshold: 0.005,
    adaptiveThreshold: false,
    events: [
      SleepEvent(
        fileName: 'chunk-20261019-010015.wav',
        startedAt: DateTime(2026, 10, 19, 1),
        endedAt: DateTime(2026, 10, 19, 1, 0, 15),
        peakAmplitude: 0.1,
        annotation: 'cough',
      ),
    ],
    updatedAt: 42,
  );

  test('json round trip keeps events, times and sync clock', () {
    final original = session();
    final copy = SleepSessionData.fromJson(original.path, original.toJson());
    expect(copy.startedAt, original.startedAt);
    expect(copy.endedAt, original.endedAt);
    expect(copy.updatedAt, 42);
    expect(copy.events.single.fileName, 'chunk-20261019-010015.wav');
    expect(copy.events.single.endedAt, original.events.single.endedAt);
    expect(copy.events.single.annotation, 'cough');
  });

  test('times are stored as UTC', () {
    final json = session().toJson();
    expect(json['startedAt'], endsWith('Z'));
  });

  test('legacy absolute file paths are reduced to the file name', () {
    final event = SleepEvent.fromJson({
      'file': r'C:\docs\sleep_recordings\session-x\chunk-1.wav',
      'startedAt': '2026-10-19T01:00:00.000',
      'endedAt': '2026-10-19T01:00:15.000',
      'peakAmplitude': 0.1,
    });
    expect(event.fileName, 'chunk-1.wav');
    expect(event.startedAt, DateTime(2026, 10, 19, 1));
  });

  test('sync ids split into session and chunk', () {
    final id = SleepSessionStore.chunkSyncId('session-1', 'chunk-2.wav');
    expect(SleepSessionStore.parseSyncId(id), ('session-1', 'chunk-2.wav'));
    expect(SleepSessionStore.parseSyncId('session-1'), ('session-1', null));
  });
}
