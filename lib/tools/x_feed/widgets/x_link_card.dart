import 'package:flutter/material.dart';

import '../models/x_post.dart';

class XLinkCardView extends StatelessWidget {
  final XLinkCard card;
  final VoidCallback onTap;

  const XLinkCardView({super.key, required this.card, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final image = card.imageUrl;
    final domain = card.domain ?? Uri.tryParse(card.url)?.host ?? '';
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (image != null)
              AspectRatio(
                aspectRatio: 1.91,
                child: Image.network(
                  image,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (domain.isNotEmpty)
                    Text(
                      domain,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  Text(
                    card.title ?? card.url,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
