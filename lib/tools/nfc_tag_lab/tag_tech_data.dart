import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';
import 'ndef_codec.dart';

class NfcAData {
  final String atqaHex;
  final int sak;

  NfcAData({required this.atqaHex, required this.sak});

  String get sakByte =>
      '0x${sak.toRadixString(16).padLeft(2, '0').toUpperCase()}';

  String get tagType {
    return switch (sak) {
      0x00 => 'MIFARE Ultralight / Ultralight C',
      0x08 => 'MIFARE Classic 1K',
      0x09 => 'MIFARE Classic Mini (320B)',
      0x18 => 'MIFARE Classic 4K',
      0x20 => 'NTAG / MIFARE Ultralight EV1',
      0x28 => 'MIFARE Plus 2K / 4K',
      0x38 => 'MIFARE Plus SE 1K',
      0x50 => 'ISO/IEC 14443-4 PICC (IsoDep)',
      _ => 'Nfc-A compliant tag',
    };
  }

  static NfcAData? from(NfcAAndroid? nfcA) {
    if (nfcA == null) return null;
    return NfcAData(atqaHex: NdefCodec.toHex(nfcA.atqa), sak: nfcA.sak);
  }
}

class NfcBData {
  final String applicationDataHex;
  final String protocolInfoHex;

  NfcBData({required this.applicationDataHex, required this.protocolInfoHex});

  static NfcBData? from(NfcBAndroid? nfcB) {
    if (nfcB == null) return null;
    return NfcBData(
      applicationDataHex: NdefCodec.toHex(nfcB.applicationData),
      protocolInfoHex: NdefCodec.toHex(nfcB.protocolInfo),
    );
  }
}

class NfcFData {
  final String manufacturerHex;
  final String systemCodeHex;

  NfcFData({required this.manufacturerHex, required this.systemCodeHex});

  static NfcFData? from(NfcFAndroid? nfcF) {
    if (nfcF == null) return null;
    return NfcFData(
      manufacturerHex: NdefCodec.toHex(nfcF.manufacturer),
      systemCodeHex: NdefCodec.toHex(nfcF.systemCode),
    );
  }
}

class NfcVData {
  final int dsfId;
  final int responseFlags;

  NfcVData({required this.dsfId, required this.responseFlags});

  static NfcVData? from(NfcVAndroid? nfcV) {
    if (nfcV == null) return null;
    return NfcVData(dsfId: nfcV.dsfId, responseFlags: nfcV.responseFlags);
  }
}

class IsoDepTechData {
  final String? hiLayerResponseHex;
  final String? historicalBytesHex;
  final bool isExtendedLengthApduSupported;

  IsoDepTechData({
    this.hiLayerResponseHex,
    this.historicalBytesHex,
    required this.isExtendedLengthApduSupported,
  });

  static IsoDepTechData? from(IsoDepAndroid? isoDep) {
    if (isoDep == null) return null;
    return IsoDepTechData(
      hiLayerResponseHex: isoDep.hiLayerResponse != null
          ? NdefCodec.toHex(isoDep.hiLayerResponse!)
          : null,
      historicalBytesHex: isoDep.historicalBytes != null
          ? NdefCodec.toHex(isoDep.historicalBytes!)
          : null,
      isExtendedLengthApduSupported: isoDep.isExtendedLengthApduSupported,
    );
  }
}

class MifareClassicTechData {
  final String type;
  final int blockCount;
  final int sectorCount;
  final int sizeBytes;

  MifareClassicTechData({
    required this.type,
    required this.blockCount,
    required this.sectorCount,
    required this.sizeBytes,
  });

  String get sizeLabel {
    if (sizeBytes >= 1024) {
      return '${(sizeBytes / 1024).round()} KB';
    }
    return '$sizeBytes bytes';
  }

  static MifareClassicTechData? from(MifareClassicAndroid? mc) {
    if (mc == null) return null;
    return MifareClassicTechData(
      type: mc.type.name,
      blockCount: mc.blockCount,
      sectorCount: mc.sectorCount,
      sizeBytes: mc.size,
    );
  }
}

class MifareUltralightTechData {
  final String type;

  MifareUltralightTechData({required this.type});

  static MifareUltralightTechData? from(MifareUltralightAndroid? mu) {
    if (mu == null) return null;
    return MifareUltralightTechData(type: mu.type.name);
  }
}

class NdefFormatableTechData {
  final bool isFormatable;

  NdefFormatableTechData({required this.isFormatable});

  static NdefFormatableTechData? from(NdefFormatableAndroid? nf) {
    if (nf == null) return null;
    return NdefFormatableTechData(isFormatable: true);
  }
}

class NfcBarcodeTechData {
  final String type;
  final String barcodeHex;

  NfcBarcodeTechData({required this.type, required this.barcodeHex});

  static NfcBarcodeTechData? from(NfcBarcodeAndroid? nb) {
    if (nb == null) return null;
    return NfcBarcodeTechData(
      type: nb.type.name,
      barcodeHex: NdefCodec.toHex(nb.barcode),
    );
  }
}

class NdefTechData {
  final int maxSize;
  final bool isWritable;
  final int recordCount;

  NdefTechData({
    required this.maxSize,
    required this.isWritable,
    required this.recordCount,
  });

  String get capacityLabel => '$maxSize bytes';

  static NdefTechData? from(Ndef? ndef, int recordCount) {
    if (ndef == null) return null;
    return NdefTechData(
      maxSize: ndef.maxSize,
      isWritable: ndef.isWritable,
      recordCount: recordCount,
    );
  }
}

