import 'package:flutter/material.dart';
import 'dart:typed_data';

class ImagesToPdfPreview extends StatelessWidget {
  final List<Uint8List> images;
  final List<String> names;
  final void Function(int index) onRemove;
  final void Function(int oldIndex, int newIndex) onReorder;

  const ImagesToPdfPreview({
    super.key,
    required this.images,
    required this.names,
    required this.onRemove,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (images.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.collections_bookmark_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'No images added yet',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Drop images here or use "Add More" to begin',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: images.length,
      onReorderItem: onReorder,
      proxyDecorator: (child, index, animation) {
        return Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          child: child,
        );
      },
      itemBuilder: (context, index) {
        return Card(
          key: ValueKey('img_$index'),
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.memory(
                images[index],
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  width: 60,
                  height: 60,
                  color: Colors.grey[300],
                  child: const Icon(Icons.broken_image),
                ),
              ),
            ),
            title: Text(
              names[index],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text('Page ${index + 1}'),
            trailing: IconButton(
              icon: Icon(
                Icons.remove_circle_outlined,
                color: theme.colorScheme.error,
              ),
              tooltip: 'Remove',
              onPressed: () => onRemove(index),
            ),
          ),
        );
      },
    );
  }
}
