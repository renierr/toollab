import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:nfc_manager/nfc_manager_android.dart';

class TlvNode {
  final int tag;
  final Uint8List value;
  final List<TlvNode> children;

  TlvNode(this.tag, this.value, this.children);

  @override
  String toString() {
    return 'Tag: 0x${tag.toRadixString(16).toUpperCase()}, Length: ${value.length}';
  }
}

class EmvCardDetails {
  final String brand;
  final String number;
  final String expiry;
  final String holder;
  final String aid;
  final String label;

  EmvCardDetails({
    required this.brand,
    required this.number,
    required this.expiry,
    required this.holder,
    required this.aid,
    required this.label,
  });
}

class EmvParser {
  static const Map<String, String> commonAids = {
    'A0000000031010': 'Visa Credit/Debit',
    'A0000000041010': 'Mastercard Credit/Debit',
    'A0000000043060': 'Maestro Debit',
    'A000000025010801': 'American Express',
    'A0000000651010': 'JCB',
    'A000000333010101': 'UnionPay',
    'A0000001523010': 'Discover',
    'A0000002771010': 'Interac',
  };

  static List<TlvNode> parseTlv(Uint8List bytes) {
    List<TlvNode> nodes = [];
    int i = 0;
    while (i < bytes.length) {
      if (bytes[i] == 0x00 || bytes[i] == 0xFF) {
        i++;
        continue;
      }

      int tag = bytes[i++];
      // If bottom 5 bits are 1, it's multi-byte
      if ((tag & 0x1F) == 0x1F) {
        if (i >= bytes.length) break;
        tag = (tag << 8) | bytes[i++];
        while ((tag & 0x80) != 0 && i < bytes.length) {
          tag = (tag << 8) | bytes[i++];
        }
      }

      if (i >= bytes.length) break;

      int length = bytes[i++];
      if ((length & 0x80) != 0) {
        int numBytes = length & 0x7F;
        length = 0;
        for (int j = 0; j < numBytes; j++) {
          if (i >= bytes.length) break;
          length = (length << 8) | bytes[i++];
        }
      }

      if (i + length > bytes.length) {
        length = bytes.length - i;
      }

      Uint8List value = bytes.sublist(i, i + length);
      i += length;

      List<TlvNode> children = [];
      // Determine if constructed by looking at first byte (MSB of the tag)
      int firstByte = tag;
      while (firstByte > 0xFF) {
        firstByte >>= 8;
      }
      bool isConstructed = (firstByte & 0x20) != 0;

      if (isConstructed) {
        children = parseTlv(value);
      }

      nodes.add(TlvNode(tag, value, children));
    }
    return nodes;
  }

  static TlvNode? findTag(List<TlvNode> nodes, int targetTag) {
    for (var node in nodes) {
      if (node.tag == targetTag) return node;
      var found = findTag(node.children, targetTag);
      if (found != null) return found;
    }
    return null;
  }

  static List<TlvNode> findAllTags(List<TlvNode> nodes, int targetTag) {
    List<TlvNode> results = [];
    for (var node in nodes) {
      if (node.tag == targetTag) results.add(node);
      results.addAll(findAllTags(node.children, targetTag));
    }
    return results;
  }

  static String decodePan(Uint8List bytes) {
    StringBuffer sb = StringBuffer();
    for (var b in bytes) {
      int high = (b >> 4) & 0x0F;
      int low = b & 0x0F;
      sb.write(high.toRadixString(16));
      sb.write(low.toRadixString(16));
    }
    String pan = sb.toString().toUpperCase();
    if (pan.endsWith('F')) {
      pan = pan.substring(0, pan.length - 1);
    }
    return pan;
  }

  static String decodeExpiry(Uint8List bytes) {
    if (bytes.length < 2) return '';
    StringBuffer sb = StringBuffer();
    // Expiration date is YYMMDD, we only need YYMM
    for (int i = 0; i < 2; i++) {
      int b = bytes[i];
      int high = (b >> 4) & 0x0F;
      int low = b & 0x0F;
      sb.write(high.toRadixString(16));
      sb.write(low.toRadixString(16));
    }
    String str = sb.toString();
    if (str.length >= 4) {
      String yy = str.substring(0, 2);
      String mm = str.substring(2, 4);
      return '$mm/$yy';
    }
    return '';
  }

  static String decodeString(Uint8List bytes) {
    return utf8.decode(bytes, allowMalformed: true).trim();
  }

