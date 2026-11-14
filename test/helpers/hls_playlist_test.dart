import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/helpers/hls_playlist.dart';

void main() {
  final base = Uri.parse(
    'https://video.example/hls/abc/master_dynamic_delta.m3u8?type=live',
  );

  test('lists the variants of a master playlist, best first', () {
    const body = '''
#EXTM3U
#EXT-X-DYNAMICALLY-GENERATED
#EXT-X-STREAM-INF:PROGRAM-ID=1,BANDWIDTH=1200000,RESOLUTION=848x480,CODECS="avc1.64001f,mp4a.40.2",FRAME-RATE=29.980
/a/hls/480/dynamic_delta.m3u8?type=live
#EXT-X-STREAM-INF:PROGRAM-ID=1,BANDWIDTH=16000000,RESOLUTION=3840x2160,CODECS="avc1.640033,mp4a.40.2"
/a/hls/2160/dynamic_delta.m3u8?type=live
#EXT-X-STREAM-INF:BANDWIDTH=2750000,RESOLUTION=1280x720
720/index.m3u8
''';
    final variants = HlsPlaylist.parseVariants(body, base);
    expect(variants.map((v) => v.height), [2160, 720, 480]);
    expect(
      variants.first.uri.toString(),
      'https://video.example/a/hls/2160/dynamic_delta.m3u8?type=live',
    );
    expect(variants.first.bandwidth, 16000000);
    expect(variants.first.width, 3840);
    expect(
      variants[1].uri.toString(),
      'https://video.example/hls/abc/720/index.m3u8',
    );
  });

  test('a media playlist has no variants', () {
    const body = '''
#EXTM3U
#EXT-X-TARGETDURATION:4
#EXTINF:4.0,
segment0.ts
''';
    expect(HlsPlaylist.parseVariants(body, base), isEmpty);
  });
}
