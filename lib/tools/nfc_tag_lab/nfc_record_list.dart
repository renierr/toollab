import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tool_lab/theme/theme.dart';
import 'ndef_codec.dart';

class NfcRecordList extends StatelessWidget {
  final List<DecodedRecord> records;
  final Function(DecodedRecord)? onLoadIntoEditor;

  const NfcRecordList({
    super.key,
    required this.records,
    this.onLoadIntoEditor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (records.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.layers_clear_outlined,
                  size: 40,
                  color: theme.colorScheme.onSurface.withAlpha(80),
                ),
                const SizedBox(height: 8),
                Text(
                  'No Records Found',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface.withAlpha(140),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'NDEF payload is empty or not scanned yet.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(100),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'NDEF Records (${records.length})',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface.withAlpha(160),
            ),
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: records.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final record = records[index];
            return _RecordItem(
              record: record,
              onLoad: onLoadIntoEditor != null
                  ? () => onLoadIntoEditor!(record)
                  : null,
            );
          },
        ),
      ],
    );
  }
}

class _RecordItem extends StatelessWidget {
  final DecodedRecord record;
  final VoidCallback? onLoad;

  const _RecordItem({required this.record, this.onLoad});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _getRecordTypeColor(record.recordType);

    return Card(
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: accent.withAlpha(20),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: accent.withAlpha(60)),
          ),
          child: Icon(
            _getRecordTypeIcon(record.recordType),
            size: 20,
            color: accent,
          ),
        ),
        title: Text(
          record.value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          _getSubtitle(record),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withAlpha(140),
          ),
        ),
        childrenPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        expandedAlignment: Alignment.topLeft,
        children: [
          Row(
            children: [
              Text(
                'Record Index:',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(120),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '#${record.index}',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (onLoad != null)
                IconButton(
                  tooltip: 'Load into Editor',
                  icon: const Icon(Icons.edit_note_outlined, size: 20),
                  onPressed: () {
                    onLoad!();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Record loaded into Editor Form.'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),
              IconButton(
                tooltip: 'Copy Payload Hex',
                icon: const Icon(Icons.copy_outlined, size: 18),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: record.rawHex));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Payload Hex copied to clipboard.'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Raw Payload (Hex):',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(120),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withAlpha(10),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              record.rawHex,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getSubtitle(DecodedRecord r) {
    if (r.recordType == 'text') {
      return 'Well-known Text [${r.lang.toUpperCase()} | ${r.encoding}]';
    }
    if (r.recordType == 'url') {
      return 'Well-known URI';
    }
    if (r.recordType == 'mime') {
      return 'MIME: ${r.mediaType}';
    }
    return 'Custom / Non-NDEF';
  }

  Color _getRecordTypeColor(String type) {
    return switch (type) {
      'text' => AppTheme.accentTeal,
      'url' => AppTheme.statusBlue,
      'mime' => AppTheme.accentPurple,
      _ => AppTheme.statusOrange,
    };
  }

  IconData _getRecordTypeIcon(String type) {
    return switch (type) {
      'text' => Icons.text_fields,
      'url' => Icons.link,
      'mime' => Icons.description_outlined,
      _ => Icons.widgets_outlined,
    };
  }
}
