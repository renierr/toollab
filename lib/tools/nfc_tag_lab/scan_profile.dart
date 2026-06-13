import 'ndef_codec.dart';
import 'emv_parser.dart';

enum NfcCategoryId {
  ndefData,
  paymentCard,
  passport,
  idCard,
  secureCard,
  unknown,
}

class NfcScanProfile {
  final NfcCategoryId categoryId;
  final String categoryLabel;
  final String technology;
  final String confidence;
  final bool supportsNdefRead;
  final bool allowsEditor;
  final bool allowsWrite;
  final String reason;
  final String matchedRule;

  // Extended fields for card/credential info
  final String? cardNumber;
  final String? cardExpiry;
  final String? cardHolder;
  final String? cardBrand;
  final String? cardAid;
  final bool isEmv;

  NfcScanProfile({
    required this.categoryId,
    required this.categoryLabel,
    required this.technology,
    required this.confidence,
    required this.supportsNdefRead,
    required this.allowsEditor,
    required this.allowsWrite,
    required this.reason,
    required this.matchedRule,
    this.cardNumber,
    this.cardExpiry,
    this.cardHolder,
    this.cardBrand,
    this.cardAid,
    this.isEmv = false,
  });

  factory NfcScanProfile.defaultProfile() {
    return NfcScanProfile(
      categoryId: NfcCategoryId.unknown,
      categoryLabel: 'No scan yet',
      technology: '-',
      confidence: 'low',
      supportsNdefRead: false,
      allowsEditor: true,
      allowsWrite: true,
      reason: 'Scan an NFC target to classify it and show supported actions.',
      matchedRule: 'none',
      isEmv: false,
    );
  }
}

class ScanContext {
  final String source; // 'reading' | 'reading-error' | 'hex-parser'
  final String serialNumber;
  final List<DecodedRecord> records;
  final EmvCardDetails? emvDetails;
  final List<String> techList;
  final int? nfcASak;
  final String? isoDepHistoricalBytes;

  ScanContext({
    required this.source,
    required this.serialNumber,
    required this.records,
    this.emvDetails,
    this.techList = const [],
    this.nfcASak,
    this.isoDepHistoricalBytes,
  });
}

class ScanProfileClassifier {
  static const List<String> paymentSignatures = [
    '2PAY.SYS.DDF01',
    'A000000003',
    'A000000004',
    'A00000025',
    'A000000152',
  ];

  static const List<String> passportSignatures = [
    'A0000002471001',
    'ICAO',
    'LDS',
  ];

  static const List<String> idSignatures = [
    'A000000167455349474E',
    'A000000248',
    'EID',
    'IDENTITY',
  ];

