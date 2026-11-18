import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:cryptography/cryptography.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';
import 'package:tool_lab/helpers/debug_log.dart';

const _channel = MethodChannel('de.renier.tool_lab/pbkdf2');
const _bits = 256;

/// PBKDF2-HMAC-SHA256, 256 bits, through the platform's native crypto. Pure
/// Dart takes seconds at vault iteration counts, so it is only the fallback.
Future<SecretKey> derivePbkdf2Key({
  required int iterations,
  required String password,
  required List<int> salt,
}) async {
  if (Platform.isAndroid) {
    try {
      final bytes = await _channel.invokeMethod<Uint8List>('deriveSha256', {
        'password': password,
        'salt': Uint8List.fromList(salt),
        'iterations': iterations,
        'bits': _bits,
      });
      if (bytes != null) return SecretKey(bytes);
    } on MissingPluginException {
      // Background engines have no app channels.
    } on PlatformException catch (e) {
      errorLog('Pbkdf2: native derivation failed: ${e.message}');
    }
  }
  final saltBytes = Uint8List.fromList(salt);
  final bytes = await Isolate.run(
    () async =>
        _deriveDesktop(iterations, password, saltBytes) ??
        await _deriveDart(iterations, password, saltBytes),
  );
  return SecretKey(bytes);
}

Future<List<int>> _deriveDart(
  int iterations,
  String password,
  Uint8List salt,
) async {
  final key = await Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: iterations,
    bits: _bits,
  ).deriveKeyFromPassword(password: password, nonce: salt);
  return key.extractBytes();
}

Uint8List? _deriveDesktop(int iterations, String password, Uint8List salt) {
  try {
    if (Platform.isLinux) return _deriveOpenSsl(iterations, password, salt);
    if (Platform.isWindows) return _deriveBcrypt(iterations, password, salt);
  } on Object catch (e) {
    errorLog('Pbkdf2: native derivation unavailable: $e');
  }
  return null;
}

typedef _EvpSha256 = Pointer<Void> Function();
typedef _OpenSslPbkdf2Native =
    Int32 Function(
      Pointer<Uint8>,
      Int32,
      Pointer<Uint8>,
      Int32,
      Int32,
      Pointer<Void>,
      Int32,
      Pointer<Uint8>,
    );
typedef _OpenSslPbkdf2 =
    int Function(
      Pointer<Uint8>,
      int,
      Pointer<Uint8>,
      int,
      int,
      Pointer<Void>,
      int,
      Pointer<Uint8>,
    );

Uint8List? _deriveOpenSsl(int iterations, String password, Uint8List salt) {
  DynamicLibrary? lib;
  for (final name in const ['libcrypto.so.3', 'libcrypto.so']) {
    try {
      lib = DynamicLibrary.open(name);
      break;
    } on ArgumentError {
      continue;
    }
  }
  if (lib == null) return null;
  final sha256 = lib.lookupFunction<Pointer<Void> Function(), _EvpSha256>(
    'EVP_sha256',
  );
  final pbkdf2 = lib.lookupFunction<_OpenSslPbkdf2Native, _OpenSslPbkdf2>(
    'PKCS5_PBKDF2_HMAC',
  );
  return _withBuffers(password, salt, (pass, passLen, saltPtr, out) {
    final ok = pbkdf2(
      pass,
      passLen,
      saltPtr,
      salt.length,
      iterations,
      sha256(),
      _bits ~/ 8,
      out,
    );
    return ok == 1;
  });
}

typedef _BcryptOpenNative =
    Int32 Function(
      Pointer<Pointer<Void>>,
      Pointer<Utf16>,
      Pointer<Utf16>,
      Uint32,
    );
typedef _BcryptOpen =
    int Function(Pointer<Pointer<Void>>, Pointer<Utf16>, Pointer<Utf16>, int);
typedef _BcryptPbkdf2Native =
    Int32 Function(
      Pointer<Void>,
      Pointer<Uint8>,
      Uint32,
      Pointer<Uint8>,
      Uint32,
      Uint64,
      Pointer<Uint8>,
      Uint32,
      Uint32,
    );
typedef _BcryptPbkdf2 =
    int Function(
      Pointer<Void>,
      Pointer<Uint8>,
      int,
      Pointer<Uint8>,
      int,
      int,
      Pointer<Uint8>,
      int,
      int,
    );
typedef _BcryptCloseNative = Int32 Function(Pointer<Void>, Uint32);
typedef _BcryptClose = int Function(Pointer<Void>, int);

const _bcryptAlgHandleHmacFlag = 0x8;

Uint8List? _deriveBcrypt(int iterations, String password, Uint8List salt) {
  final lib = DynamicLibrary.open('bcrypt.dll');
  final open = lib.lookupFunction<_BcryptOpenNative, _BcryptOpen>(
    'BCryptOpenAlgorithmProvider',
  );
  final derive = lib.lookupFunction<_BcryptPbkdf2Native, _BcryptPbkdf2>(
    'BCryptDeriveKeyPBKDF2',
  );
  final close = lib.lookupFunction<_BcryptCloseNative, _BcryptClose>(
    'BCryptCloseAlgorithmProvider',
  );
  final handle = calloc<Pointer<Void>>();
  final algId = 'SHA256'.toNativeUtf16();
  try {
    if (open(handle, algId, nullptr, _bcryptAlgHandleHmacFlag) != 0) {
      return null;
    }
    try {
      return _withBuffers(password, salt, (pass, passLen, saltPtr, out) {
        final status = derive(
          handle.value,
          pass,
          passLen,
          saltPtr,
          salt.length,
          iterations,
          out,
          _bits ~/ 8,
          0,
        );
        return status == 0;
      });
    } finally {
      close(handle.value, 0);
    }
  } finally {
    calloc
      ..free(algId)
      ..free(handle);
  }
}

Uint8List? _withBuffers(
  String password,
  Uint8List salt,
  bool Function(
    Pointer<Uint8> pass,
    int passLen,
    Pointer<Uint8> salt,
    Pointer<Uint8> out,
  )
  run,
) {
  final passBytes = utf8.encode(password);
  final pass = calloc<Uint8>(passBytes.length + 1);
  final saltPtr = calloc<Uint8>(salt.length + 1);
  final out = calloc<Uint8>(_bits ~/ 8);
  try {
    pass.asTypedList(passBytes.length).setAll(0, passBytes);
    saltPtr.asTypedList(salt.length).setAll(0, salt);
    if (!run(pass, passBytes.length, saltPtr, out)) return null;
    return Uint8List.fromList(out.asTypedList(_bits ~/ 8));
  } finally {
    pass.asTypedList(passBytes.length).fillRange(0, passBytes.length, 0);
    calloc
      ..free(pass)
      ..free(saltPtr)
      ..free(out);
  }
}
