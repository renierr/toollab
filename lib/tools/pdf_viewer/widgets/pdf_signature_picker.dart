import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:tool_lab/services/signature_library.dart';
import 'package:tool_lab/widgets/checkerboard_background.dart';

/// Horizontal strip of stored signatures to choose from when signing a PDF.
class PdfSignaturePicker extends StatelessWidget {
  final List<SignatureRecord> signatures;
  final String? selectedId;
  final ValueChanged<SignatureRecord> onSelect;

  const PdfSignaturePicker({
    super.key,
    required this.signatures,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (signatures.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No saved signatures. Create one in the Signature Creator first.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return SizedBox(
      height: 84,
      child: ScrollConfiguration(
        // Allow click/trackpad drag to scroll horizontally on desktop, where a
        // narrow window would otherwise hide signatures with no way to reach them.
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
            PointerDeviceKind.stylus,
          },
        ),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: signatures.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final record = signatures[index];
            final selected = record.shortId == selectedId;
            return InkWell(
              onTap: () => onSelect(record),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 110,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline.withValues(alpha: 0.3),
                    width: selected ? 2.5 : 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: CheckerboardBackground(
                  child: record.image == null
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.all(6),
                          child: Image.memory(
                            record.image!,
                            fit: BoxFit.contain,
                          ),
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
