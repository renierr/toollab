// ignore: deprecated_member_use
import 'package:flutter/material.dart' as legacy;
import 'package:flutter_localizations/flutter_localizations.dart' as legacy;
import 'package:material_ui/material_ui.dart';
import 'package:tool_lab/theme/theme.dart';

/// Gives packages still on `package:flutter/material.dart` the full [AppTheme]
/// and the app's localizations, which they cannot read from material_ui.
class LegacyMaterialBridge extends StatelessWidget {
  final Widget child;

  const LegacyMaterialBridge({super.key, required this.child});

  static final legacy.ThemeData _light = _theme(Brightness.light);
  static final legacy.ThemeData _dark = _theme(Brightness.dark);

  // Mirrors AppTheme.light / AppTheme.dark.
  static legacy.ThemeData _theme(Brightness brightness) => legacy.ThemeData(
    useMaterial3: true,
    colorSchemeSeed: AppTheme.accentBlue,
    brightness: brightness,
    focusColor: AppTheme.focusColor,
    appBarTheme: const legacy.AppBarTheme(centerTitle: true, elevation: 0),
    cardTheme: legacy.CardThemeData(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return legacy.Theme(
      data: dark ? _dark : _light,
      child: Localizations.override(
        context: context,
        delegates: const [
          // ignore: deprecated_member_use
          legacy.GlobalCupertinoLocalizations.delegate,
          // ignore: deprecated_member_use
          legacy.GlobalMaterialLocalizations.delegate,
        ],
        child: child,
      ),
    );
  }
}
