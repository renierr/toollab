import 'package:tool_lab/l10n/app_localizations.dart';

import 'renpho_body_metrics.dart';

extension RenphoSegmentLabel on RenphoSegment {
  String label(AppLocalizations l10n) => switch (this) {
    RenphoSegment.leftArm => l10n.renphoSegmentLeftArm,
    RenphoSegment.rightArm => l10n.renphoSegmentRightArm,
    RenphoSegment.leftLeg => l10n.renphoSegmentLeftLeg,
    RenphoSegment.rightLeg => l10n.renphoSegmentRightLeg,
    RenphoSegment.trunk => l10n.renphoSegmentTrunk,
  };
}
