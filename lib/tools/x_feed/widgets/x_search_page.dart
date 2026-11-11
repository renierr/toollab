import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import 'x_back_key.dart';
import 'x_search_view.dart';

class XSearchPage extends StatelessWidget {
  final String query;

  const XSearchPage({super.key, required this.query});

  static Future<void> open(BuildContext context, String query) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => XSearchPage(query: query)));

  @override
  Widget build(BuildContext context) {
    return XBackKey(
      child: Scaffold(
        appBar: AppBar(title: Text(AppLocalizations.of(context).commonSearch)),
        body: XSearchView(initialQuery: query),
      ),
    );
  }
}
