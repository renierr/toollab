import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:tool_lab/helpers/lan_pairing.dart';

import 'api/x_session.dart';

class XPairingReceiver {
  static const _protocol = PairingProtocol(
    scheme: 'toollab-x-pair',
    path: '/x-pair',
  );

  final PairingReceiver _receiver;

  XPairingReceiver._(this._receiver);

  static Future<XPairingReceiver> start({
    @visibleForTesting InternetAddress? bindAddress,
  }) async => XPairingReceiver._(
    await PairingReceiver.start(
      protocol: _protocol,
      bindAddress: bindAddress,
      validate: (data) =>
          XSession.fromCookies(data.cast<String, String>()) != null,
    ),
  );

  int get port => _receiver.port;
  List<String> get hosts => _receiver.hosts;
  String get payload => _receiver.payload();
  Future<XSession> get session async =>
      XSession.fromCookies((await _receiver.received).cast<String, String>())!;

  Future<void> close() => _receiver.close();

  static Future<bool> send(String payload, XSession session) =>
      PairingSender.send(
        PairingCode.parse(payload, protocol: _protocol),
        session.toJson(),
      );
}
