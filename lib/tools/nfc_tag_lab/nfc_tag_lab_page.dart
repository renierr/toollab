import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/ndef_record.dart';
import 'package:nfc_manager/nfc_manager_android.dart';

import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/tool_layout.dart';

import 'config.dart';
import 'ndef_codec.dart';
import 'scan_profile.dart';
import 'nfc_scan_status_card.dart';
import 'nfc_record_list.dart';
import 'nfc_editor_form.dart';
import 'nfc_hex_panel.dart';
import 'emv_parser.dart';
import 'tag_tech_data.dart';

class NfcTagLabPage extends StatefulWidget {
  const NfcTagLabPage({super.key});

  @override
  State<NfcTagLabPage> createState() => _NfcTagLabPageState();
}

class _NfcTagLabPageState extends State<NfcTagLabPage> with DisposeCleanup {
  bool _hasNfcSupport = false;
  bool _isScanning = false;
  NfcScanProfile _profile = NfcScanProfile.defaultProfile();

  String _scannedUid = '';
  String _scannedTechs = '';
  String _scannedCapacity = '';
  String _scannedWritable = '';
  bool _isTagWritable = false;

  List<DecodedRecord> _scannedRecords = [];
  TagTechData? _techData;
  NfcTag? _currentTag;

  String _editorRecordType = 'url';
  String _editorUrl = 'https://';
  String _editorPayload = '';
  String _editorLang = 'en';
  String _editorMimeType = 'application/json';

  String _generatedHex = '';

  @override
  void initState() {
    super.initState();
    onDispose(_stopScanning);
    _checkNfcSupport();
  }

  Future<void> _checkNfcSupport() async {
    bool hasSupport = false;
    try {
      final availability = await NfcManager.instance.checkAvailability();
      hasSupport =
          availability == NfcAvailability.enabled ||
          availability == NfcAvailability.disabled;
    } catch (e) {
      debugPrint('[NfcTagLab] NFC check failed: $e');
      hasSupport = false;
    }
    if (mounted) {
      setState(() {
        _hasNfcSupport = hasSupport;
      });
    }
  }

