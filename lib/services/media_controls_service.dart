import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:dbus/dbus.dart';

enum MediaPlaybackStatus { playing, paused, stopped }

enum MediaButton { play, pause, stop, next, previous }

class MediaMetadata {
  final String title;
  final String? artist;
  final String? album;
  final Duration? duration;
  final List<MediaButton>? supportedButtons;

  const MediaMetadata({
    required this.title,
    this.artist,
    this.album,
    this.duration,
    this.supportedButtons,
  });
}

abstract class MediaControlsService {
  MediaControlsService._();

  static MediaControlsService? _instance;

  static MediaControlsService get instance {
    if (_instance == null) {
      _instance = _create();
      unawaited(_instance!.init());
    }
    return _instance!;
  }

  static MediaControlsService _create() {
    if (kIsWeb) return MediaControlsStubImpl();
    if (defaultTargetPlatform == TargetPlatform.windows || Platform.isWindows) {
      return MediaControlsWindowsImpl();
    }
    if (defaultTargetPlatform == TargetPlatform.linux || Platform.isLinux) {
      return MediaControlsLinuxImpl();
    }
    return MediaControlsStubImpl();
  }

  static void reset({MediaControlsService? override}) {
    if (override != null) {
      _instance = override;
    } else {
      _instance = null;
    }
  }

  Future<void> init();
  Future<void> updateMetadata(MediaMetadata metadata);
  Future<void> updatePlaybackStatus(MediaPlaybackStatus status);
  Future<void> updatePosition(Duration position);
  Future<void> clear();
  Stream<MediaButton> get buttonEvents;
  Future<void> dispose();
}

class MediaControlsStubImpl extends MediaControlsService {
  MediaControlsStubImpl() : super._();

  final StreamController<MediaButton> _controller =
      StreamController<MediaButton>.broadcast();

  @override
  Future<void> init() async {}

  @override
  Future<void> updateMetadata(MediaMetadata metadata) async {}

  @override
  Future<void> updatePlaybackStatus(MediaPlaybackStatus status) async {}

  @override
  Future<void> updatePosition(Duration position) async {}

  @override
  Future<void> clear() async {}

  @override
  Stream<MediaButton> get buttonEvents => _controller.stream;

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}

class MediaControlsWindowsImpl extends MediaControlsService {
  MediaControlsWindowsImpl() : super._();

  static const MethodChannel _channel = MethodChannel(
    'de.renier.tool_lab/media_controls',
  );

  final StreamController<MediaButton> _controller =
      StreamController<MediaButton>.broadcast();
  bool _disposed = false;

  @override
  Future<void> init() async {
    if (_disposed) return;
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onButton') {
      final button = _parseButton(call.arguments as String);
      if (button != null && !_controller.isClosed) {
        _controller.add(button);
      }
    }
  }

  static MediaButton? _parseButton(String name) {
    switch (name) {
      case 'play':
        return MediaButton.play;
      case 'pause':
        return MediaButton.pause;
      case 'stop':
        return MediaButton.stop;
      case 'next':
        return MediaButton.next;
      case 'previous':
        return MediaButton.previous;
    }
    return null;
  }

  @override
  Future<void> updateMetadata(MediaMetadata metadata) async {
    if (_disposed) return;
    try {
      await _channel.invokeMethod<void>('updateMetadata', {
        'title': metadata.title,
        if (metadata.artist != null) 'artist': metadata.artist,
        if (metadata.album != null) 'album': metadata.album,
        if (metadata.duration != null)
          'durationMs': metadata.duration!.inMilliseconds,
        if (metadata.supportedButtons != null)
          'supportedButtons': metadata.supportedButtons!
              .map((b) => b.name)
              .toList(),
      });
    } catch (e) {
      debugPrint('[$_logPrefix] updateMetadata failed: $e');
    }
  }

  @override
  Future<void> updatePlaybackStatus(MediaPlaybackStatus status) async {
    if (_disposed) return;
    try {
      await _channel.invokeMethod<void>('updatePlaybackStatus', status.name);
    } catch (e) {
      debugPrint('[$_logPrefix] updatePlaybackStatus failed: $e');
    }
  }

  @override
  Future<void> updatePosition(Duration position) async {
    if (_disposed) return;
    try {
      await _channel.invokeMethod<void>(
        'updatePosition',
        position.inMilliseconds,
      );
    } catch (e) {
      debugPrint('[$_logPrefix] updatePosition failed: $e');
    }
  }

  @override
  Future<void> clear() async {
    if (_disposed) return;
    try {
      await _channel.invokeMethod<void>('clear');
    } catch (e) {
      debugPrint('[$_logPrefix] clear failed: $e');
    }
  }

  @override
  Stream<MediaButton> get buttonEvents => _controller.stream;

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    try {
      await _channel.invokeMethod<void>('dispose');
    } catch (_) {}
    await _controller.close();
    _channel.setMethodCallHandler(null);
  }

  static const String _logPrefix = 'MediaControlsWindows';
}

