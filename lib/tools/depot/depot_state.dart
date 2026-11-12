import 'package:flutter/foundation.dart';
import 'package:tool_lab/helpers/debug_log.dart';

import 'depot_details_link.dart';
import 'depot_store.dart';

enum DepotTab {
  overview,
  allocation,
  dividends,
  activities,
  wishlist,
  pdfImport,
}

class DepotState extends ChangeNotifier {
  DepotTab _tab = DepotTab.overview;
  final Map<DepotDetailsLinkKind, String> _detailsUrlTemplates = {
    for (final kind in DepotDetailsLinkKind.values) kind: kind.defaultTemplate,
  };
  bool _disposed = false;
  late final Future<void> loaded;

  DepotState() {
    loaded = _loadDetailsUrlTemplates();
  }

  DepotTab get tab => _tab;

  String detailsUrlTemplate(DepotDetailsLinkKind kind) =>
      _detailsUrlTemplates[kind]!;

  void setTab(DepotTab tab) {
    if (tab == _tab) return;
    _tab = tab;
    notifyListeners();
  }

  Future<void> _loadDetailsUrlTemplates() async {
    try {
      for (final kind in DepotDetailsLinkKind.values) {
        final stored = await DepotStore.instance.detailsUrlTemplate(kind);
        if (stored != null) _detailsUrlTemplates[kind] = stored;
      }
      if (!_disposed) notifyListeners();
    } catch (e) {
      errorLog('[DepotState] Loading details URLs failed: $e');
    }
  }

  Future<void> setDetailsUrlTemplate(
    DepotDetailsLinkKind kind,
    String template,
  ) async {
    if (template == _detailsUrlTemplates[kind]) return;
    _detailsUrlTemplates[kind] = template;
    notifyListeners();
    try {
      await DepotStore.instance.setDetailsUrlTemplate(kind, template);
    } catch (e) {
      errorLog('[DepotState] Saving details URL failed: $e');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
