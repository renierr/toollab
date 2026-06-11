// IT (Impulse Tracker) sample decompression
// Based on ITTECH.TXT and the canonical ITSEX.C source by Jeffrey Lim.
//
// Key difference between IT 2.14 and IT 2.15:
// - IT 2.14: Single integration (d1 += delta; output = d1)
// - IT 2.15: Double integration (d1 += delta; d2 += d1; output = d2)
// At max bit width, IT 2.14 uses the sentinel for width change,
// while IT 2.15 uses it for a raw sample value injection.

import 'dart:math' as math;
import 'dart:typed_data';

/// Variable-width bit-stream reader. Reads least-significant bits first,
/// advancing through [data] one byte at a time starting from [offset].
class BitReader {
  final Uint8List data;
  int pos;
  int bitPos;

  BitReader(this.data, int offset) : pos = offset, bitPos = 0;

  int readBits(int numBits) {
    int value = 0;
    int bitsRead = 0;

    while (bitsRead < numBits) {
      if (pos >= data.length) return value;
      final bitsAvailable = 8 - bitPos;
      final bitsToRead = math.min(numBits - bitsRead, bitsAvailable);
      final mask = (1 << bitsToRead) - 1;
      value |= ((data[pos] >> bitPos) & mask) << bitsRead;

      bitPos += bitsToRead;
      bitsRead += bitsToRead;

      if (bitPos >= 8) {
        bitPos = 0;
        pos++;
      }
    }
    return value;
  }
}

int _signExtend(int value, int bits) {
  final signBit = 1 << (bits - 1);
  final fullRange = 1 << bits;
  return (value & signBit) != 0 ? value - fullRange : value;
}

/// Detects an 8-bit method-2 width-change code.
/// Returns null when [value] is a normal sample value, 0 when the caller
/// must read 3 extra bits to derive the new width, or the new width directly.
int? _decodeMethod2WidthChange8(int value, int bitWidth) {
  if (bitWidth < 7) {
    if (value == 1 << (bitWidth - 1)) {
      return 0; // marker: caller must read 3 extra bits
    }
    return null;
  }

  if (bitWidth < 9) {
    // IT method-2 width change for widths 7-8 uses a reserved value range.
    final border = (0xff >> (9 - bitWidth)) - 4;
    if (value > border && value <= border + 8) {
      // Encoded width domain is 1..8 (not 0..7).
      final packedWidth = value - border;
      return packedWidth < bitWidth ? packedWidth : packedWidth + 1;
    }
  }

  return null;
}

/// Detects a 16-bit method-2 width-change code.
/// Returns null when [value] is a normal sample value, 0 when the caller
/// must read 4 extra bits to derive the new width, or the new width directly.
int? _decodeMethod2WidthChange16(int value, int bitWidth) {
  if (bitWidth < 7) {
    if (value == 1 << (bitWidth - 1)) {
      return 0; // marker: caller must read 4 extra bits
    }
    return null;
  }

  if (bitWidth < 17) {
    // IT method-2 width change for widths 7-16 uses a reserved value range.
    final border = (0xffff >> (17 - bitWidth)) - 8;
    if (value > border && value <= border + 16) {
      // Encoded width domain is 1..16 (not 0..15).
      final packedWidth = value - border;
      return packedWidth < bitWidth ? packedWidth : packedWidth + 1;
    }
  }

  return null;
}