class TagTechData {
  final String uid;
  final List<String> techList;
  final NfcAData? nfcA;
  final NfcBData? nfcB;
  final NfcFData? nfcF;
  final NfcVData? nfcV;
  final IsoDepTechData? isoDep;
  final MifareClassicTechData? mifareClassic;
  final MifareUltralightTechData? mifareUltralight;
  final NdefTechData? ndef;
  final NdefFormatableTechData? ndefFormatable;
  final NfcBarcodeTechData? nfcBarcode;

  TagTechData({
    required this.uid,
    required this.techList,
    this.nfcA,
    this.nfcB,
    this.nfcF,
    this.nfcV,
    this.isoDep,
    this.mifareClassic,
    this.mifareUltralight,
    this.ndef,
    this.ndefFormatable,
    this.nfcBarcode,
  });

  String get techListLabel => techList.join(', ');

  List<TechSection> get sections {
    final list = <TechSection>[];
    if (nfcA != null) {
      list.add(
        TechSection(
          title: 'Nfc-A (ISO 14443-3A)',
          items: [
            TechItem('ATQA', nfcA!.atqaHex),
            TechItem('SAK', '${nfcA!.sakByte} - ${nfcA!.tagType}'),
          ],
        ),
      );
    }
    if (nfcB != null) {
      list.add(
        TechSection(
          title: 'Nfc-B (ISO 14443-3B)',
          items: [
            TechItem('Application Data', nfcB!.applicationDataHex),
            TechItem('Protocol Info', nfcB!.protocolInfoHex),
          ],
        ),
      );
    }
    if (nfcF != null) {
      list.add(
        TechSection(
          title: 'Nfc-F (JIS 6319-4 / FeliCa)',
          items: [
            TechItem('Manufacturer', nfcF!.manufacturerHex),
            TechItem('System Code', nfcF!.systemCodeHex),
          ],
        ),
      );
    }
    if (nfcV != null) {
      list.add(
        TechSection(
          title: 'Nfc-V (ISO 15693)',
          items: [
            TechItem(
              'DSF ID',
              '0x${nfcV!.dsfId.toRadixString(16).padLeft(2, '0').toUpperCase()}',
            ),
            TechItem(
              'Response Flags',
              '0x${nfcV!.responseFlags.toRadixString(16).padLeft(2, '0').toUpperCase()}',
            ),
          ],
        ),
      );
    }
    if (isoDep != null) {
      list.add(
        TechSection(
          title: 'ISO-DEP (ISO 14443-4)',
          items: [
            if (isoDep!.hiLayerResponseHex != null)
              TechItem('HL Response', isoDep!.hiLayerResponseHex!),
            if (isoDep!.historicalBytesHex != null)
              TechItem('Historical Bytes', isoDep!.historicalBytesHex!),
            TechItem(
              'Extended APDU',
              isoDep!.isExtendedLengthApduSupported
                  ? 'Supported'
                  : 'Not supported',
            ),
          ],
        ),
      );
    }
    if (mifareClassic != null) {
      list.add(
        TechSection(
          title: 'MIFARE Classic',
          items: [
            TechItem('Type', mifareClassic!.type),
            TechItem('Size', mifareClassic!.sizeLabel),
            TechItem('Sectors', '${mifareClassic!.sectorCount}'),
            TechItem('Blocks', '${mifareClassic!.blockCount}'),
          ],
        ),
      );
    }
    if (mifareUltralight != null) {
      list.add(
        TechSection(
          title: 'MIFARE Ultralight',
          items: [TechItem('Type', mifareUltralight!.type)],
        ),
      );
    }
    if (ndef != null) {
      list.add(
        TechSection(
          title: 'NDEF',
          items: [
            TechItem('Capacity', ndef!.capacityLabel),
            TechItem('Writable', ndef!.isWritable ? 'Yes' : 'No'),
            TechItem('Records', '${ndef!.recordCount}'),
          ],
        ),
      );
    }
    if (ndefFormatable != null) {
      list.add(
        TechSection(
          title: 'NDEF Format',
          items: [TechItem('Status', 'Formatable - can be initialized')],
        ),
      );
    }
    if (nfcBarcode != null) {
      list.add(
        TechSection(
          title: 'NFC Barcode',
          items: [
            TechItem('Type', nfcBarcode!.type),
            TechItem('Data', nfcBarcode!.barcodeHex),
          ],
        ),
      );
    }
    return list;
  }

  static TagTechData extract(NfcTag tag, {Ndef? ndef, int recordCount = 0}) {
    final androidTag = NfcTagAndroid.from(tag);
    return TagTechData(
      uid: androidTag != null ? NdefCodec.toHex(androidTag.id) : '',
      techList: androidTag != null
          ? List<String>.from(androidTag.techList)
          : const [],
      nfcA: NfcAData.from(NfcAAndroid.from(tag)),
      nfcB: NfcBData.from(NfcBAndroid.from(tag)),
      nfcF: NfcFData.from(NfcFAndroid.from(tag)),
      nfcV: NfcVData.from(NfcVAndroid.from(tag)),
      isoDep: IsoDepTechData.from(IsoDepAndroid.from(tag)),
      mifareClassic: MifareClassicTechData.from(MifareClassicAndroid.from(tag)),
      mifareUltralight: MifareUltralightTechData.from(
        MifareUltralightAndroid.from(tag),
      ),
      ndef: NdefTechData.from(ndef, recordCount),
      ndefFormatable: NdefFormatableTechData.from(
        NdefFormatableAndroid.from(tag),
      ),
      nfcBarcode: NfcBarcodeTechData.from(NfcBarcodeAndroid.from(tag)),
    );
  }
}

class TechItem {
  final String label;
  final String value;
  TechItem(this.label, this.value);
}

class TechSection {
  final String title;
  final List<TechItem> items;
  TechSection({required this.title, required this.items});
}
