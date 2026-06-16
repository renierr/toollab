import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';

import 'signatures_page.dart';
import 'signatures_state.dart';
import 'signatures_sync_delegate.dart';

class SignaturesTool {
  SignaturesTool._();

  static ToolModel get config => ToolModel(
    id: 'signatures',
    name: 'Signature Creator',
    description: 'Draw signatures and export them as transparent PNG or SVG',
    icon: Icons.draw_outlined,
    route: '/signatures',
    accentColor: AppTheme.accentBlue,
    sectionId: 'utilities',
    fileExtensions: ['png', 'svg'],
    createPage: (_) => const SignaturesPage(),
    syncDelegateFactory: SignaturesSyncDelegate.new,
    stateProviders: () => [
      ChangeNotifierProvider<SignaturesState>(create: (_) => SignaturesState()),
    ],
  );
}
