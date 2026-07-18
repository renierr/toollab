import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import 'sf_morse_analyser.dart';
import 'sf_morse_generator.dart';

enum MorseSubMode { generator, analyser }

class SfMorseView extends StatefulWidget {
  const SfMorseView({super.key});

  @override
  State<SfMorseView> createState() => _SfMorseViewState();
}

class _SfMorseViewState extends State<SfMorseView> {
  MorseSubMode _subMode = MorseSubMode.generator;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: SegmentedButton<MorseSubMode>(
              segments: [
                ButtonSegment(
                  value: MorseSubMode.generator,
                  icon: const Icon(Icons.send_outlined),
                  label: Text(l10n.sfMorseGenTab),
                ),
                ButtonSegment(
                  value: MorseSubMode.analyser,
                  icon: const Icon(Icons.hearing_outlined),
                  label: Text(l10n.sfMorseAnalTab),
                ),
              ],
              selected: {_subMode},
              showSelectedIcon: false,
              onSelectionChanged: (selection) {
                setState(() {
                  _subMode = selection.first;
                });
              },
            ),
          ),
        ),
        switch (_subMode) {
          MorseSubMode.generator => const SfMorseGenerator(),
          MorseSubMode.analyser => const SfMorseAnalyser(),
        },
      ],
    );
  }
}
