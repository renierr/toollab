import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'mixer.dart';
import 'module.dart';

class RenderRowEvent {
  final int order;
  final int row;
  final List<bool> activeChannels;

  const RenderRowEvent({
    required this.order,
    required this.row,
    required this.activeChannels,
  });
}

class ChiptuneRenderWorker {
  Isolate? _isolate;
  SendPort? _sendPort;
  ReceivePort? _receivePort;

  int _nextRequestId = 1;
  final Map<int, Completer<Float32List>> _pending =
      <int, Completer<Float32List>>{};

  final StreamController<RenderRowEvent> _rowController =
      StreamController<RenderRowEvent>.broadcast();
  final StreamController<void> _endedController =
      StreamController<void>.broadcast();

  Stream<RenderRowEvent> get onRow => _rowController.stream;
  Stream<void> get onEnded => _endedController.stream;

  bool get isRunning => _sendPort != null;

  Future<void> start({
    required WorkletModule module,
    required int sampleRate,
    required bool looping,
    required double volume,
  }) async {
    await stop();

    final ReceivePort readyPort = ReceivePort();
    _isolate = await Isolate.spawn(_renderWorkerEntry, readyPort.sendPort);
    final SendPort workerPort = await readyPort.first as SendPort;

    final ReceivePort receivePort = ReceivePort();
    workerPort.send({'cmd': 'attachMainPort', 'port': receivePort.sendPort});

    _sendPort = workerPort;
    _receivePort = receivePort;
    receivePort.listen(_handleMessage);

    _sendPort?.send({
      'cmd': 'init',
      'module': workletModuleToMessage(module),
      'sampleRate': sampleRate,
      'looping': looping,
      'volume': volume,
    });
  }

  Future<Float32List> render(int frames) {
    final SendPort? port = _sendPort;
    if (port == null) {
      return Future<Float32List>.value(Float32List(frames * 2));
    }

    final int id = _nextRequestId++;
    final Completer<Float32List> completer = Completer<Float32List>();
    _pending[id] = completer;
    port.send({'cmd': 'render', 'id': id, 'frames': frames});
    return completer.future;
  }

  void seek(int order, int row) {
    _sendPort?.send({'cmd': 'seek', 'order': order, 'row': row});
  }

  void setVolume(double volume) {
    _sendPort?.send({'cmd': 'setVolume', 'volume': volume});
  }

  void setSpeed(int speed) {
    _sendPort?.send({'cmd': 'setSpeed', 'speed': speed});
  }

  void setLooping(bool looping) {
    _sendPort?.send({'cmd': 'setLooping', 'looping': looping});
  }

  Future<void> stop() async {
    _sendPort?.send({'cmd': 'stop'});
    _sendPort = null;

    _receivePort?.close();
    _receivePort = null;

    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;

    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.complete(Float32List(0));
      }
    }
    _pending.clear();
  }

  Future<void> dispose() async {
    await stop();
    await _rowController.close();
    await _endedController.close();
  }

  void _handleMessage(dynamic message) {
    if (message is! Map) return;
    final String? type = message['type'] as String?;
    if (type == null) return;

    switch (type) {
      case 'pcm':
        final int id = (message['id'] as num).toInt();
        final dynamic rawData = message['data'];
        Float32List pcm;
        if (rawData is Float32List) {
          pcm = rawData;
        } else if (rawData is Uint8List) {
          pcm = rawData.buffer.asFloat32List(
            rawData.offsetInBytes,
            rawData.lengthInBytes ~/ Float32List.bytesPerElement,
          );
        } else if (rawData is List) {
          pcm = Float32List.fromList(
            rawData.cast<num>().map((e) => e.toDouble()).toList(),
          );
        } else {
          pcm = Float32List(0);
        }
        final completer = _pending.remove(id);
        if (completer != null && !completer.isCompleted) {
          completer.complete(pcm);
        }
        break;
      case 'row':
        _rowController.add(
          RenderRowEvent(
            order: (message['order'] as num).toInt(),
            row: (message['row'] as num).toInt(),
            activeChannels: (message['active'] as List<dynamic>).cast<bool>(),
          ),
        );
        break;
      case 'ended':
        _endedController.add(null);
        break;
      default:
        break;
    }
  }
}

void _renderWorkerEntry(SendPort initPort) {
  final ReceivePort port = ReceivePort();
  initPort.send(port.sendPort);

  final ChiptuneMixer mixer = ChiptuneMixer();
  SendPort? mainPort;

  mixer.onRow = (order, row, active, _) {
    mainPort?.send({
      'type': 'row',
      'order': order,
      'row': row,
      'active': active,
    });
  };

  mixer.onEnded = () {
    mainPort?.send({'type': 'ended'});
  };

  port.listen((dynamic message) {
    if (message is! Map) return;
    final String? cmd = message['cmd'] as String?;
    if (cmd == null) return;

    switch (cmd) {
      case 'attachMainPort':
        mainPort = message['port'] as SendPort;
        break;
      case 'init':
        final WorkletModule module = workletModuleFromMessage(
          message['module'] as Map<Object?, Object?>,
        );
        mixer.loadAndPlay(
          module,
          (message['sampleRate'] as num).toInt(),
          looping: message['looping'] == true,
        );
        mixer.setMasterVolume((message['volume'] as num).toDouble());
        break;
      case 'render':
        final int id = (message['id'] as num).toInt();
        final int frames = (message['frames'] as num).toInt();
        final Float32List out = Float32List(frames * 2);
        mixer.render(out, frames);
        mainPort?.send({'type': 'pcm', 'id': id, 'data': out});
        break;
      case 'seek':
        mixer.seek(
          (message['order'] as num).toInt(),
          (message['row'] as num).toInt(),
        );
        break;
      case 'setVolume':
        mixer.setMasterVolume((message['volume'] as num).toDouble());
        break;
      case 'setSpeed':
        mixer.setSpeed((message['speed'] as num).toInt());
        break;
      case 'setLooping':
        mixer.setLooping(message['looping'] == true);
        break;
      case 'stop':
        mixer.stop();
        break;
      default:
        break;
    }
  });
}