class MediaControlsLinuxImpl extends MediaControlsService {
  MediaControlsLinuxImpl() : super._();

  final StreamController<MediaButton> _controller =
      StreamController<MediaButton>.broadcast();
  DBusClient? _client;
  MprisObject? _mprisObject;
  StreamSubscription<MediaButton>? _subscription;
  bool _disposed = false;

  @override
  Future<void> init() async {
    if (_disposed) return;
    try {
      _client = DBusClient.session();
      _mprisObject = MprisObject();
      _subscription = _mprisObject!.buttonEvents.listen((button) {
        if (!_controller.isClosed) {
          _controller.add(button);
        }
      });
      await _client!.registerObject(_mprisObject!);
      await _client!.requestName(
        'org.mpris.MediaPlayer2.toollab',
        flags: {DBusRequestNameFlag.replaceExisting},
      );
    } catch (e) {
      debugPrint('[$_logPrefix] D-Bus initialization failed: $e');
    }
  }

  @override
  Future<void> updateMetadata(MediaMetadata metadata) async {
    if (_disposed || _mprisObject == null) return;
    try {
      _mprisObject!.updateMetadata(metadata);
    } catch (e) {
      debugPrint('[$_logPrefix] updateMetadata failed: $e');
    }
  }

  @override
  Future<void> updatePlaybackStatus(MediaPlaybackStatus status) async {
    if (_disposed || _mprisObject == null) return;
    try {
      _mprisObject!.updatePlaybackStatus(status);
    } catch (e) {
      debugPrint('[$_logPrefix] updatePlaybackStatus failed: $e');
    }
  }

  @override
  Future<void> updatePosition(Duration position) async {
    if (_disposed || _mprisObject == null) return;
    try {
      _mprisObject!.updatePosition(position);
    } catch (e) {
      debugPrint('[$_logPrefix] updatePosition failed: $e');
    }
  }

  @override
  Future<void> clear() async {
    if (_disposed || _mprisObject == null) return;
    try {
      _mprisObject!.clear();
    } catch (e) {
      debugPrint('[$_logPrefix] clear failed: $e');
    }
  }

  @override
  Stream<MediaButton> get buttonEvents => _controller.stream;

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    try {
      await _subscription?.cancel();
      if (_client != null) {
        await _client!.releaseName('org.mpris.MediaPlayer2.toollab');
        if (_mprisObject != null) {
          await _client!.unregisterObject(_mprisObject!);
        }
        await _client!.close();
      }
      await _mprisObject?.close();
    } catch (_) {}
    await _controller.close();
  }

  static const String _logPrefix = 'MediaControlsLinux';
}

class MprisObject extends DBusObject {
  MprisObject() : super(DBusObjectPath('/org/mpris/MediaPlayer2'));

  String playbackStatus = 'Stopped';
  double rate = 1.0;
  Map<String, DBusValue> metadata = {};
  double volume = 1.0;
  int positionUs = 0;
  List<MediaButton>? supportedButtons;

  final StreamController<MediaButton> _controller =
      StreamController<MediaButton>.broadcast();

  Stream<MediaButton> get buttonEvents => _controller.stream;

