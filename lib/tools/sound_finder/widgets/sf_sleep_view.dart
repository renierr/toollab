import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../sound_finder_state.dart';

class SfSleepView extends StatelessWidget {
  const SfSleepView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SoundFinderState>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Sleep Sound Recorder',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Records only chunks with sound, discards silence to save space. '
          'Place the phone near the bed, plug in the charger, then turn off the screen.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        if (!state.sleepActive) ...[
          Row(
            children: [
              Text('Duration:'),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: state.sleepDurationMinutes,
                items: const [
                  DropdownMenuItem(value: 60, child: Text('1 h')),
                  DropdownMenuItem(value: 120, child: Text('2 h')),
                  DropdownMenuItem(value: 240, child: Text('4 h')),
                  DropdownMenuItem(value: 480, child: Text('8 h')),
                  DropdownMenuItem(value: 720, child: Text('12 h')),
                ],
                onChanged: (v) {
                  if (v != null) state.setSleepDurationMinutes(v);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Noise suppression, echo cancellation and auto-gain are disabled '
            'for capture. Sample rate 16 kHz.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.bedtime_outlined),
            label: const Text('Start sleep recording'),
            onPressed: () => state.startSleep(),
          ),
        ] else ...[
          Text('Recording… elapsed ${_fmt(state.sleepElapsed)}'),
          const SizedBox(height: 4),
          Text('Saved chunks: ${state.sleepChunksKept}'),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.stop_outlined),
            label: const Text('Stop'),
            onPressed: () => state.stopSleep(),
          ),
        ],
      ],
    );
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }
}
