import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/core/shared_file.dart';
import 'package:tool_lab/helpers/mime_type_helper.dart';

void main() {
  group('MimeTypeHelper', () {
    test('resolves correct mime types from file paths', () {
      expect(MimeTypeHelper.getMimeType('test.pdf'), 'application/pdf');
      expect(MimeTypeHelper.getMimeType('image.png'), 'image/png');
      expect(MimeTypeHelper.getMimeType('photo.jpg'), 'image/jpeg');
      expect(MimeTypeHelper.getMimeType('photo.jpeg'), 'image/jpeg');
      expect(MimeTypeHelper.getMimeType('animation.gif'), 'image/gif');
      expect(MimeTypeHelper.getMimeType('notes.txt'), 'text/plain');
      expect(MimeTypeHelper.getMimeType('document.md'), 'text/markdown');
      expect(MimeTypeHelper.getMimeType('document.markdown'), 'text/markdown');
      expect(MimeTypeHelper.getMimeType('data.json'), 'application/json');
      expect(
        MimeTypeHelper.getMimeType('database.db'),
        'application/vnd.sqlite3',
      );
      expect(
        MimeTypeHelper.getMimeType('database.sqlite'),
        'application/vnd.sqlite3',
      );
      expect(
        MimeTypeHelper.getMimeType('database.sqlite3'),
        'application/vnd.sqlite3',
      );
      expect(
        MimeTypeHelper.getMimeType('database.db3'),
        'application/vnd.sqlite3',
      );
      expect(MimeTypeHelper.getMimeType('index.html'), 'text/html');
      expect(MimeTypeHelper.getMimeType('styles.css'), 'text/css');
      expect(MimeTypeHelper.getMimeType('image.webp'), 'image/webp');
      expect(MimeTypeHelper.getMimeType('song.mp3'), 'audio/mpeg');
      expect(MimeTypeHelper.getMimeType('tune.mod'), 'audio/x-mod');
      expect(MimeTypeHelper.getMimeType('tune.xm'), 'audio/x-xm');
      expect(MimeTypeHelper.getMimeType('tune.it'), 'audio/x-it');
      expect(MimeTypeHelper.getMimeType('movie.mp4'), 'video/mp4');
      expect(MimeTypeHelper.getMimeType('archive.zip'), 'application/zip');
      expect(
        MimeTypeHelper.getMimeType('report.docx'),
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      );
      expect(
        MimeTypeHelper.getMimeType('unknown.xyz'),
        'application/octet-stream',
      );
      expect(
        MimeTypeHelper.getMimeType('no_extension'),
        'application/octet-stream',
      );
    });
  });

  group('MimeTypeHelper magic bytes', () {
    test('detects signatures regardless of extension', () {
      expect(
        MimeTypeHelper.detectFromMagicBytes([0x25, 0x50, 0x44, 0x46, 0x2D]),
        'application/pdf',
      );
      expect(
        MimeTypeHelper.detectFromMagicBytes('SQLite format 3\x00'.codeUnits),
        'application/vnd.sqlite3',
      );
      expect(
        MimeTypeHelper.detectFromMagicBytes([
          0x89,
          0x50,
          0x4E,
          0x47,
          0x0D,
          0x0A,
          0x1A,
          0x0A,
        ]),
        'image/png',
      );
      expect(
        MimeTypeHelper.detectFromMagicBytes([0xFF, 0xD8, 0xFF, 0xE0]),
        'image/jpeg',
      );
      expect(
        MimeTypeHelper.detectFromMagicBytes('GIF89a'.codeUnits),
        'image/gif',
      );
      expect(
        MimeTypeHelper.detectFromMagicBytes([0x50, 0x4B, 0x03, 0x04]),
        'application/zip',
      );
      expect(
        MimeTypeHelper.detectFromMagicBytes('IMPM'.codeUnits),
        'audio/x-it',
      );
      expect(
        MimeTypeHelper.detectFromMagicBytes('Extended Module: '.codeUnits),
        'audio/x-xm',
      );
      expect(MimeTypeHelper.detectFromMagicBytes([0x00, 0x01]), isNull);
    });

    test('magic bytes win over a wrong extension', () {
      expect(
        MimeTypeHelper.getMimeType(
          'photo.txt',
          bytes: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A],
        ),
        'image/png',
      );
    });

    test('falls back to extension when bytes are unknown', () {
      expect(
        MimeTypeHelper.getMimeType('notes.md', bytes: [0x00, 0x01, 0x02]),
        'text/markdown',
      );
    });
  });

  group('SharedFile Octet-Stream Resolution', () {
    test(
      'resolves mimeType from path if original is application/octet-stream',
      () {
        final file = SharedFile(
          path: '/path/to/my_notes.md',
          name: 'my_notes.md',
          mimeType: 'application/octet-stream',
        );
        expect(file.mimeType, 'text/markdown');
      },
    );

    test(
      'resolves mimeType from name if path is empty and original is application/octet-stream',
      () {
        final file = SharedFile(
          path: '',
          name: 'my_notes.md',
          mimeType: 'application/octet-stream',
        );
        expect(file.mimeType, 'text/markdown');
      },
    );

    test('retains original mimeType if it is not application/octet-stream', () {
      final file = SharedFile(
        path: '/path/to/my_notes.md',
        name: 'my_notes.md',
        mimeType: 'text/plain',
      );
      expect(file.mimeType, 'text/plain');
    });

    test(
      'retains application/octet-stream if file type cannot be determined',
      () {
        final file = SharedFile(
          path: '/path/to/unknown.xyz',
          name: 'unknown.xyz',
          mimeType: 'application/octet-stream',
        );
        expect(file.mimeType, 'application/octet-stream');
      },
    );
  });
}
