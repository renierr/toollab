import 'package:material_ui/material_ui.dart';
import 'package:pdfrx/pdfrx.dart';

enum PdfLayoutMode {
  vertical(SequentialPagesLayout()),
  horizontal(SequentialPagesLayout(scrollDirection: Axis.horizontal)),
  doublePage(FacingPagesLayout(coverPage: false));

  final PdfPageLayoutStrategy strategy;

  const PdfLayoutMode(this.strategy);
}
