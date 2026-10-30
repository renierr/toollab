import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/services/tool_lock_controller.dart';

class _AndroidController extends ToolLockController {
  _AndroidController() : super(toolId: 'test', envelopeSetting: 'envelope');

  @override
  bool get supportsBiometric => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('de.renier.tool_lab/tool_biometric_storage');
  final calls = <MethodCall>[];
  String? storedPassword;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.instance.dbPathOverride = inMemoryDatabasePath;
  });
  setUp(() async {
    await DatabaseService.instance.close();
    FlutterSecureStorage.setMockInitialValues({});
    calls.clear();
    storedPassword = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          switch (call.method) {
            case 'write':
              storedPassword = (call.arguments as Map)['value'] as String;
              return null;
            case 'read':
              return storedPassword;
            case 'delete':
              storedPassword = null;
              return null;
          }
          throw MissingPluginException();
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  tearDownAll(() async => DatabaseService.instance.close());

  test(
    'biometric timeout persists and is passed to the native storage',
    () async {
      final controller = _AndroidController();
      addTearDown(() {
        controller.lock();
        controller.dispose();
      });
      await controller.initialize();
      await controller.setup('correct password', (key, envelope) async {
        await DatabaseService.instance.setSetting('test', 'envelope', envelope);
      });
      await controller.setBiometric(true);
      expect((calls.single.arguments as Map)['minutes'], 5);
      final options = (calls.single.arguments as Map)['options'] as Map;
      expect(options['storageNamespace'], 'tool_lock_test');
      expect(options['enforceBiometrics'], 'true');
      await controller.setBiometricTimeout(15);
      controller.lock();
      expect(await controller.unlockBiometric(), isTrue);
      expect((calls.last.arguments as Map)['minutes'], 15);
      await controller.setBiometric(false);
      expect(calls.last.method, 'delete');

      final reloaded = _AndroidController();
      addTearDown(() {
        reloaded.lock();
        reloaded.dispose();
      });
      await reloaded.initialize();
      expect(reloaded.biometricTimeoutMinutes, 15);
      await expectLater(reloaded.setBiometricTimeout(2), throwsArgumentError);
    },
  );
}
