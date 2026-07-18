import 'dart:collection';

class MorseToken {
  final String char;
  final String morse;
  final bool isWordGap;
  final bool isCharGap;

  const MorseToken({
    required this.char,
    required this.morse,
    this.isWordGap = false,
    this.isCharGap = false,
  });

  bool get isLetter => !isWordGap && !isCharGap;
}

class MorseConverter {
  MorseConverter._();

  static const Map<String, String> morseMap = {
    'A': '.-',
    'B': '-...',
    'C': '-.-.',
    'D': '-..',
    'E': '.',
    'F': '..-.',
    'G': '--.',
    'H': '....',
    'I': '..',
    'J': '.---',
    'K': '-.-',
    'L': '.-..',
    'M': '--',
    'N': '-.',
    'O': '---',
    'P': '.--.',
    'Q': '--.-',
    'R': '.-.',
    'S': '...',
    'T': '-',
    'U': '..-',
    'V': '...-',
    'W': '.--',
    'X': '-..-',
    'Y': '-.--',
    'Z': '--..',
    'Ä': '.-.-',
    'Ö': '---.',
    'Ü': '..--',
    'ß': '...--..',
    '0': '-----',
    '1': '.----',
    '2': '..---',
    '3': '...--',
    '4': '....-',
    '5': '.....',
    '6': '-....',
    '7': '--...',
    '8': '---..',
    '9': '----.',
    '.': '.-.-.-',
    ',': '--..--',
    '?': '..--..',
    "'": '.----.',
    '!': '-.-.--',
    '/': '-..-.',
    '(': '-.--.',
    ')': '-.--.-',
    '&': '.-...',
    ':': '---...',
    ';': '-.-.-.',
    '=': '-...-',
    '+': '.-.-.',
    '-': '-....-',
    '_': '..--.-',
    '"': '.-..-.',
    '@': '.--.-.',
  };

  static final Map<String, String> reverseMorseMap = UnmodifiableMapView(
    morseMap.map((key, value) => MapEntry(value, key)),
  );

  /// Converts plain text into a list of morse tokens for display and playback.
  static List<MorseToken> tokenize(String text) {
    final List<MorseToken> tokens = [];
    final List<String> words = text
        .toUpperCase()
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    for (int i = 0; i < words.length; i++) {
      final String word = words[i];
      final List<String> chars = word.split('');

      for (int j = 0; j < chars.length; j++) {
        final String char = chars[j];
        final String? morse = morseMap[char];
        if (morse != null) {
          tokens.add(MorseToken(char: char, morse: morse));
          if (j < chars.length - 1) {
            tokens.add(const MorseToken(char: '', morse: '/', isCharGap: true));
          }
        }
      }

      if (i < words.length - 1) {
        tokens.add(const MorseToken(char: '', morse: '//', isWordGap: true));
      }
    }

    return tokens;
  }

  /// Converts Morse code string back to plain text.
  static String morseToText(String morse) {
    final List<String> words = morse.split(RegExp(r'\s*//\s*|\s*/\s*/\s*'));
    final List<String> decodedWords = [];

    for (final String word in words) {
      if (word.trim().isEmpty) continue;
      final List<String> chars = word.trim().split(RegExp(r'\s+'));
      final String decodedWord = chars
          .map((c) => reverseMorseMap[c] ?? '?')
          .join('');
      if (decodedWord.isNotEmpty) {
        decodedWords.add(decodedWord);
      }
    }

    return decodedWords.join(' ');
  }

  /// Converts plain text to standard space-separated morse string.
  static String textToMorseString(String text) {
    return tokenize(text).map((t) => t.morse).join(' ');
  }
}