  static Future<EmvCardDetails?> readCard(IsoDepAndroid isoDep) async {
    try {
      // 1. Try to SELECT PPSE
      // CLA = 00, INS = A4, P1 = 04, P2 = 00, Lc = 0E, Data = "2PAY.SYS.DDF01" (325041592E5359532E4444463031)
      Uint8List selectPpseCmd = Uint8List.fromList([
        0x00,
        0xA4,
        0x04,
        0x00,
        0x0E,
        0x32,
        0x50,
        0x41,
        0x59,
        0x2E,
        0x53,
        0x59,
        0x53,
        0x2E,
        0x44,
        0x44,
        0x46,
        0x30,
        0x31,
        0x00,
      ]);

      List<String> candidateAids = [];
      try {
        Uint8List response = await isoDep.transceive(selectPpseCmd);
        if (response.length >= 2 &&
            response[response.length - 2] == 0x90 &&
            response[response.length - 1] == 0x00) {
          List<TlvNode> nodes = parseTlv(
            response.sublist(0, response.length - 2),
          );
          List<TlvNode> aidNodes = findAllTags(nodes, 0x4F);
          for (var node in aidNodes) {
            candidateAids.add(
              node.value
                  .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
                  .join(),
            );
          }
        }
      } catch (e) {
        debugPrint('[NfcTagLab] PPSE selection failed: $e');
      }

      if (candidateAids.isEmpty) {
        candidateAids = commonAids.keys.toList();
      }

      for (String aidHex in candidateAids) {
        List<int> aidBytes = [];
        for (int i = 0; i < aidHex.length; i += 2) {
          aidBytes.add(int.parse(aidHex.substring(i, i + 2), radix: 16));
        }

        Uint8List selectAidCmd = Uint8List.fromList([
          0x00,
          0xA4,
          0x04,
          0x00,
          aidBytes.length,
          ...aidBytes,
          0x00,
        ]);

        try {
          Uint8List response = await isoDep.transceive(selectAidCmd);
          if (response.length >= 2 &&
              response[response.length - 2] == 0x90 &&
              response[response.length - 1] == 0x00) {
            List<TlvNode> fciNodes = parseTlv(
              response.sublist(0, response.length - 2),
            );
            TlvNode? labelNode = findTag(fciNodes, 0x50);
            TlvNode? prefNameNode = findTag(fciNodes, 0x9F12);
            String label = labelNode != null
                ? decodeString(labelNode.value)
                : '';
            String prefName = prefNameNode != null
                ? decodeString(prefNameNode.value)
                : '';
            String finalLabel = prefName.isNotEmpty
                ? prefName
                : (label.isNotEmpty
                      ? label
                      : (commonAids[aidHex] ?? 'Payment Card'));

            // SFI 1 to 4, record 1 to 10
            for (int sfi = 1; sfi <= 4; sfi++) {
              for (int rec = 1; rec <= 10; rec++) {
                int p2 = (sfi << 3) | 4;
                Uint8List readCmd = Uint8List.fromList([
                  0x00,
                  0xB2,
                  rec,
                  p2,
                  0x00,
                ]);

                try {
                  Uint8List recResp = await isoDep.transceive(readCmd);
                  if (recResp.length >= 2 &&
                      recResp[recResp.length - 2] == 0x90 &&
                      recResp[recResp.length - 1] == 0x00) {
                    List<TlvNode> recNodes = parseTlv(
                      recResp.sublist(0, recResp.length - 2),
                    );
                    TlvNode? panNode = findTag(recNodes, 0x5A);
                    if (panNode != null) {
                      String pan = decodePan(panNode.value);
                      TlvNode? expiryNode = findTag(recNodes, 0x5F24);
                      TlvNode? holderNode = findTag(recNodes, 0x5F20);

                      String expiry = expiryNode != null
                          ? decodeExpiry(expiryNode.value)
                          : '';
                      String holder = holderNode != null
                          ? decodeString(holderNode.value)
                          : '';

                      String brand = commonAids[aidHex] ?? 'Payment Card';
                      if (brand.startsWith('Visa') || pan.startsWith('4')) {
                        brand = 'Visa';
                      } else if (brand.startsWith('Mastercard') ||
                          pan.startsWith('5')) {
                        brand = 'Mastercard';
                      } else if (brand.startsWith('American Express') ||
                          pan.startsWith('37') ||
                          pan.startsWith('34')) {
                        brand = 'American Express';
                      }

                      return EmvCardDetails(
                        brand: brand,
                        number: pan,
                        expiry: expiry,
                        holder: holder,
                        aid: aidHex,
                        label: finalLabel,
                      );
                    }
                  }
                } catch (e) {
                  // Ignore read record error and continue
                }
              }
            }
          }
        } catch (e) {
          debugPrint('[NfcTagLab] AID $aidHex select failed: $e');
        }
      }
    } catch (e) {
      debugPrint('[NfcTagLab] EMV read error: $e');
    }
    return null;
  }
}