  bool get _canGoNext => supportedButtons?.contains(MediaButton.next) ?? true;
  bool get _canGoPrevious =>
      supportedButtons?.contains(MediaButton.previous) ?? true;
  bool get _canPlay => supportedButtons?.contains(MediaButton.play) ?? true;
  bool get _canPause => supportedButtons?.contains(MediaButton.pause) ?? true;

  void updatePlaybackStatus(MediaPlaybackStatus status) {
    final oldStatus = playbackStatus;
    switch (status) {
      case MediaPlaybackStatus.playing:
        playbackStatus = 'Playing';
        break;
      case MediaPlaybackStatus.paused:
        playbackStatus = 'Paused';
        break;
      case MediaPlaybackStatus.stopped:
        playbackStatus = 'Stopped';
        break;
    }
    if (oldStatus != playbackStatus) {
      emitPropertiesChanged(
        'org.mpris.MediaPlayer2.Player',
        changedProperties: {'PlaybackStatus': DBusString(playbackStatus)},
      );
    }
  }

  void updateMetadata(MediaMetadata meta) {
    final oldGoNext = _canGoNext;
    final oldGoPrev = _canGoPrevious;
    final oldPlay = _canPlay;
    final oldPause = _canPause;

    supportedButtons = meta.supportedButtons;

    final newMetadata = {
      'mpris:trackid': DBusObjectPath('/org/mpris/MediaPlayer2/track/0'),
      'xesam:title': DBusString(meta.title),
      if (meta.artist != null) 'xesam:artist': DBusArray.string([meta.artist!]),
      if (meta.album != null) 'xesam:album': DBusString(meta.album!),
      if (meta.duration != null)
        'mpris:length': DBusInt64(meta.duration!.inMicroseconds),
    };
    metadata = newMetadata;

    final changed = <String, DBusValue>{
      'Metadata': DBusDict.stringVariant(metadata),
    };
    if (oldGoNext != _canGoNext) changed['CanGoNext'] = DBusBoolean(_canGoNext);
    if (oldGoPrev != _canGoPrevious) {
      changed['CanGoPrevious'] = DBusBoolean(_canGoPrevious);
    }
    if (oldPlay != _canPlay) changed['CanPlay'] = DBusBoolean(_canPlay);
    if (oldPause != _canPause) changed['CanPause'] = DBusBoolean(_canPause);

    emitPropertiesChanged(
      'org.mpris.MediaPlayer2.Player',
      changedProperties: changed,
    );
  }

  void updatePosition(Duration position) {
    positionUs = position.inMicroseconds;
  }

  void clear() {
    metadata = {};
    playbackStatus = 'Stopped';
    supportedButtons = null;
    emitPropertiesChanged(
      'org.mpris.MediaPlayer2.Player',
      changedProperties: {
        'Metadata': DBusDict.stringVariant({}),
        'PlaybackStatus': DBusString('Stopped'),
        'CanGoNext': DBusBoolean(true),
        'CanGoPrevious': DBusBoolean(true),
        'CanPlay': DBusBoolean(true),
        'CanPause': DBusBoolean(true),
      },
    );
  }

  Future<void> close() async {
    await _controller.close();
  }

