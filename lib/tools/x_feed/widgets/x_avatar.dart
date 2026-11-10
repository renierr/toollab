import 'package:flutter/material.dart';

class XAvatar extends StatelessWidget {
  final String? url;
  final double size;

  const XAvatar({super.key, required this.url, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = Icon(
      Icons.person,
      size: size * 0.6,
      color: scheme.onSurfaceVariant,
    );
    final image = url;
    return ClipOval(
      child: Container(
        width: size,
        height: size,
        color: scheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: image == null
            ? placeholder
            : Image.network(
                image,
                width: size,
                height: size,
                fit: BoxFit.cover,
                cacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
                    .round(),
                errorBuilder: (_, _, _) => placeholder,
              ),
      ),
    );
  }
}
