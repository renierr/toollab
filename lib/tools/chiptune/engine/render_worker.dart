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
    required int chunkFrames,
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
      'chunkFrames': chunkFrames,
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

  void setStereoWidth(double stereoWidth) {
    _sendPort?.send({'cmd': 'setStereoWidth', 'stereoWidth': stereoWidth});
  }

  void setInterpolation(int mode) {
    _sendPort?.send({'cmd': 'setInterpolation', 'mode': mode});
  }

  void setPreAmp(double value) {
    _sendPort?.send({'cmd': 'setPreAmp', 'value': value});
  }

  void setAmigaFilter(int mode) {
    _sendPort?.send({'cmd': 'setAmigaFilter', 'mode': mode});
  }

  void setRampStep(double value) {
    _sendPort?.send({'cmd': 'setRampStep', 'value': value});
  }

  void setModSeparation(double value) {
    _sendPort?.send({'cmd': 'setModSeparation', 'value': value});
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
        } else if (rawData is TransferableTypedData) {
          final ByteData bytes = rawData.materialize().asByteData();
          pcm = bytes.buffer.asFloat32List(
            bytes.offsetInBytes,
            bytes.lengthInBytes ~/ Float32List.bytesPerElement,
          );
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
  int chunkFrames = 4096;
  final List<TransferableTypedData> pcmQueue = <TransferableTypedData>[];

  void refillQueue() {
    if (mixer.mod == null) return;
    while (pcmQueue.length < 10) {
      final Float32List out = Float32List(chunkFrames * 2);
      mixer.render(out, chunkFrames);
      final Uint8List bytes = out.buffer.asUint8List();
      pcmQueue.add(TransferableTypedData.fromList([bytes]));
      if (!mixer.playing) {
        break;
      }
    }
  }

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
        chunkFrames = (message['chunkFrames'] as num).toInt();
        mixer.loadAndPlay(
          module,
          (message['sampleRate'] as num).toInt(),
          looping: message['looping'] == true,
        );
        mixer.setMasterVolume((message['volume'] as num).toDouble());
        pcmQueue.clear();
        refillQueue();
        break;
      case 'render':
        final int id = (message['id'] as num).toInt();
        final int frames = (message['frames'] as num).toInt();
        if (frames != chunkFrames) {
          chunkFrames = frames;
          pcmQueue.clear();
        }
        if (pcmQueue.isEmpty) {
          refillQueue();
        }
        if (pcmQueue.isNotEmpty) {
          final TransferableTypedData chunk = pcmQueue.removeAt(0);
          mainPort?.send({'type': 'pcm', 'id': id, 'data': chunk});
        } else {
          mainPort?.send({
            'type': 'pcm',
            'id': id,
            'data': TransferableTypedData.fromList([
              Uint8List(chunkFrames * 2 * Float32List.bytesPerElement),
            ]),
          });
        }
        refillQueue();
        break;
      case 'seek':
        mixer.seek(
          (message['order'] as num).toInt(),
          (message['row'] as num).toInt(),
        );
        pcmQueue.clear();
        refillQueue();
        break;
      case 'setVolume':
        mixer.setMasterVolume((message['volume'] as num).toDouble());
        break;
      case 'setStereoWidth':
        mixer.stereoWidth = (message['stereoWidth'] as num).toDouble();
        pcmQueue.clear();
        refillQueue();
        break;
      case 'setInterpolation':
        mixer.interpolation =
            ChiptuneInterpolation.values[(message['mode'] as num).toInt()];
        pcmQueue.clear();
        refillQueue();
        break;
      case 'setPreAmp':
        mixer.preAmp = (message['value'] as num).toDouble();
        pcmQueue.clear();
        refillQueue();
        break;
      case 'setAmigaFilter':
        mixer.amigaFilterMode =
            ChiptuneAmigaFilter.values[(message['mode'] as num).toInt()];
        pcmQueue.clear();
        refillQueue();
        break;
      case 'setRampStep':
        mixer.rampStep = (message['value'] as num).toDouble();
        pcmQueue.clear();
        refillQueue();
        break;
      case 'setModSeparation':
        mixer.setModSeparation((message['value'] as num).toDouble());
        pcmQueue.clear();
        refillQueue();
        break;
      case 'setSpeed':
        mixer.setSpeed((message['speed'] as num).toInt());
        pcmQueue.clear();
        refillQueue();
        break;
      case 'setLooping':
        mixer.setLooping(message['looping'] == true);
        break;
      case 'stop':
        mixer.stop();
        pcmQueue.clear();
        break;
      default:
        break;
    }
  });
}
