import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';

Future<void> waitUntil(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 15));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('Video playback did not reach the expected state');
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Linux mpv streams and decodes video', () async {
    MediaKit.ensureInitialized();
    final video = await File('test/fixtures/video/sample.mp4').readAsBytes();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var requests = 0;
    final serverSubscription = server.listen((request) async {
      requests++;
      if (request.uri.path != '/sample.mp4') {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }
      request.response.headers.contentType = ContentType('video', 'mp4');
      request.response.contentLength = video.length;
      request.response.add(video);
      await request.response.close();
    });
    final player = Player();
    final native = player.platform as NativePlayer;
    final errors = <String>[];
    final errorSubscription = player.stream.error.listen(errors.add);

    try {
      await native.setProperty('vid', 'auto');
      await native.setProperty('ao', 'null');
      await player.open(Media('http://127.0.0.1:${server.port}/sample.mp4'));
      await waitUntil(
        () =>
            player.state.width == 64 &&
            player.state.position.inMilliseconds > 200,
      );
      expect(requests, greaterThan(0));
      expect(player.state.height, 64);
      expect(player.state.duration.inSeconds, greaterThanOrEqualTo(2));
      expect(player.state.tracks.audio.length, greaterThan(1));

      await player.pause();
      await waitUntil(() => !player.state.playing);
      await player.seek(const Duration(seconds: 1));
      await waitUntil(() => player.state.position.inMilliseconds >= 900);
      await player.play();
      await waitUntil(() => player.state.completed);
      expect(errors, isEmpty);

      await player.setPlaylistMode(PlaylistMode.single);
      await player.open(Media('http://127.0.0.1:${server.port}/sample.mp4'));
      await waitUntil(() => player.state.position.inMilliseconds > 2200);
      await waitUntil(() => player.state.position.inMilliseconds < 1000);
      expect(player.state.playing, isTrue);
      expect(errors, isEmpty);

      await player.setPlaylistMode(PlaylistMode.none);
      await player.open(Media('http://127.0.0.1:${server.port}/missing.mp4'));
      await waitUntil(() => errors.isNotEmpty);
    } finally {
      await errorSubscription.cancel();
      await player.dispose();
      await serverSubscription.cancel();
      await server.close(force: true);
    }
  }, skip: !Platform.isLinux);
}
