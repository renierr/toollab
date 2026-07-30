import 'package:flutter/material.dart';

class Grammar {
  final Map<String, dynamic> raw;
  final Map<String, Rule> repository = {};
  late final List<Rule> patterns;

  Grammar(this.raw) {
    final repoMap = raw['repository'] as Map<String, dynamic>?;
    if (repoMap != null) {
      repoMap.forEach((key, val) {
        repository[key] = Rule.fromJson(val, this);
      });
    }
    patterns =
        (raw['patterns'] as List?)
            ?.map((val) => Rule.fromJson(val, this))
            .toList() ??
        [];
  }
}

class Rule {
  final String? name;
  final RegExp? matchRegExp;
  final RegExp? beginRegExp;
  final RegExp? endRegExp;
  final Map<int, String>? captures;
  final Map<int, String>? beginCaptures;
  final Map<int, String>? endCaptures;
  final String? include;
  final List<Rule>? patterns;

  Rule({
    this.name,
    this.matchRegExp,
    this.beginRegExp,
    this.endRegExp,
    this.captures,
    this.beginCaptures,
    this.endCaptures,
    this.include,
    this.patterns,
  });

  factory Rule.fromJson(dynamic json, Grammar grammar) {
    if (json is! Map<String, dynamic>) {
      return Rule();
    }

    final include = json['include'] as String?;
    if (include != null) {
      return Rule(include: include);
    }

    RegExp? parseRegExp(String? pat) {
      if (pat == null) return null;
      try {
        bool caseSensitive = true;
        String sanitized = pat;

        if (sanitized.contains('(?i)')) {
          caseSensitive = false;
          sanitized = sanitized.replaceAll('(?i)', '');
        }

        sanitized = sanitized
            .replaceAll('*+', '*')
            .replaceAll('++', '+')
            .replaceAll('?+', '?')
            .replaceAll('}+', '}')
            .replaceAll(r'\h', r'[ \t]')
            .replaceAll(r'\v', r'[\n\r]')
            .replaceAll(r'\G', '')
            .replaceAll('[]]', r'[\]]')
            .replaceAll('[^]]', r'[^\]]');

        return RegExp(sanitized, caseSensitive: caseSensitive);
      } catch (e) {
        return null;
      }
    }

    Map<int, String>? parseCaptures(dynamic caps) {
      if (caps == null) return null;
      final map = <int, String>{};
      if (caps is Map) {
        caps.forEach((key, val) {
          final idx = int.tryParse(key.toString());
          if (idx != null && val is Map) {
            final name = val['name'] as String?;
            if (name != null) {
              map[idx] = name;
            }
          }
        });
      }
      return map;
    }

    return Rule(
      name: json['name'] as String?,
      matchRegExp: parseRegExp(json['match'] as String?),
      beginRegExp: parseRegExp(json['begin'] as String?),
      endRegExp: parseRegExp(json['end'] as String?),
      captures: parseCaptures(json['captures'] ?? json['captures']),
      beginCaptures: parseCaptures(json['beginCaptures']),
      endCaptures: parseCaptures(json['endCaptures']),
      patterns: (json['patterns'] as List?)
          ?.map((val) => Rule.fromJson(val, grammar))
          .toList(),
    );
  }
}

class MatchResult {
  final Rule rule;
  final Match match;
  final bool isEnd;

  MatchResult(this.rule, this.match, this.isEnd);
}

class IsolateResult {
  final List<String> scopes;
  final List<int> tokens;

  IsolateResult(this.scopes, this.tokens);
}

class TextMateEngine {
  TextMateEngine._();

