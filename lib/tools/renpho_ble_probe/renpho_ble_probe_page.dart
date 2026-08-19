import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/widgets/tool_layout.dart';

import 'config.dart';
import 'renpho_ble_probe_state.dart';
import 'renpho_health_connect_publisher.dart';
import 'renpho_measurement.dart';

class RenphoBleProbePage extends StatefulWidget {
  const RenphoBleProbePage({super.key});
  @override
  State<RenphoBleProbePage> createState() => _RenphoBleProbePageState();
}

class _RenphoBleProbePageState extends State<RenphoBleProbePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<RenphoBleProbeState>().load();
    });
  }

  Future<void> _editProfile(RenphoBleProbeState state) async {
    final name = TextEditingController(text: state.profile.name);
    final height = TextEditingController(
      text: state.profile.heightCm.toStringAsFixed(1),
    );
    final birth = TextEditingController(
      text: state.profile.birthDate.toIso8601String().substring(0, 10),
    );
    var sex = state.profile.sex;
    final profile = await showDialog<RenphoProfile>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Measurement profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Display name'),
              ),
              TextField(
                controller: height,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Height (cm)'),
              ),
              TextField(
                controller: birth,
                keyboardType: TextInputType.datetime,
                decoration: const InputDecoration(
                  labelText: 'Birth date (YYYY-MM-DD)',
                ),
              ),
              StatefulBuilder(
                builder: (context, setSex) => DropdownButtonFormField<String>(
                  initialValue: sex,
                  decoration: const InputDecoration(labelText: 'Sex'),
                  items: const [
                    DropdownMenuItem(value: 'male', child: Text('Male')),
                    DropdownMenuItem(value: 'female', child: Text('Female')),
                  ],
                  onChanged: (value) => setSex(() => sex = value!),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final parsedHeight = double.tryParse(height.text);
              final parsedBirth = DateTime.tryParse(birth.text);
              if (parsedHeight == null ||
                  parsedHeight < 80 ||
                  parsedHeight > 250 ||
                  parsedBirth == null)
                return;
              Navigator.pop(
                context,
                RenphoProfile(
                  name: name.text.trim().isEmpty ? 'User' : name.text.trim(),
                  sex: sex,
                  heightCm: parsedHeight,
                  birthDate: parsedBirth,
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (profile != null) await state.saveProfile(profile);
  }

  Future<void> _publish(BuildContext context) async {
    try {
      final count = await RenphoHealthConnectPublisher.instance
          .publishPending();
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Published $count measurement(s) to Health Connect.'),
          ),
        );
    } catch (e) {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Health Connect export failed: $e')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<RenphoBleProbeState>();
    final latest = state.latest;
    return ToolLayout(
      title: RenphoBleProbeTool.config.name,
      actions: [
        IconButton(
          icon: const Icon(Icons.upload_outlined),
          tooltip: 'Publish to Health Connect',
          onPressed: () => _publish(context),
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: 'Measurement profile',
          onPressed: () => _editProfile(state),
        ),
      ],
      child: LayoutBuilder(
        builder: (context, constraints) {
          final content = <Widget>[
            _WeightHero(
              weight: state.liveWeightKg ?? latest?.weightKg,
              status: state.status,
              ready: state.ready,
              working: state.scanning || state.connecting || state.saving,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: state.scanning || state.connecting
                  ? state.stop
                  : state.startScan,
              icon: Icon(
                state.scanning || state.connecting
                    ? Icons.stop
                    : Icons.bluetooth_searching,
              ),
              label: Text(
                state.scanning || state.connecting
                    ? 'Stop scan'
                    : 'Scan MorphoScan Nova',
              ),
            ),
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  state.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 20),
            if (latest != null)
              _MeasurementCard(
                measurement: latest,
                heading: 'Latest local measurement',
              ),
            const SizedBox(height: 20),
            Text(
              'Saved measurements',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (state.history.isEmpty)
              const Text(
                'No local measurements yet. Your scan data stays on this device.',
              ),
            for (final measurement in state.history)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _HistoryRow(measurement: measurement),
              ),
            const SizedBox(height: 24),
            Text(
              'Profile: ${state.profile.name}, ${state.profile.sex}, ${state.profile.heightCm.toStringAsFixed(1)} cm',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Profile name is the only profile field currently verified for BLE setup. Sex, height, and birth date are stored locally for calculations; their scale-packet encoding is not yet known, so they are not claimed to alter the scale firmware result.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Health Connect receives weight, body-fat percentage, and calculated fat-free mass. Impedance, BMI, muscle percentage, and visceral-fat score remain in local SQLite because Health Connect has no matching record types.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ];
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 880),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: content,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WeightHero extends StatelessWidget {
  final double? weight;
  final String status;
  final bool ready, working;
  const _WeightHero({
    this.weight,
    required this.status,
    required this.ready,
    required this.working,
  });
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            ready
                ? 'READY FOR FULL SCAN'
                : working
                ? 'CONNECTING'
                : 'LOCAL SCALE SCAN',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Text(
            weight == null ? '--.--' : weight!.toStringAsFixed(2),
            style: Theme.of(
              context,
            ).textTheme.displayLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text('kg', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Text(status, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class _MeasurementCard extends StatelessWidget {
  final RenphoMeasurement measurement;
  final String heading;
  const _MeasurementCard({required this.measurement, required this.heading});
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(heading, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _Metric(
                label: 'Body fat',
                value: '${measurement.bodyFatPercent.toStringAsFixed(1)}%',
              ),
              _Metric(
                label: 'Fat-free mass',
                value: '${measurement.fatFreeMassKg.toStringAsFixed(1)} kg',
              ),
              _Metric(
                label: 'Muscle',
                value: '${measurement.musclePercent.toStringAsFixed(1)}%',
              ),
              _Metric(
                label: 'Visceral score',
                value: '${measurement.visceralFat}',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Segment impedance (20 / 100 kHz)',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          Text(
            'Torso ${measurement.impedance['z20Body']!.toStringAsFixed(1)} / ${measurement.impedance['z100Body']!.toStringAsFixed(1)}   Arms ${measurement.impedance['z20HandL']!.toStringAsFixed(1)} / ${measurement.impedance['z20HandR']!.toStringAsFixed(1)}   Legs ${measurement.impedance['z20FootL']!.toStringAsFixed(1)} / ${measurement.impedance['z20FootR']!.toStringAsFixed(1)}',
          ),
        ],
      ),
    ),
  );
}

class _Metric extends StatelessWidget {
  final String label, value;
  const _Metric({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 130,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: Theme.of(context).textTheme.titleLarge),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}

class _HistoryRow extends StatelessWidget {
  final RenphoMeasurement measurement;
  const _HistoryRow({required this.measurement});
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.monitor_weight_outlined),
      title: Text(
        '${measurement.weightKg.toStringAsFixed(2)} kg  ${measurement.bodyFatPercent.toStringAsFixed(1)}% body fat',
      ),
      subtitle: Text(
        '${measurement.measuredAt.toLocal()}  BMI ${measurement.bmi.toStringAsFixed(1)}  Muscle ${measurement.musclePercent.toStringAsFixed(1)}%',
      ),
      trailing: Text(
        '${measurement.fatFreeMassKg.toStringAsFixed(1)} kg\nFFM',
        textAlign: TextAlign.end,
      ),
    ),
  );
}
