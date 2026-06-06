import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

class PdfDrawer extends StatelessWidget {
  final List<PdfOutlineNode>? outline;
  final bool isLoadingOutline;
  final PdfViewerController controller;

  const PdfDrawer({
    super.key,
    required this.outline,
    required this.isLoadingOutline,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Drawer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  Icons.menu_book,
                  color: theme.colorScheme.primary,
                  size: 36,
                ),
                const SizedBox(height: 12),
                Text(
                  'Bookmarks',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: isLoadingOutline
                ? const Center(child: CircularProgressIndicator())
                : outline == null || outline!.isEmpty
                ? const Center(child: Text('No bookmarks available'))
                : ListView.builder(
                    itemCount: outline!.length,
                    itemBuilder: (context, index) {
                      return PdfOutlineTile(
                        node: outline![index],
                        controller: controller,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class PdfOutlineTile extends StatelessWidget {
  final PdfOutlineNode node;
  final PdfViewerController controller;
  final int depth;

  const PdfOutlineTile({
    super.key,
    required this.node,
    required this.controller,
    this.depth = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasChildren = node.children.isNotEmpty;

    if (hasChildren) {
      return ExpansionTile(
        title: Padding(
          padding: EdgeInsets.only(left: depth * 8.0),
          child: Text(
            node.title,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        children: node.children
            .map(
              (child) => PdfOutlineTile(
                node: child,
                controller: controller,
                depth: depth + 1,
              ),
            )
            .toList(),
      );
    }

    return ListTile(
      contentPadding: EdgeInsets.only(left: 16.0 + (depth * 8.0), right: 16.0),
      title: Text(node.title, style: theme.textTheme.bodyMedium),
      onTap: () {
        if (node.dest != null) {
          controller.goToDest(node.dest);
          Navigator.of(context).pop();
        }
      },
    );
  }
}