  static List<Rule> resolveRules(
    List<Rule> rules,
    Grammar grammar,
    Set<String> visited,
  ) {
    final List<Rule> resolved = [];
    for (final rule in rules) {
      if (rule.include != null) {
        final inc = rule.include!;
        if (inc == r'$self' || inc == 'self') {
          if (!visited.contains(r'$self')) {
            visited.add(r'$self');
            resolved.addAll(resolveRules(grammar.patterns, grammar, visited));
            visited.remove(r'$self');
          }
        } else if (inc.startsWith('#')) {
          final key = inc.substring(1);
          if (!visited.contains(key)) {
            visited.add(key);
            final repoRule = grammar.repository[key];
            if (repoRule != null) {
              resolved.addAll(resolveRules([repoRule], grammar, visited));
            }
            visited.remove(key);
          }
        }
      } else if (rule.beginRegExp == null &&
          rule.matchRegExp == null &&
          rule.patterns != null) {
        resolved.addAll(resolveRules(rule.patterns!, grammar, visited));
      } else {
        resolved.add(rule);
      }
    }
    return resolved;
  }

  static MatchResult? findEarliestMatch(
    String line,
    int pos,
    List<Rule> rules,
    Rule? activeBlock,
    Grammar grammar,
  ) {
    int bestStart = -1;
    MatchResult? bestResult;

    void updateBest(Rule rule, Match match, bool isEnd) {
      if (match.start < pos) return;
      if (bestStart == -1 || match.start < bestStart) {
        bestStart = match.start;
        bestResult = MatchResult(rule, match, isEnd);
      }
    }

    if (activeBlock != null && activeBlock.endRegExp != null) {
      final matches = activeBlock.endRegExp!.allMatches(line, pos);
      if (matches.isNotEmpty) {
        updateBest(activeBlock, matches.first, true);
      }
    }

    final resolved = resolveRules(rules, grammar, {});
    for (final rule in resolved) {
      if (rule.matchRegExp != null) {
        final matches = rule.matchRegExp!.allMatches(line, pos);
        if (matches.isNotEmpty) {
          updateBest(rule, matches.first, false);
        }
      } else if (rule.beginRegExp != null) {
        final matches = rule.beginRegExp!.allMatches(line, pos);
        if (matches.isNotEmpty) {
          updateBest(rule, matches.first, false);
        }
      }
    }

    return bestResult;
  }

  static IsolateResult tokenize(String text, Map<String, dynamic> grammarJson) {
    final grammar = Grammar(grammarJson);
    final scopesList = <String>[];
    final scopesMap = <String, int>{};

    int getScopeId(String scope) {
      return scopesMap.putIfAbsent(scope, () {
        scopesList.add(scope);
        return scopesList.length - 1;
      });
    }

    final tokens = <int>[];
    final lines = text.split('\n');

    final List<Rule> stack = [];
    int currentOffset = 0;

    for (int lineIdx = 0; lineIdx < lines.length; lineIdx++) {
      final line = lines[lineIdx];
      int pos = 0;

      while (pos < line.length) {
        final List<Rule> activePatterns =
            stack.isNotEmpty && stack.last.patterns != null
            ? stack.last.patterns!
            : grammar.patterns;

        final earliest = findEarliestMatch(
          line,
          pos,
          activePatterns,
          stack.isNotEmpty ? stack.last : null,
          grammar,
        );

        if (earliest == null) {
          if (stack.isNotEmpty && stack.last.name != null) {
            tokens.add(currentOffset + pos);
            tokens.add(line.length - pos);
            tokens.add(getScopeId(stack.last.name!));
          }
          break;
        }

        final matchStart = earliest.match.start;
        final matchEnd = earliest.match.end;

        if (matchStart > pos) {
          if (stack.isNotEmpty && stack.last.name != null) {
            tokens.add(currentOffset + pos);
            tokens.add(matchStart - pos);
            tokens.add(getScopeId(stack.last.name!));
          }
        }

        if (earliest.isEnd) {
          _addCaptureTokens(
            line,
            currentOffset,
            matchStart,
            earliest.match,
            earliest.rule.endCaptures,
            earliest.rule.name,
            getScopeId,
            tokens,
          );
          if (stack.isNotEmpty) {
            stack.removeLast();
          }
        } else {
          final rule = earliest.rule;
          if (rule.beginRegExp != null) {
            _addCaptureTokens(
              line,
              currentOffset,
              matchStart,
              earliest.match,
              rule.beginCaptures,
              rule.name,
              getScopeId,
              tokens,
            );
            stack.add(rule);
          } else {
            _addCaptureTokens(
              line,
              currentOffset,
              matchStart,
              earliest.match,
              rule.captures,
              rule.name,
              getScopeId,
              tokens,
            );
          }
        }

        if (matchEnd == pos) {
          pos++;
        } else {
          pos = matchEnd;
        }
      }

      currentOffset += line.length + 1;
    }

    return IsolateResult(scopesList, tokens);
  }

