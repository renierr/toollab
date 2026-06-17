import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

/// Resolves localized tool metadata at display time.
///
/// Tool IDs are never translated — only the human-facing name and
/// description are mapped here. Unknown IDs fall back to the raw
/// `const` values from `config.dart`.
extension ToolModelL10n on ToolModel {
  String localizedName(AppLocalizations l10n) {
    switch (id) {
      case 'calculator':
        return l10n.toolNameCalculator;
      case 'bubble-level':
        return l10n.toolNameBubbleLevel;
      case 'emf-detector':
        return l10n.toolNameEmfDetector;
      case 'device-info':
        return l10n.toolNameDeviceInfo;
      case 'nfc-tag-lab':
        return l10n.toolNameNfcTagLab;
      case 'pdf-viewer':
        return l10n.toolNamePdfViewer;
      case 'notes':
        return l10n.toolNameNotes;
      case 'markdown-viewer':
        return l10n.toolNameMarkdownViewer;
      case 'image-viewer':
        return l10n.toolNameImageViewer;
      case 'fast-drop':
        return l10n.toolNameFastDrop;
      case 'images-to-pdf':
        return l10n.toolNameImagesToPdf;
      case 'chiptune':
        return l10n.toolNameChiptune;
      case 'focus-noise':
        return l10n.toolNameFocusNoise;
      case 'signatures':
        return l10n.toolNameSignatures;
      default:
        return name;
    }
  }

  String localizedDescription(AppLocalizations l10n) {
    switch (id) {
      case 'calculator':
        return l10n.toolDescCalculator;
      case 'bubble-level':
        return l10n.toolDescBubbleLevel;
      case 'emf-detector':
        return l10n.toolDescEmfDetector;
      case 'device-info':
        return l10n.toolDescDeviceInfo;
      case 'nfc-tag-lab':
        return l10n.toolDescNfcTagLab;
      case 'pdf-viewer':
        return l10n.toolDescPdfViewer;
      case 'notes':
        return l10n.toolDescNotes;
      case 'markdown-viewer':
        return l10n.toolDescMarkdownViewer;
      case 'image-viewer':
        return l10n.toolDescImageViewer;
      case 'fast-drop':
        return l10n.toolDescFastDrop;
      case 'images-to-pdf':
        return l10n.toolDescImagesToPdf;
      case 'chiptune':
        return l10n.toolDescChiptune;
      case 'focus-noise':
        return l10n.toolDescFocusNoise;
      case 'signatures':
        return l10n.toolDescSignatures;
      default:
        return description;
    }
  }
}

/// Resolves localized section titles at display time. Section IDs are
/// never translated; unknown IDs fall back to the raw `title`.
extension ToolSectionL10n on ToolSection {
  String localizedTitle(AppLocalizations l10n) {
    switch (id) {
      case 'sensors':
        return l10n.sectionTitleSensors;
      case 'utilities':
        return l10n.sectionTitleUtilities;
      case 'info':
        return l10n.sectionTitleInfo;
      default:
        return title;
    }
  }
}
