import 'package:material_ui/material_ui.dart';
import 'package:tool_lab/widgets/tool_layout.dart';

import 'config.dart';

class WeatherPage extends StatelessWidget {
  const WeatherPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ToolLayout(
      title: WeatherTool.config.name,
      child: const SizedBox.shrink(),
    );
  }
}