  static void _addCaptureTokens(
    String line,
    int currentOffset,
    int matchStart,
    Match match,
    Map<int, String>? captures,
    String? ruleName,
    int Function(String) getScopeId,
    List<int> tokens,
  ) {
    if (captures != null && captures.isNotEmpty) {
      captures.forEach((groupIndex, scope) {
        if (groupIndex <= match.groupCount) {
          final groupText = match.group(groupIndex);
          if (groupText != null && groupText.isNotEmpty) {
            final idx = match.group(0)!.indexOf(groupText);
            if (idx != -1) {
              final gStart = match.start + idx;
              tokens.add(currentOffset + gStart);
              tokens.add(groupText.length);
              tokens.add(getScopeId(scope));
            }
          }
        }
      });
    } else if (ruleName != null) {
      tokens.add(currentOffset + match.start);
      tokens.add(match.end - match.start);
      tokens.add(getScopeId(ruleName));
    }
  }

  static TextStyle getScopeStyle(String scope, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final parts = scope.split('.');
    for (int i = parts.length; i > 0; i--) {
      final subScope = parts.take(i).join('.');
      switch (subScope) {
        case 'comment':
        case 'punctuation.definition.comment':
          return const TextStyle(
            color: Colors.grey,
            fontStyle: FontStyle.italic,
          );
        case 'string':
        case 'punctuation.definition.string':
          return const TextStyle(color: Colors.green);
        case 'keyword':
        case 'storage':
          return TextStyle(
            color: isDark ? Colors.orangeAccent : Colors.deepOrange,
            fontWeight: FontWeight.bold,
          );
        case 'constant':
        case 'support.constant':
          return TextStyle(
            color: isDark ? Colors.lightBlueAccent : Colors.blue,
          );
        case 'entity.name.function':
        case 'support.function':
          return TextStyle(
            color: isDark ? Colors.lightBlueAccent : Colors.blueAccent,
          );
        case 'entity.name.type':
        case 'entity.name.class':
        case 'support.class':
        case 'support.type':
          return const TextStyle(color: Colors.teal);
        case 'variable':
        case 'variable.parameter':
          return TextStyle(color: isDark ? Colors.white70 : Colors.black87);
        case 'meta.structure.dictionary.key':
        case 'entity.name.tag.yaml':
        case 'support.type.property-name':
          return TextStyle(
            color: isDark ? Colors.indigoAccent : Colors.indigo,
            fontWeight: FontWeight.bold,
          );
        case 'markup.heading':
          return const TextStyle(
            color: Colors.blueAccent,
            fontWeight: FontWeight.bold,
          );
        case 'markup.bold':
          return TextStyle(
            color: isDark ? Colors.orangeAccent : Colors.orange,
            fontWeight: FontWeight.bold,
          );
        case 'markup.italic':
          return TextStyle(
            color: isDark ? Colors.amberAccent : Colors.amber,
            fontStyle: FontStyle.italic,
          );
        case 'markup.underline.link':
          return const TextStyle(
            color: Colors.blue,
            decoration: TextDecoration.underline,
          );
        case 'markup.raw':
          return const TextStyle(color: Colors.teal);
        case 'markup.quote':
          return const TextStyle(
            color: Colors.grey,
            fontStyle: FontStyle.italic,
          );
        case 'markup.list':
          return const TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.bold,
          );
      }
    }
    return TextStyle(color: theme.colorScheme.onSurface);
  }
}
