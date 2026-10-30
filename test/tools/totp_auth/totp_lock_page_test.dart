import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/services/settings_service.dart';
import 'package:tool_lab/tools/totp_auth/totp_account.dart';
import 'package:tool_lab/tools/totp_auth/totp_auth_page.dart';
import 'package:tool_lab/tools/totp_auth/totp_auth_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.instance.dbPathOverride = inMemoryDatabasePath;
  });
  setUp(() async {
    await DatabaseService.instance.close();
    FlutterSecureStorage.setMockInitialValues({});
  });
  tearDownAll(() async => DatabaseService.instance.close());

  testWidgets('backgrounding closes sensitive dialogs and locks the page', (
    tester,
  ) async {
    late TotpAuthState state;
    late AppState appState;
    await tester.runAsync(() async {
      state = TotpAuthState();
      await state.ready;
      await state.setupVault('shared password');
      await state.addAccount(
        TotpAccount.newAccount(
          issuer: 'Secret service',
          accountName: 'user',
          secret: 'JBSWY3DPEHPK3PXP',
        ),
      );
      appState = AppState(await SettingsService.init());
    });
    final router = GoRouter(
      routes: [GoRoute(path: '/', builder: (_, _) => const TotpAuthPage())],
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: appState),
          ChangeNotifierProvider.value(value: state),
        ],
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Secret service'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(state.accounts, isEmpty);
    expect(state.hasSyncPassword, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('Secret service'), findsNothing);
    expect(find.text('Unlock tool'), findsOneWidget);
    expect(state.accounts, isEmpty);
    expect(state.hasSyncPassword, isFalse);
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    state.dispose();
    appState.dispose();
    expect(tester.takeException(), isNull);
  });
}
