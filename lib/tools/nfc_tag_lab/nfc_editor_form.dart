import 'package:flutter/material.dart';

class NfcEditorForm extends StatefulWidget {
  final bool isWriteEnabled;
  final String? initialRecordType;
  final String? initialUrl;
  final String? initialPayload;
  final String? initialLang;
  final String? initialMimeType;
  final Function(
    String type,
    String url,
    String payload,
    String lang,
    String mime,
  )
  onWrite;
  final Function(
    String type,
    String url,
    String payload,
    String lang,
    String mime,
  )
  onGenerateHex;

  const NfcEditorForm({
    super.key,
    required this.isWriteEnabled,
    this.initialRecordType,
    this.initialUrl,
    this.initialPayload,
    this.initialLang,
    this.initialMimeType,
    required this.onWrite,
    required this.onGenerateHex,
  });

  @override
  State<NfcEditorForm> createState() => _NfcEditorFormState();
}

class _NfcEditorFormState extends State<NfcEditorForm> {
  final _formKey = GlobalKey<FormState>();

  late String _recordType;
  late TextEditingController _urlController;
  late TextEditingController _payloadController;
  late TextEditingController _langController;
  late TextEditingController _mimeController;

  String _templateId = 'custom';

  @override
  void initState() {
    super.initState();
    _recordType = widget.initialRecordType ?? 'url';
    _urlController = TextEditingController(
      text: widget.initialUrl ?? 'https://',
    );
    _payloadController = TextEditingController(
      text: widget.initialPayload ?? '',
    );
    _langController = TextEditingController(text: widget.initialLang ?? 'en');
    _mimeController = TextEditingController(
      text: widget.initialMimeType ?? 'application/json',
    );
  }

  @override
  void didUpdateWidget(covariant NfcEditorForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialRecordType != null &&
        widget.initialRecordType != oldWidget.initialRecordType) {
      _recordType = widget.initialRecordType!;
    }
    if (widget.initialUrl != null &&
        widget.initialUrl != oldWidget.initialUrl) {
      _urlController.text = widget.initialUrl!;
    }
    if (widget.initialPayload != null &&
        widget.initialPayload != oldWidget.initialPayload) {
      _payloadController.text = widget.initialPayload!;
    }
    if (widget.initialLang != null &&
        widget.initialLang != oldWidget.initialLang) {
      _langController.text = widget.initialLang!;
    }
    if (widget.initialMimeType != null &&
        widget.initialMimeType != oldWidget.initialMimeType) {
      _mimeController.text = widget.initialMimeType!;
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _payloadController.dispose();
    _langController.dispose();
    _mimeController.dispose();
    super.dispose();
  }

  void _applyTemplate(String templateId) {
    setState(() {
      _templateId = templateId;
      if (templateId == 'url-homepage') {
        _recordType = 'url';
        _urlController.text = 'https://example.com';
      } else if (templateId == 'text-note') {
        _recordType = 'text';
        _payloadController.text = 'Hello from NFC Tag Lab';
        _langController.text = 'en';
      } else if (templateId == 'mime-json') {
        _recordType = 'mime';
        _mimeController.text = 'application/json';
        _payloadController.text =
            '{\n  "name": "NFC Tag Lab",\n  "version": 1\n}';
      } else if (templateId == 'mime-vcard') {
        _recordType = 'mime';
        _mimeController.text = 'text/vcard';
        _payloadController.text =
            'BEGIN:VCARD\nVERSION:3.0\nFN:Jane Doe\nTEL:+123456789\nEND:VCARD';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NDEF Record Creator',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              // Template Preset Dropdown
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: _templateId,
                decoration: const InputDecoration(
                  labelText: 'Template Preset',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'custom',
                    child: Text('Custom Record'),
                  ),
                  DropdownMenuItem(
                    value: 'url-homepage',
                    child: Text('URL: Homepage Link'),
                  ),
                  DropdownMenuItem(
                    value: 'text-note',
                    child: Text('Text: Plain Note'),
                  ),
                  DropdownMenuItem(
                    value: 'mime-json',
                    child: Text('MIME: JSON Config'),
                  ),
                  DropdownMenuItem(
                    value: 'mime-vcard',
                    child: Text('MIME: vCard Contact'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) _applyTemplate(val);
                },
              ),
              const SizedBox(height: 12),
              // Record Type Selection Segment
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: _recordType,
                decoration: const InputDecoration(
                  labelText: 'Record Type (NDEF Format)',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'url',
                    child: Text('Well-known URI (URL)'),
                  ),
                  DropdownMenuItem(
                    value: 'text',
                    child: Text('Well-known Text'),
                  ),
                  DropdownMenuItem(
                    value: 'mime',
                    child: Text('MIME Media Payload'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _recordType = val;
                      _templateId = 'custom';
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              // Dynamic Fields
              if (_recordType == 'url') ...[
                TextFormField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    labelText: 'URI Target Link',
                    hintText: 'https://example.com',
                    border: OutlineInputBorder(),
                    helperText:
                        'Auto-detects common prefixes (https://, http://, mailto:, file://) to save tag space.',
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'URI target link is required';
                    }
                    return null;
                  },
                ),
              ] else if (_recordType == 'text') ...[
                TextFormField(
                  controller: _payloadController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Text Content',
                    hintText: 'Enter note content...',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Text content is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _langController,
                  decoration: const InputDecoration(
                    labelText: 'Language Code',
                    hintText: 'en',
                    border: OutlineInputBorder(),
                    helperText:
                        'Standard BCP 47 language identifier (e.g. en, fr, de, es).',
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Language code is required';
                    }
                    return null;
                  },
                ),
              ] else if (_recordType == 'mime') ...[
                TextFormField(
                  controller: _mimeController,
                  decoration: const InputDecoration(
                    labelText: 'MIME Type',
                    hintText: 'application/json',
                    border: OutlineInputBorder(),
                    helperText:
                        'Official media type (e.g. application/json, text/vcard, image/png).',
                  ),
                  validator: (val) {
                    final str = val ?? '';
                    if (str.isEmpty || !str.contains('/')) {
                      return 'A valid MIME type (e.g., type/subtype) is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _payloadController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'MIME Payload Data',
                    hintText: 'Enter JSON, vCard, or custom raw contents...',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Payload data is required';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 18),
              // Action Buttons Row
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        if (_formKey.currentState?.validate() ?? false) {
                          widget.onGenerateHex(
                            _recordType,
                            _urlController.text,
                            _payloadController.text,
                            _langController.text,
                            _mimeController.text,
                          );
                        }
                      },
                      icon: const Icon(Icons.code, size: 18),
                      label: const Text('Get Hex'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: widget.isWriteEnabled
                          ? () {
                              if (_formKey.currentState?.validate() ?? false) {
                                widget.onWrite(
                                  _recordType,
                                  _urlController.text,
                                  _payloadController.text,
                                  _langController.text,
                                  _mimeController.text,
                                );
                              }
                            }
                          : null,
                      icon: const Icon(Icons.edit_calendar, size: 18),
                      label: const Text('Write Tag'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              if (!widget.isWriteEnabled) ...[
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Write Tag active only when scanning a writable tag.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(100),
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
