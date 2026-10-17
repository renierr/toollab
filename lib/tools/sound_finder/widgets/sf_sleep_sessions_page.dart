import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';

import '../sound_finder_state.dart';

class SfSleepSessionsPage extends StatefulWidget {
  const SfSleepSessionsPage({super.key});

  @override
  State<SfSleepSessionsPage> createState() => _SfSleepSessionsPageState();
}

class _SfSleepSessionsPageState extends State<SfSleepSessionsPage> {
  List<SleepSession> _sessions = const [];
  bool _loading = true;
  String? _playingPath;
  SoundHandle? _handle;
  AudioSource? _source;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await SoundFinderState.listSleepSessions();
    if (!mounted) return;
    setState(() {
      _sessions = s;
      _loading = false;
    });
  }

  Future<void> _play(String path) async {
    if (_playingPath == path) {
      await _stop();
      return;
    }
    await _stop();
    if (!SoLoud.instance.isInitialized) {
      await SoLoud.instance.init();
    }
    try {
      final source = await SoLoud.instance.loadFile(path);
      final handle = SoLoud.instance.play(source);
      _source = source;
      _handle = handle;
      _playingPath = path;
      setState(() {});
      source.soundEvents.listen((e) {
        if (e.handle == handle && e.event == SoundEventType.handleIsNoMoreValid) {
          _stop();
        }
      });
    } catch (e) {
      debugPrint('play failed: $e');
    }
  }

  Future<void> _stop() async {
    final h = _handle;
    final s = _source;
    _handle = null;
    _source = null;
    _playingPath = null;
    if (h != null) await SoLoud.instance.stop(h);
    if (s != null) SoLoud.instance.disposeSource(s);
    if (mounted) setState(() {});
  }

  Future<void> _deleteSession(SleepSession session) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete session?'),
        content: Text('Delete ${session.chunks.length} chunks?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await SoundFinderState.deleteSleepSession(session.path);
    await _load();
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sleep Sessions')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
              ? const Center(child: Text('No sessions yet.'))
              : ListView.builder(
                  itemCount: _sessions.length,
                  itemBuilder: (context, i) {
                    final s = _sessions[i];
                    return ExpansionTile(
                      title: Text(s.name),
                      subtitle: Text('${s.chunks.length} chunks'),
                      children: [
                        ...s.chunks.map((f) {
                          final name = f.path.split(Platform.pathSeparator).last;
                          return ListTile(
                            title: Text(name),
                            trailing: Wrap(
                              children: [
                                IconButton(
                                  icon: Icon(_playingPath == f.path
                                      ? Icons.stop_outlined
                                      : Icons.play_arrow_outlined),
                                  onPressed: () => _play(f.path),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.save_alt_outlined),
                                  onPressed: () => FileSaveHelper.saveFileFromPath(
                                    context: context,
                                    suggestedName: name,
                                    sourcePath: f.path,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: TextButton.icon(
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Delete session'),
                            onPressed: () => _deleteSession(s),
                          ),
                        ),
                      ],
                    );
                  },
                ),
    );
  }
}