/// Decompress 8-bit IT compressed samples.
/// [isIT215] - true = IT 2.15 double-integration mode,
/// false = IT 2.14 single-integration.
Float32List decompressIT8(
  Uint8List inData,
  int offset,
  int outLen,
  bool isIT215,
  bool isSigned,
) {
  int pos = offset;
  int outPos = 0;
  final out = Float32List(outLen);

  while (outPos < outLen) {
    if (pos + 2 > inData.length) break;
    final blockSize = inData[pos] | (inData[pos + 1] << 8);
    pos += 2;

    if (blockSize == 0 || pos + blockSize > inData.length) break;

    final br = BitReader(inData, pos);
    pos += blockSize;

    int bitWidth = 9;
    int d1 = 0;
    int d2 = 0;
    final blockSamples = math.min(0x8000, outLen - outPos);
    final blockEnd = outPos + blockSamples;

    while (outPos < blockEnd) {
      final v = br.readBits(bitWidth);

      final method2Width = _decodeMethod2WidthChange8(v, bitWidth);
      if (method2Width != null) {
        if (method2Width == 0) {
          final nw = br.readBits(3) + 1;
          bitWidth = nw < bitWidth ? nw : nw + 1;
        } else {
          bitWidth = method2Width;
        }
        if (bitWidth > 9) bitWidth = 9;
        if (bitWidth < 1) bitWidth = 1;
        continue;
      }

      if (bitWidth == 9) {
        // bitWidth == 9
        if ((v & 0x100) != 0) {
          if (isIT215) {
            // IT 2.15: lower 8 bits = raw sample value injected into d1
            d1 = v & 0xff;
            if (d1 >= 128) d1 -= 256;
            d2 += d1;
            final wrapped = d2 & 0xff;
            if (isSigned) {
              int finalVal = wrapped;
              if (finalVal >= 128) finalVal -= 256;
              out[outPos++] = finalVal / 128;
            } else {
              out[outPos++] = (wrapped - 128) / 128;
            }
            continue;
          } else {
            // IT 2.14: width change
            final nw = (v & 0xff) + 1;
            if (nw >= 1 && nw <= 9) bitWidth = nw;
            continue;
          }
        }
      }

      // Sign-extend value from bitWidth bits
      final signedVal = _signExtend(v, bitWidth);

      // IT 2.14: single integration; IT 2.15: double integration
      d1 += signedVal;
      if (isIT215) {
        d2 += d1;
        final wrapped = d2 & 0xff;
        if (isSigned) {
          int finalVal = wrapped;
          if (finalVal >= 128) finalVal -= 256;
          out[outPos++] = finalVal / 128;
        } else {
          out[outPos++] = (wrapped - 128) / 128;
        }
      } else {
        final wrapped = d1 & 0xff;
        if (isSigned) {
          int finalVal = wrapped;
          if (finalVal >= 128) finalVal -= 256;
          out[outPos++] = finalVal / 128;
        } else {
          out[outPos++] = (wrapped - 128) / 128;
        }
      }
    }
  }

  return out;
}

/// Decompress 16-bit IT compressed samples.
/// [isIT215] - true = IT 2.15 double-integration mode,
/// false = IT 2.14 single-integration.
Float32List decompressIT16(
  Uint8List inData,
  int offset,
  int outLen,
  bool isIT215,
  bool isSigned,
) {
  int pos = offset;
  int outPos = 0;
  final out = Float32List(outLen);

  while (outPos < outLen) {
    if (pos + 2 > inData.length) break;
    final blockSize = inData[pos] | (inData[pos + 1] << 8);
    pos += 2;

    if (blockSize == 0 || pos + blockSize > inData.length) break;

    final br = BitReader(inData, pos);
    pos += blockSize;

    int bitWidth = 17;
    int d1 = 0;
    int d2 = 0;
    final blockSamples = math.min(0x4000, outLen - outPos);
    final blockEnd = outPos + blockSamples;

    while (outPos < blockEnd) {
      final v = br.readBits(bitWidth);

      final method2Width = _decodeMethod2WidthChange16(v, bitWidth);
      if (method2Width != null) {
        if (method2Width == 0) {
          final nw = br.readBits(4) + 1;
          bitWidth = nw < bitWidth ? nw : nw + 1;
        } else {
          bitWidth = method2Width;
        }
        if (bitWidth > 17) bitWidth = 17;
        if (bitWidth < 1) bitWidth = 1;
        continue;
      }

      if (bitWidth == 17) {
        // bitWidth == 17
        if ((v & 0x10000) != 0) {
          if (isIT215) {
            // IT 2.15: lower 16 bits = raw sample value
            d1 = v & 0xffff;
            if (d1 >= 32768) d1 -= 65536;
            d2 += d1;
            final wrapped = d2 & 0xffff;
            if (isSigned) {
              int finalVal = wrapped;
              if (finalVal >= 32768) finalVal -= 65536;
              out[outPos++] = finalVal / 32768;
            } else {
              out[outPos++] = (wrapped - 32768) / 32768;
            }
            continue;
          } else {
            // IT 2.14: width change
            final nw = (v & 0xffff) + 1;
            if (nw >= 1 && nw <= 17) bitWidth = nw;
            continue;
          }
        }
      }

      // Sign-extend value from bitWidth bits
      final signedVal = _signExtend(v, bitWidth);

      // IT 2.14: single integration; IT 2.15: double integration
      d1 += signedVal;
      if (isIT215) {
        d2 += d1;
        final wrapped = d2 & 0xffff;
        if (isSigned) {
          int finalVal = wrapped;
          if (finalVal >= 32768) finalVal -= 65536;
          out[outPos++] = finalVal / 32768;
        } else {
          out[outPos++] = (wrapped - 32768) / 32768;
        }
      } else {
        final wrapped = d1 & 0xffff;
        if (isSigned) {
          int finalVal = wrapped;
          if (finalVal >= 32768) finalVal -= 65536;
          out[outPos++] = finalVal / 32768;
        } else {
          out[outPos++] = (wrapped - 32768) / 32768;
        }
      }
    }
  }

  return out;
}
