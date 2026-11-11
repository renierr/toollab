import 'dart:typed_data';

import 'package:flutter/material.dart';

class PairingQrContent extends StatelessWidget {
  final String hint;
  final Uint8List qr;
  final List<String> hosts;
  final int port;

  const PairingQrContent({
    super.key,
    required this.hint,
    required this.qr,
    required this.hosts,
    required this.port,
  });

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(hint, textAlign: TextAlign.center),
      const SizedBox(height: 16),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280, maxHeight: 280),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(qr, filterQuality: FilterQuality.none),
        ),
      ),
      const SizedBox(height: 12),
      Text(
        hosts.map((host) => '$host:$port').join('  '),
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );
}
