import 'package:material_ui/material_ui.dart';
import 'package:tool_lab/widgets/responsive_layout.dart';

import 'trimz_section_title.dart';
import 'trimz_series_card.dart';

/// A titled row of cards that scrolls sideways.
class TrimzRail extends StatelessWidget {
  final String title;
  final int itemCount;
  final Widget Function(BuildContext context, int index, double width)
  itemBuilder;

  const TrimzRail({
    super.key,
    required this.title,
    required this.itemCount,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.isCompact ? 200.0 : 250.0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TrimzSectionTitle(title: title),
            SizedBox(
              height: TrimzSeriesCard.heightFor(context, width),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: itemCount,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) => SizedBox(
                  width: width,
                  child: itemBuilder(context, index, width),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
