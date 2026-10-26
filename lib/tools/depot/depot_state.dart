import 'package:flutter/foundation.dart';

enum DepotTab { overview, dividends, activities, pdfImport }

class DepotState extends ChangeNotifier {
  DepotTab _tab = DepotTab.overview;

  DepotTab get tab => _tab;

  void setTab(DepotTab tab) {
    if (tab == _tab) return;
    _tab = tab;
    notifyListeners();
  }
}
