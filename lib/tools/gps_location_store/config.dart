import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';

import 'gps_location_store_page.dart';
import 'gps_location_store_state.dart';

class GpsLocationStoreTool {
  GpsLocationStoreTool._();

  static ToolModel get config => ToolModel(
    id: 'gps-location-store',
    name: 'GPS Location Store',
    description:
        'Capture and store your current location with notes and map links',
    icon: Icons.location_on_outlined,
    route: '/gps-location-store',
    accentColor: AppTheme.accentGreen,
    sectionId: 'sensors',
    nameL10n: (l10n) => l10n.toolNameGpsLocationStore,
    descriptionL10n: (l10n) => l10n.toolDescGpsLocationStore,
    createPage: (_) => const GpsLocationStorePage(),
    stateProviders: () => [
      ChangeNotifierProvider<GpsLocationStoreState>(
        create: (_) => GpsLocationStoreState(),
      ),
    ],
  );
}