  void _startScanning() async {
    if (!_hasNfcSupport) return;
    setState(() {
      _isScanning = true;
      _scannedUid = '';
      _scannedTechs = '';
      _scannedCapacity = '';
      _scannedWritable = '';
      _isTagWritable = false;
      _scannedRecords = [];
      _techData = null;
      _currentTag = null;
      _profile = NfcScanProfile.defaultProfile();
    });

    try {
      await NfcManager.instance.startSession(
        pollingOptions: const {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
          NfcPollingOption.iso18092,
        },
        onSessionErrorIos: (error) {
          debugPrint('[NfcTagLab] iOS Session Error: ${error.message}');
          if (mounted) {
            setState(() {
              _isScanning = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  AppLocalizations.of(context).nfcSessionError(error.message),
                ),
              ),
            );
          }
        },
        onDiscovered: (NfcTag tag) async {
          try {
            final l10n = AppLocalizations.of(context);
            String uid = '';
            List<String> techs = [];
            String capacity = l10n.commonLoading;
            bool tagWritable = false;

            final androidTag = NfcTagAndroid.from(tag);
            if (androidTag != null) {
              uid = NdefCodec.toHex(androidTag.id);
              techs = List<String>.from(androidTag.techList);
            }

            EmvCardDetails? emvDetails;
            final isoDep = IsoDepAndroid.from(tag);
            if (isoDep != null) {
              if (!techs.contains('IsoDep')) techs.add('IsoDep');
              emvDetails = await EmvParser.readCard(isoDep);
            }

            final ndef = Ndef.from(tag);
            if (ndef != null) {
              if (!techs.contains('Ndef')) techs.add('Ndef');
              capacity = '${ndef.maxSize} bytes';
              tagWritable = ndef.isWritable;
            }

            List<DecodedRecord> decodedRecords = [];
            if (ndef != null) {
              final cachedMsg = ndef.cachedMessage;
              if (cachedMsg != null) {
                for (int i = 0; i < cachedMsg.records.length; i++) {
                  final r = cachedMsg.records[i];
                  final decoded = NdefCodec.decodeRawRecord(
                    r.typeNameFormat.index,
                    r.type,
                    r.payload,
                    i,
                  );
                  decodedRecords.add(decoded);
                }
              }
            }

            final tagTechData = TagTechData.extract(
              tag,
              ndef: ndef,
              recordCount: decodedRecords.length,
            );

            final profile = ScanProfileClassifier.classify(
              ScanContext(
                source: (ndef != null || emvDetails != null)
                    ? 'reading'
                    : 'reading-error',
                serialNumber: uid,
                records: decodedRecords,
                emvDetails: emvDetails,
                techList: tagTechData.techList,
                nfcASak: tagTechData.nfcA?.sak,
                isoDepHistoricalBytes: tagTechData.isoDep?.historicalBytesHex,
              ),
            );

            if (mounted) {
              setState(() {
                _scannedUid = uid;
                _scannedTechs = techs.join(', ');
                _scannedCapacity = capacity;
                _scannedWritable = tagWritable ? l10n.commonYes : l10n.commonNo;
                _isTagWritable = tagWritable;
                _scannedRecords = decodedRecords;
                _techData = tagTechData;
                _profile = profile;
                _currentTag = tag;
                _isScanning = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    AppLocalizations.of(
                      context,
                    ).nfcTagDetected(profile.categoryLabel),
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          } catch (e) {
            debugPrint('[NfcTagLab] Scan error: $e');
            if (mounted) {
              setState(() => _isScanning = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    AppLocalizations.of(context).nfcScanFailed(e.toString()),
                  ),
                ),
              );
            }
          } finally {
            try {
              await NfcManager.instance.stopSession();
            } catch (_) {}
          }
        },
      );
    } catch (e) {
      debugPrint('[NfcTagLab] Start session error: $e');
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  void _stopScanning() async {
    if (!_hasNfcSupport) return;
    try {
      await NfcManager.instance.stopSession();
    } catch (e) {
      debugPrint('[NfcTagLab] Stop session error: $e');
    }
    if (mounted) {
      setState(() {
        _isScanning = false;
      });
    }
  }

  void _writeTag(
    String type,
    String url,
    String payload,
    String lang,
    String mime,
  ) async {
    if (_currentTag == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).nfcNoActiveTag)),
      );
      return;
    }

    final ndef = Ndef.from(_currentTag!);
    if (ndef == null || !ndef.isWritable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).nfcTagNotWritable)),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).nfcWritingToTag),
        duration: const Duration(seconds: 1),
      ),
    );

    try {
      NdefRecord record;
      if (type == 'url') {
        record = NdefRecord(
          typeNameFormat: TypeNameFormat.wellKnown,
          type: Uint8List.fromList(utf8.encode('U')),
          identifier: Uint8List(0),
          payload: NdefCodec.encodeUriPayload(url),
        );
      } else if (type == 'text') {
        record = NdefRecord(
          typeNameFormat: TypeNameFormat.wellKnown,
          type: Uint8List.fromList(utf8.encode('T')),
          identifier: Uint8List(0),
          payload: NdefCodec.encodeTextPayload(payload, lang),
        );
      } else if (type == 'mime') {
        record = NdefRecord(
          typeNameFormat: TypeNameFormat.media,
          type: Uint8List.fromList(utf8.encode(mime.trim().toLowerCase())),
          identifier: Uint8List(0),
          payload: Uint8List.fromList(utf8.encode(payload)),
        );
      } else {
        throw Exception('Unsupported record type');
      }

      final message = NdefMessage(records: [record]);
      await ndef.write(message: message);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).nfcWriteSuccess)),
        );
      }

      final updatedDrecords = [
        NdefCodec.decodeRawRecord(
          record.typeNameFormat.index,
          record.type,
          record.payload,
          0,
        ),
      ];
      setState(() {
        _scannedRecords = updatedDrecords;
        _profile = ScanProfileClassifier.classify(
          ScanContext(
            source: 'reading',
            serialNumber: _scannedUid,
            records: updatedDrecords,
          ),
        );
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).nfcWriteFailed(e.toString()),
            ),
          ),
        );
      }
    }
  }

  void _generateHex(
    String type,
    String url,
    String payload,
    String lang,
    String mime,
  ) {
    try {
      final hex = NdefCodec.encodeSingleRecordNdefHex(
        recordType: type,
        payload: type == 'url' ? url : payload,
        lang: lang,
        mimeType: mime,
      );
      setState(() {
        _generatedHex = hex;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).nfcHexGenerated),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).nfcHexGenerateError(e.toString()),
          ),
        ),
      );
    }
  }

  void _parseHex(String hex) {
    final l10n = AppLocalizations.of(context);
    try {
      final records = NdefCodec.parseNdefMessageHex(hex);
      final profile = ScanProfileClassifier.classify(
        ScanContext(source: 'hex-parser', serialNumber: '', records: records),
      );
      setState(() {
        _scannedRecords = records;
        _profile = profile;
        _scannedUid = '';
        _scannedTechs = l10n.nfcHexEmulator;
        _scannedCapacity = l10n.nfcRecordsParsed(records.length);
        _scannedWritable = l10n.commonNo;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.nfcHexParsed),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.nfcHexParseFailed(e.toString()))),
      );
    }
  }

  void _loadRecordIntoEditor(DecodedRecord record) {
    setState(() {
      _editorRecordType = record.recordType;
      if (record.recordType == 'url') {
        _editorUrl = record.value;
      } else if (record.recordType == 'mime') {
        _editorMimeType = record.mediaType;
        _editorPayload = record.value;
      } else {
        _editorPayload = record.value;
        _editorLang = record.lang.isNotEmpty ? record.lang : 'en';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return ToolLayout(
      title: NfcTagLabTool.config.localizedName(l10n),
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          if (!_hasNfcSupport) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.primary.withAlpha(60),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.nfcNoHardwareInfo,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(180),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          NfcScanStatusCard(
            isScanning: _isScanning,
            hasNfcSupport: _hasNfcSupport,
            profile: _profile,
            tagUid: _scannedUid,
            tagTechs: _scannedTechs,
            tagCapacity: _scannedCapacity,
            tagWritable: _scannedWritable,
            techData: _techData,
            onStartScan: _startScanning,
            onStopScan: _stopScanning,
          ),
          const SizedBox(height: 12),
          NfcRecordList(
            records: _scannedRecords,
            onLoadIntoEditor: _loadRecordIntoEditor,
          ),
          const SizedBox(height: 12),
          NfcEditorForm(
            isWriteEnabled: _currentTag != null && _isTagWritable,
            initialRecordType: _editorRecordType,
            initialUrl: _editorUrl,
            initialPayload: _editorPayload,
            initialLang: _editorLang,
            initialMimeType: _editorMimeType,
            onWrite: _writeTag,
            onGenerateHex: _generateHex,
          ),
          const SizedBox(height: 12),
          NfcHexPanel(generatedHex: _generatedHex, onParseHex: _parseHex),
        ],
      ),
    );
  }
}
