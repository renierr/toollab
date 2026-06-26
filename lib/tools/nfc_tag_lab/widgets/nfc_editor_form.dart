import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context);
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
                l10n.nfcEditorFormTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              // Template Preset Dropdown
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: _templateId,
                decoration: InputDecoration(
                  labelText: l10n.nfcTemplatePreset,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'custom',
                    child: Text(l10n.nfcTemplateCustomRecord),
                  ),
                  DropdownMenuItem(
                    value: 'url-homepage',
                    child: Text(l10n.nfcTemplateUrlHomepage),
                  ),
                  DropdownMenuItem(
                    value: 'text-note',
                    child: Text(l10n.nfcTemplateTextNote),
                  ),
                  DropdownMenuItem(
                    value: 'mime-json',
                    child: Text(l10n.nfcTemplateMimeJson),
                  ),
                  DropdownMenuItem(
                    value: 'mime-vcard',
                    child: Text(l10n.nfcTemplateMimeVcard),
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
                decoration: InputDecoration(
                  labelText: l10n.nfcRecordType,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'url',
                    child: Text(l10n.nfcRecordTypeUri),
                  ),
                  DropdownMenuItem(
                    value: 'text',
                    child: Text(l10n.nfcRecordTypeText),
                  ),
                  DropdownMenuItem(
                    value: 'mime',
                    child: Text(l10n.nfcRecordTypeMime),
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
                  decoration: InputDecoration(
                    labelText: l10n.nfcUriTargetLink,
                    hintText: 'https://example.com',
                    border: const OutlineInputBorder(),
                    helperText: l10n.nfcUriHelperText,
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return l10n.nfcUriRequired;
                    }
                    return null;
                  },
                ),
              ] else if (_recordType == 'text') ...[
                TextFormField(
                  controller: _payloadController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: l10n.nfcTextContent,
                    hintText: l10n.nfcTextContentHint,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return l10n.nfcTextContentRequired;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _langController,
                  decoration: InputDecoration(
                    labelText: l10n.nfcLanguageCode,
                    hintText: 'en',
                    border: const OutlineInputBorder(),
                    helperText: l10n.nfcLanguageCodeHelper,
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return l10n.nfcLanguageCodeRequired;
                    }
                    return null;
                  },
                ),
              ] else if (_recordType == 'mime') ...[
                TextFormField(
                  controller: _mimeController,
                  decoration: InputDecoration(
                    labelText: l10n.nfcMimeType,
                    hintText: 'application/json',
                    border: const OutlineInputBorder(),
                    helperText: l10n.nfcMimeTypeHelper,
                  ),
                  validator: (val) {
                    final str = val ?? '';
                    if (str.isEmpty || !str.contains('/')) {
                      return l10n.nfcMimeTypeRequired;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _payloadController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: l10n.nfcMimePayloadData,
                    hintText: l10n.nfcMimePayloadHint,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return l10n.nfcPayloadRequired;
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
                      label: Text(l10n.nfcGetHex),
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
                      label: Text(l10n.nfcWriteTag),
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
                    l10n.nfcWriteTagHint,
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
