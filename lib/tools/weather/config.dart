import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';

import 'radar_frame_store.dart';
import 'weather_background.dart';
import 'weather_page.dart';
import 'weather_radar_state.dart';
import 'weather_state.dart';

class WeatherTool {
  WeatherTool._();

  static ToolModel get config => ToolModel(
    id: 'weather',
    name: 'Weather',
    description: 'DWD forecast, live measurements, warnings and rain radar',
    icon: Icons.wb_cloudy_outlined,
    route: '/weather',
    accentColor: AppTheme.accentBlue,
    sectionId: 'utilities',
    androidProcessIsolated: true,
    nameL10n: (l10n) => l10n.toolNameWeather,
    descriptionL10n: (l10n) => l10n.toolDescWeather,
    createPage: (_) => const WeatherPage(),
    onClose: (context) {
      context.read<WeatherState>().release();
      context.read<WeatherRadarState>().release();
    },
    stateProviders: () => [
      ChangeNotifierProvider<WeatherState>(create: (_) => WeatherState()),
      ChangeNotifierProvider<WeatherRadarState>(
        create: (_) => WeatherRadarState(lasting: RadarLastingStore()),
      ),
    ],
    backgroundTasks: () => [WeatherBackground.task],
  );
}
