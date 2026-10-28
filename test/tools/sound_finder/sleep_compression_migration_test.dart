import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/helpers/wav_pcm16_encoder.dart';
import 'package:tool_lab/services/app_http_client.dart';
import 'package:tool_lab/services/sync_service.dart';
import 'package:tool_lab/tools/sound_finder/audio/sleep_wav_compressor.dart';
import 'package:tool_lab/tools/sound_finder/sleep_session_data.dart';
import 'package:tool_lab/tools/sound_finder/sleep_session_store.dart';
import 'package:tool_lab/tools/sound_finder/sleep_sync_delegate.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory work;

  setUp(() async {
    work = Directory(
      '.agents/temp/sleep-migration-${DateTime.now().microsecondsSinceEpoch}',
    ).absolute;
    await work.create(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'getTemporaryDirectory') {
            return Platform.isLinux && Directory('/tmp/opencode').existsSync()
                ? '/tmp/opencode'
                : work.path;
          }
          return null;
        });
    SleepSessionStore.overrideRootForTest('${work.path}/sleep_recordings');
  });

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.instance.dbPathOverride = inMemoryDatabasePath;
  });

  tearDownAll(() async {
    await DatabaseService.instance.close();
  });

  test('atomic replacement preserves the destination on failure', () async {
    final scope = TempFileManager.createScope();
    final destination = File('${work.path}/session.json');
    await destination.writeAsString('before');
    await TempFileManager.sessionDir;
    await scope.replaceAtomically(
      destination,
      Uint8List.fromList(utf8.encode('after')),
    );
    expect(await destination.readAsString(), 'after');
    final directory = Directory('${work.path}/not-a-file');
    await directory.create();
    final sentinel = File('${directory.path}/sentinel');
    await sentinel.writeAsString('keep');
    await expectLater(
      scope.replaceAtomically(File(directory.path), Uint8List.fromList([1])),
      throwsA(isA<FileSystemException>()),
    );
    expect(await sentinel.readAsString(), 'keep');
    expect(scope.trackedCount, 0);
    expect(
      await work
          .list()
          .where((e) => e.path.contains('.tool_lab_atomic_'))
          .isEmpty,
      isTrue,
    );
    await scope.cleanTracked();
  });

  tearDown(() async {
    AppHttpClient.testClient = null;
    await TempFileManager.cleanSession();
    SleepSessionStore.overrideRootForTest(null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (await work.exists()) await work.delete(recursive: true);
  });

  test('sync replaces the old blob and another device receives FLAC', () async {
    final server = <String, Map<String, dynamic>>{};
    var failPush = false;
    AppHttpClient.testClient = MockClient((request) async {
      final path = request.url.path;
      if (request.method == 'GET' && path.endsWith('/metadata')) {
        return http.Response(
          jsonEncode({
            'success': true,
            'full': true,
            'records': [
              for (final r in server.values)
                {
                  'id': r['id'],
                  'updatedAt': r['updatedAt'],
                  'deleted': r['deleted'],
                },
            ],
          }),
          200,
        );
      }
      if (request.method == 'POST' && path.endsWith('/pull')) {
        final ids = (jsonDecode(request.body) as Map)['ids'] as List;
        return http.Response(
          jsonEncode({
            'success': true,
            'records': [
              for (final id in ids)
                if (server.containsKey(id)) server[id],
            ],
          }),
          200,
        );
      }
      if (request.method == 'POST') {
        if (failPush) return http.Response('failed', 503);
        final records = (jsonDecode(request.body) as Map)['records'] as List;
        for (final raw in records) {
          final record = Map<String, dynamic>.from(raw as Map);
          final old = server[record['id']];
          if (old == null ||
              (record['updatedAt'] as int) > (old['updatedAt'] as int)) {
            server[record['id'] as String] = record;
          }
        }
        return http.Response(jsonEncode({'success': true}), 200);
      }
      return http.Response('unexpected', 404);
    });
    final path = await SleepSessionStore.sessionPath('session-sync');
    await Directory(path).create(recursive: true);
    final wav = File('$path/chunk-1.wav');
    final samples = Float32List.fromList([
      for (var i = 0; i < 16000; i++) 0.1 * math.sin(i / 13),
    ]);
    final wavBytes = WavPcm16Encoder.encode(
      samples,
      frames: samples.length,
      sampleRate: 8000,
      channels: 1,
    );
    await wav.writeAsBytes(wavBytes);
    final start = DateTime.utc(2025, 1, 1);
    final data = SleepSessionData(
      path: path,
      startedAt: start,
      endedAt: start.add(const Duration(seconds: 2)),
      targetMinutes: 0,
      threshold: 0.01,
      adaptiveThreshold: false,
      events: [
        SleepEvent(
          fileName: 'chunk-1.wav',
          startedAt: start,
          endedAt: start.add(const Duration(seconds: 2)),
          peakAmplitude: 0.1,
        ),
      ],
    );
    await data.save();
    final original = data.toJson();
    final delegate = SleepSyncDelegate();
    Future<void> sync() async => SyncService.sync(
      baseUrl: 'https://test.invalid',
      userId: '',
      delegate: delegate,
      backendAlreadyChecked: true,
    );
    await sync();
    final id = SleepSessionStore.chunkSyncId('session-sync', 'chunk-1.wav');
    expect(
      ((server[id]!['data'] as Map)['audio'] as Map)['mimeType'],
      'audio/wav',
    );
    expect(
      await SleepSessionStore.compress(
        (await SleepSessionStore.byId('session-sync'))!,
      ),
      1,
    );
    failPush = true;
    await expectLater(sync(), throwsException);
    expect(await wav.exists(), isTrue);
    expect(
      ((server[id]!['data'] as Map)['audio'] as Map)['mimeType'],
      'audio/wav',
    );
    failPush = false;
    await sync();
    expect(await wav.exists(), isTrue);
    expect(
      ((server[id]!['data'] as Map)['audio'] as Map)['mimeType'],
      'audio/flac',
    );
    expect(server.length, 2);
    await sync();
    expect(await wav.exists(), isFalse);

    SleepSessionStore.overrideRootForTest('${work.path}/peer');
    final peerPath = await SleepSessionStore.sessionPath('session-sync');
    await Directory(peerPath).create(recursive: true);
    final peerWav = File('$peerPath/chunk-1.wav');
    await peerWav.writeAsBytes(wavBytes);
    await SleepSessionData.fromJson(peerPath, original).save(touch: false);
    final remoteSession = server['session-sync']!;
    await delegate.savePulledRecord(
      id: 'session-sync',
      data: Map<String, dynamic>.from(remoteSession['data'] as Map),
      updatedAt: remoteSession['updatedAt'] as int,
      deleted: false,
    );
    final beforeDownload = (await SleepSessionStore.byId('session-sync'))!;
    expect(beforeDownload.hasFile(beforeDownload.data.events.single), isTrue);
    expect(
      beforeDownload.data.fileFor(beforeDownload.data.events.single).path,
      peerWav.path,
    );
    final pending = await delegate.getLocalSyncRecords();
    expect(
      pending.singleWhere((r) => r['id'] == id)['updatedAt'],
      start.add(const Duration(seconds: 2)).millisecondsSinceEpoch,
    );
    await sync();
    final peer = (await SleepSessionStore.byId('session-sync'))!;
    expect(peer.data.events.single.fileName, 'chunk-1.flac');
    expect(await File('$peerPath/chunk-1.flac').exists(), isTrue);
    expect(await peerWav.exists(), isTrue);
    await sync();
    expect(await peerWav.exists(), isFalse);
  });

  test(
    'migration preserves WAV until matching remote versions are verified',
    () async {
      final path = await SleepSessionStore.sessionPath('session-test');
      await Directory(path).create(recursive: true);
      final wav = File('$path/chunk-1.wav');
      final flac = File('$path/chunk-1.flac');
      final samples = Float32List.fromList([
        for (var i = 0; i < 16000; i++) 0.1 * math.sin(i / 13),
      ]);
      await wav.writeAsBytes(
        WavPcm16Encoder.encode(
          samples,
          frames: samples.length,
          sampleRate: 8000,
          channels: 1,
        ),
      );
      final start = DateTime.utc(2025, 1, 1);
      final data = SleepSessionData(
        path: path,
        startedAt: start,
        endedAt: start.add(const Duration(seconds: 2)),
        targetMinutes: 0,
        threshold: 0.01,
        adaptiveThreshold: false,
        events: [
          SleepEvent(
            fileName: 'chunk-1.wav',
            startedAt: start,
            endedAt: start.add(const Duration(seconds: 2)),
            peakAmplitude: 0.1,
          ),
        ],
      );
      await data.save();
      expect(compressSleepWav((wav.path, flac.path)), isTrue);
      final previousFlac = await flac.readAsBytes();
      final previousModified = await flac.lastModified();
      final session = (await SleepSessionStore.byId('session-test'))!;
      expect(await SleepSessionStore.compress(session), 1);
      final updated = (await SleepSessionStore.byId('session-test'))!;
      final event = updated.data.events.single;
      expect(event.fileName, 'chunk-1.flac');
      expect(event.syncFileName, 'chunk-1.wav');
      expect(await wav.exists(), isTrue);
      expect(await flac.exists(), isTrue);
      expect(await flac.readAsBytes(), previousFlac);
      expect(await flac.lastModified(), previousModified);
      final delegate = SleepSyncDelegate();
      final id = SleepSessionStore.chunkSyncId(updated.id, event.syncFileName);
      final blob = (await delegate.getLocalRecordData(id))!;
      expect(blob['file'], 'chunk-1.flac');
      expect((blob['audio'] as Map)['mimeType'], 'audio/flac');
      final records = await delegate.getLocalSyncRecords();
      expect(
        records.singleWhere((r) => r['id'] == id)['updatedAt'],
        event.audioUpdatedAt,
      );
      await delegate.verifiedRemoteRecords({id: event.audioUpdatedAt!});
      expect(await wav.exists(), isTrue);
      final flacBytes = await flac.readAsBytes();
      await flac.writeAsBytes([0, 1, 2]);
      await delegate.verifiedRemoteRecords({
        updated.id: updated.data.updatedAt,
        id: event.audioUpdatedAt!,
      });
      expect(await wav.exists(), isTrue);
      await flac.writeAsBytes(flacBytes);
      await delegate.verifiedRemoteRecords({
        updated.id: updated.data.updatedAt,
        id: event.audioUpdatedAt!,
      });
      expect(await wav.exists(), isFalse);
      expect(await flac.exists(), isTrue);
    },
  );
}
