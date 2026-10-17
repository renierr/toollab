import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../sound_finder_state.dart';
import 'sf_sleep_sessions_page.dart';

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
        if (state.sleepError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              state.sleepError!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
          ),
        // Live indicator
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.mic_outlined,
                color: state.sleepActive ? Colors.red : Colors.grey,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  state.sleepActive
                      ? 'Live: ${state.sleepLiveDb.toStringAsFixed(1)} dB  |  '
                          'Last event: ${state.sleepLastEvent == null ? 'none' : _fmtTime(state.sleepLastEvent!)}'
                      : 'Idle. Live level: ${state.sleepLiveDb.toStringAsFixed(1)} dB',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
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
          Text('Threshold: ${state.sleepThreshold.toStringAsFixed(4)}'),
          Slider(
            value: state.sleepThreshold,
            min: 0.0005,
            max: 0.1,
            divisions: 40,
            label: state.sleepThreshold.toStringAsFixed(4),
            onChanged: (v) => state.setSleepThreshold(v),
          ),
          Text(
            'Noise suppression, echo cancellation and auto-gain are disabled '
            'for capture.',
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
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.list_outlined),
            label: const Text('View sessions'),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SfSleepSessionsPage(),
                ),
              );
            },
          ),
          if (state.sleepSessionFiles.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Last session: ${state.sleepSessionFiles.length} chunks'),
          ],
        ] else ...[
          Text('Recording… elapsed ${_fmt(state.sleepElapsed)}'),
          const SizedBox(height: 4),
          Text('Saved chunks: ${state.sleepChunksKept}'),
          if (state.sleepSessionFiles.isNotEmpty) ...[
            const SizedBox(height: 4),
            ...state.sleepSessionFiles.map(
              (p) => Text(
                p.split('/').last,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.stop_outlined),
            label: const Text('Stop'),
            onPressed: () => state.stopSleep(),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.list_outlined),
            label: const Text('View sessions'),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SfSleepSessionsPage(),
                ),
              );
            },
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

  String _fmtTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}';
  }
}
