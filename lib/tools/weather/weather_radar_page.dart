import 'package:material_ui/material_ui.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/tool_layout.dart';

import 'widgets/weather_radar_layer_button.dart';
import 'widgets/weather_radar_view.dart';

class WeatherRadarPage extends StatelessWidget {
  const WeatherRadarPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ToolLayout(
      title: l10n.weatherRadarTitle,
      leading: const BackButton(),
      actions: const [WeatherRadarLayerButton()],
      child: const WeatherRadarView(showLayerButton: false),
    );
  }
}