  static NfcScanProfile classify(ScanContext context) {
    if (context.emvDetails != null) {
      final details = context.emvDetails!;
      return NfcScanProfile(
        categoryId: NfcCategoryId.paymentCard,
        categoryLabel: details.brand.isNotEmpty
            ? details.brand
            : 'Payment Card',
        technology: 'ISO-DEP / EMV',
        confidence: 'high',
        supportsNdefRead: false,
        allowsEditor: false,
        allowsWrite: false,
        reason: 'Successfully decoded payment card secure data.',
        matchedRule: 'emv-parsed-card',
        cardNumber: details.number,
        cardExpiry: details.expiry,
        cardHolder: details.holder,
        cardBrand: details.brand,
        cardAid: details.aid,
        isEmv: true,
      );
    }

    if (hasAnySignature(context, paymentSignatures)) {
      return NfcScanProfile(
        categoryId: NfcCategoryId.paymentCard,
        categoryLabel: 'Payment Card',
        technology: 'ISO-DEP / EMV',
        confidence: 'medium',
        supportsNdefRead: false,
        allowsEditor: false,
        allowsWrite: false,
        reason:
            'Detected EMV-like payment card signatures. Editing and writing are disabled.',
        matchedRule: 'payment-card-signature',
      );
    }

    if (hasAnySignature(context, passportSignatures)) {
      return NfcScanProfile(
        categoryId: NfcCategoryId.passport,
        categoryLabel: 'ePassport',
        technology: 'ISO-DEP / ICAO LDS',
        confidence: 'medium',
        supportsNdefRead: false,
        allowsEditor: false,
        allowsWrite: false,
        reason:
            'Detected ICAO passport-like signatures. Editing and writing are disabled.',
        matchedRule: 'passport-signature',
      );
    }

    if (hasAnySignature(context, idSignatures)) {
      return NfcScanProfile(
        categoryId: NfcCategoryId.idCard,
        categoryLabel: 'ID Card',
        technology: 'Secure document applet',
        confidence: 'low',
        supportsNdefRead: false,
        allowsEditor: false,
        allowsWrite: false,
        reason:
            'Detected ID-document-like signatures. Editing and writing are disabled.',
        matchedRule: 'id-card-signature',
      );
    }

    if (context.techList.any((tech) => tech.toLowerCase().contains('isodep'))) {
      final historicalBytes = context.isoDepHistoricalBytes;
      final reason = (historicalBytes != null && historicalBytes.isNotEmpty)
          ? 'ISO-DEP tag detected with historical bytes $historicalBytes. Secure applet access is likely required.'
          : 'ISO-DEP tag detected, but no public NDEF payload was decoded. Secure applet access is likely required.';
      return NfcScanProfile(
        categoryId: NfcCategoryId.secureCard,
        categoryLabel: 'Secure ISO-DEP Card',
        technology: 'ISO-DEP / APDU',
        confidence: 'medium',
        supportsNdefRead: false,
        allowsEditor: false,
        allowsWrite: false,
        reason: reason,
        matchedRule: 'isodep-tech-present',
      );
    }

    if (context.nfcASak != null) {
      final sak = context.nfcASak!;
      final technology = switch (sak) {
        0x00 => 'MIFARE Ultralight',
        0x08 => 'MIFARE Classic 1K',
        0x09 => 'MIFARE Classic Mini',
        0x18 => 'MIFARE Classic 4K',
        0x20 => 'NTAG / MIFARE Ultralight EV1',
        0x50 => 'ISO-DEP capable tag',
        _ =>
          'Nfc-A tag (SAK 0x${sak.toRadixString(16).padLeft(2, '0').toUpperCase()})',
      };
      return NfcScanProfile(
        categoryId: NfcCategoryId.unknown,
        categoryLabel: 'Nfc-A Tag',
        technology: technology,
        confidence: 'medium',
        supportsNdefRead: false,
        allowsEditor: false,
        allowsWrite: false,
        reason:
            'Classified using Nfc-A SAK byte. No public NDEF records were decoded.',
        matchedRule: 'nfca-sak-heuristic',
      );
    }

    if (context.source == 'reading-error') {
      return NfcScanProfile(
        categoryId: NfcCategoryId.secureCard,
        categoryLabel: 'Non-NDEF NFC target',
        technology: 'Secure NFC applet or card emulation',
        confidence: 'low',
        supportsNdefRead: false,
        allowsEditor: false,
        allowsWrite: false,
        reason:
            'This target responded to NFC, but no NDEF payload could be decoded. Editing and writing are disabled.',
        matchedRule: 'non-ndef-reading-error',
      );
    }

    if (context.records.isNotEmpty) {
      return NfcScanProfile(
        categoryId: NfcCategoryId.ndefData,
        categoryLabel: 'NDEF Data',
        technology: 'NDEF-compatible target',
        confidence: 'high',
        supportsNdefRead: true,
        allowsEditor: true,
        allowsWrite: true,
        reason:
            'NDEF records decoded successfully. Editor and writing are available.',
        matchedRule: 'decoded-ndef-records',
      );
    }

    return NfcScanProfile(
      categoryId: NfcCategoryId.unknown,
      categoryLabel: 'Unknown NFC target',
      technology: 'Unidentified technology',
      confidence: 'low',
      supportsNdefRead: false,
      allowsEditor: false,
      allowsWrite: false,
      reason:
          'No signatures or NDEF records were available for reliable classification.',
      matchedRule: 'fallback-unknown',
    );
  }

  static bool hasAnySignature(ScanContext context, List<String> signatures) {
    final haystack = buildScanHaystack(context);
    return signatures.any((sig) => haystack.contains(sig));
  }

  static String buildScanHaystack(ScanContext context) {
    final joinedRecords = context.records
        .map(
          (record) =>
              '${record.recordType}|${record.mediaType}|${record.value}|${record.rawHex}',
        )
        .join('|');

    return '${context.serialNumber}|$joinedRecords'.toUpperCase();
  }
}
