import 'package:tool_lab/helpers/lan_pairing.dart';
import 'parqet_auth.dart';

/// The QR handoff that logs a TV in with a phone: the TV publishes its public
/// challenge, the phone completes the consent page and returns the redirect.
/// The code is exchanged, and the tokens stored, on the TV itself.
class ParqetPairing {
  ParqetPairing._();

  static const protocol = PairingProtocol(
    scheme: 'toollab-pair',
    path: '/pair',
    kind: 'parqet',
  );

  static Map<String, Object?> fields(ParqetLoginRequest request) => {
    's': request.state,
    'q': request.challenge,
  };

  static ({String state, String challenge}) read(PairingCode code) {
    final state = code.fields['s'];
    final challenge = code.fields['q'];
    if (state is! String ||
        state.isEmpty ||
        challenge is! String ||
        challenge.isEmpty) {
      throw const FormatException('Incomplete Parqet pairing code');
    }
    return (state: state, challenge: challenge);
  }

  static Uri callback(Map<String, dynamic> data) {
    final value = data['u'];
    final uri = value is String ? Uri.tryParse(value) : null;
    if (uri == null) throw const FormatException('No login redirect');
    return uri;
  }

  static Future<({String clientId, ParqetTokens tokens})> complete(
    ParqetLoginRequest request,
    Map<String, dynamic> data,
  ) async {
    final id = data['c'];
    if (id is! String || id.trim().isEmpty) {
      throw const FormatException('No client ID');
    }
    final clientId = id.trim();
    final tokens = await request.complete(callback(data), clientId: clientId);
    return (clientId: clientId, tokens: tokens);
  }

  static Future<bool> send(PairingCode code, Uri callback, String clientId) =>
      PairingSender.send(code, {'u': callback.toString(), 'c': clientId});
}
