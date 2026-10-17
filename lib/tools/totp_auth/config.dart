import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';

import 'totp_auth_page.dart';
import 'totp_auth_state.dart';

class TotpAuthTool {
  TotpAuthTool._();

  static ToolModel get config => ToolModel(
        id: 'totp-auth',
        name: 'TOTP Authenticator',
        description: 'Two-factor authentication codes',
        icon: Icons.security_outlined,
        route: '/totp-auth',
        accentColor: AppTheme.accentPurple,
        sectionId: 'utilities',
        nameL10n: (l10n) => l10n.toolNameTotpAuth,
        descriptionL10n: (l10n) => l10n.toolDescTotpAuth,
        createPage: (_) => const TotpAuthPage(),
        stateProviders: () => [
          ChangeNotifierProvider<TotpAuthState>(create: (_) => TotpAuthState()),
        ],
        syncDelegateFactory: () => TotpAuthState(),
      );
}
