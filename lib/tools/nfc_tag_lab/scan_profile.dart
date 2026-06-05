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

  ScanContext({
    required this.source,
    required this.serialNumber,
    required this.records,
    this.emvDetails,
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