  @override
  Future<DBusMethodResponse> getProperty(
    String interface,
    String name, {
    DBusSignature? signature,
  }) async {
    if (interface == 'org.mpris.MediaPlayer2') {
      switch (name) {
        case 'CanQuit':
          return DBusGetPropertyResponse(DBusBoolean(false));
        case 'CanRaise':
          return DBusGetPropertyResponse(DBusBoolean(false));
        case 'HasTrackList':
          return DBusGetPropertyResponse(DBusBoolean(false));
        case 'Identity':
          return DBusGetPropertyResponse(DBusString('ToolLab'));
        case 'SupportedUriSchemes':
          return DBusGetPropertyResponse(DBusArray.string([]));
        case 'SupportedMimeTypes':
          return DBusGetPropertyResponse(DBusArray.string([]));
      }
    } else if (interface == 'org.mpris.MediaPlayer2.Player') {
      switch (name) {
        case 'PlaybackStatus':
          return DBusGetPropertyResponse(DBusString(playbackStatus));
        case 'Rate':
          return DBusGetPropertyResponse(DBusDouble(rate));
        case 'Metadata':
          return DBusGetPropertyResponse(DBusDict.stringVariant(metadata));
        case 'Volume':
          return DBusGetPropertyResponse(DBusDouble(volume));
        case 'Position':
          return DBusGetPropertyResponse(DBusInt64(positionUs));
        case 'MinimumRate':
          return DBusGetPropertyResponse(DBusDouble(1.0));
        case 'MaximumRate':
          return DBusGetPropertyResponse(DBusDouble(1.0));
        case 'CanGoNext':
          return DBusGetPropertyResponse(DBusBoolean(_canGoNext));
        case 'CanGoPrevious':
          return DBusGetPropertyResponse(DBusBoolean(_canGoPrevious));
        case 'CanPlay':
          return DBusGetPropertyResponse(DBusBoolean(_canPlay));
        case 'CanPause':
          return DBusGetPropertyResponse(DBusBoolean(_canPause));
        case 'CanSeek':
          return DBusGetPropertyResponse(DBusBoolean(false));
        case 'CanControl':
          return DBusGetPropertyResponse(DBusBoolean(true));
      }
    }
    return DBusMethodErrorResponse.unknownProperty();
  }

  @override
  Future<DBusMethodResponse> getAllProperties(String interface) async {
    if (interface == 'org.mpris.MediaPlayer2') {
      return DBusGetAllPropertiesResponse({
        'CanQuit': DBusBoolean(false),
        'CanRaise': DBusBoolean(false),
        'HasTrackList': DBusBoolean(false),
        'Identity': DBusString('ToolLab'),
        'SupportedUriSchemes': DBusArray.string([]),
        'SupportedMimeTypes': DBusArray.string([]),
      });
    } else if (interface == 'org.mpris.MediaPlayer2.Player') {
      return DBusGetAllPropertiesResponse({
        'PlaybackStatus': DBusString(playbackStatus),
        'Rate': DBusDouble(rate),
        'Metadata': DBusDict.stringVariant(metadata),
        'Volume': DBusDouble(volume),
        'Position': DBusInt64(positionUs),
        'MinimumRate': DBusDouble(1.0),
        'MaximumRate': DBusDouble(1.0),
        'CanGoNext': DBusBoolean(_canGoNext),
        'CanGoPrevious': DBusBoolean(_canGoPrevious),
        'CanPlay': DBusBoolean(_canPlay),
        'CanPause': DBusBoolean(_canPause),
        'CanSeek': DBusBoolean(false),
        'CanControl': DBusBoolean(true),
      });
    }
    return DBusGetAllPropertiesResponse({});
  }

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) async {
    if (methodCall.interface == 'org.mpris.MediaPlayer2') {
      if (methodCall.name == 'Raise' || methodCall.name == 'Quit') {
        return DBusMethodSuccessResponse([]);
      }
    } else if (methodCall.interface == 'org.mpris.MediaPlayer2.Player') {
      switch (methodCall.name) {
        case 'Next':
          if (_canGoNext) {
            _controller.add(MediaButton.next);
          }
          return DBusMethodSuccessResponse([]);
        case 'Previous':
          if (_canGoPrevious) {
            _controller.add(MediaButton.previous);
          }
          return DBusMethodSuccessResponse([]);
        case 'Pause':
          if (_canPause) {
            _controller.add(MediaButton.pause);
          }
          return DBusMethodSuccessResponse([]);
        case 'PlayPause':
          if (playbackStatus == 'Playing') {
            if (_canPause) _controller.add(MediaButton.pause);
          } else {
            if (_canPlay) _controller.add(MediaButton.play);
          }
          return DBusMethodSuccessResponse([]);
        case 'Stop':
          _controller.add(MediaButton.stop);
          return DBusMethodSuccessResponse([]);
        case 'Play':
          if (_canPlay) {
            _controller.add(MediaButton.play);
          }
          return DBusMethodSuccessResponse([]);
      }
    }
    return DBusMethodErrorResponse.unknownMethod();
  }
}
