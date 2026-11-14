/// One rendition listed in an HLS master playlist.
class HlsVariant {
  final Uri uri;
  final int bandwidth;
  final int? width;
  final int? height;

  const HlsVariant({
    required this.uri,
    required this.bandwidth,
    this.width,
    this.height,
  });
}

class HlsPlaylist {
  HlsPlaylist._();

  static final RegExp _attribute = RegExp(r'([A-Z0-9-]+)=("[^"]*"|[^,]*)');

  /// The variants of a master playlist, best first; empty for a media
  /// playlist, which has no `#EXT-X-STREAM-INF` lines.
  static List<HlsVariant> parseVariants(String body, Uri base) {
    final variants = <HlsVariant>[];
    Map<String, String>? pending;
    for (final raw in body.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('#EXT-X-STREAM-INF:')) {
        pending = {
          for (final m in _attribute.allMatches(
            line.substring('#EXT-X-STREAM-INF:'.length),
          ))
            m.group(1)!: m.group(2)!.replaceAll('"', ''),
        };
        continue;
      }
      if (line.startsWith('#')) continue;
      final attributes = pending;
      pending = null;
      if (attributes == null) continue;
      final size = attributes['RESOLUTION']?.split('x');
      variants.add(
        HlsVariant(
          uri: base.resolve(line),
          bandwidth: int.tryParse(attributes['BANDWIDTH'] ?? '') ?? 0,
          width: size?.length == 2 ? int.tryParse(size![0]) : null,
          height: size?.length == 2 ? int.tryParse(size![1]) : null,
        ),
      );
    }
    variants.sort((a, b) {
      final byHeight = (b.height ?? 0).compareTo(a.height ?? 0);
      return byHeight != 0 ? byHeight : b.bandwidth.compareTo(a.bandwidth);
    });
    return variants;
  }
}
