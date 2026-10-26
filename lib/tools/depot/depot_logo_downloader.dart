import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:http/http.dart' as http;
import 'package:tool_lab/services/app_http_client.dart';

class DepotLogoDownloader {
  final http.Client? client;

  const DepotLogoDownloader({this.client});

  static const maxBytes = 64 * 1024;
  static const _timeout = Duration(seconds: 20);

  static Uri imageUri(String url) {
    final uri = Uri.parse(url);
    if (uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      throw const FormatException('Logo URL must be HTTPS');
    }
    // Parqet defaults to SVG; ask for a small raster image for offline use.
    return uri.host == 'image.parqet.com'
        ? uri.replace(
            queryParameters: {
              ...uri.queryParameters,
              'format': 'png',
              'size': '96',
            },
          )
        : uri;
  }

  Future<Uint8List> download(String url) async {
    final httpClient = client ?? await AppHttpClient.client;
    final request = http.Request('GET', imageUri(url))
      ..headers['Accept'] = 'image/png,image/webp,image/jpeg'
      ..headers['User-Agent'] = 'ToolLab';
    final response = await httpClient.send(request).timeout(_timeout);
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response.stream.timeout(_timeout)) {
      if (response.statusCode != 200 ||
          (response.contentLength ?? 0) > maxBytes ||
          bytes.length + chunk.length > maxBytes) {
        throw const FormatException(
          'Logo response failed or exceeded size limit',
        );
      }
      bytes.add(chunk);
    }
    if (response.statusCode != 200 || bytes.isEmpty) {
      throw const FormatException('Empty or unsuccessful logo response');
    }
    final data = bytes.takeBytes();
    final buffer = await ui.ImmutableBuffer.fromUint8List(data);
    ui.ImageDescriptor? descriptor;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      if (descriptor.width > 512 || descriptor.height > 512) {
        throw const FormatException('Logo dimensions exceed size limit');
      }
      final codec = await descriptor.instantiateCodec();
      try {
        final frame = await codec.getNextFrame();
        frame.image.dispose();
      } finally {
        codec.dispose();
      }
    } finally {
      descriptor?.dispose();
      buffer.dispose();
    }
    return data;
  }
}
