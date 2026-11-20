import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_page_state.dart';

import '../weather_state.dart';
import 'weather_forecast_view.dart';

/// Swipe between places on narrow screens.
class WeatherLocationPager extends StatefulWidget {
  const WeatherLocationPager({super.key});

  @override
  State<WeatherLocationPager> createState() => _WeatherLocationPagerState();
}

class _WeatherLocationPagerState extends State<WeatherLocationPager>
    with DisposeCleanup {
  PageController? _controller;

  @override
  void initState() {
    super.initState();
    onDispose(() => _controller?.dispose());
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<WeatherState>();
    final locations = state.locations;
    final index = locations
        .indexWhere((l) => l.id == state.selected?.id)
        .clamp(0, locations.length - 1);
    final controller = _controller ??= PageController(initialPage: index);
    if (controller.hasClients && controller.page?.round() != index) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (controller.hasClients) controller.jumpToPage(index);
      });
    }
    final theme = Theme.of(context);
    return Stack(
      children: [
        PageView.builder(
          controller: controller,
          itemCount: locations.length,
          onPageChanged: (i) => state.select(locations[i].id!),
          itemBuilder: (context, i) =>
              WeatherForecastView(locationId: locations[i].id!),
        ),
        if (locations.length > 1)
          Positioned(
            left: 0,
            right: 0,
            bottom: 8,
            child: IgnorePointer(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < locations.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == index ? 18 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: i == index
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface.withValues(
                                alpha: .25,
                              ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
