import 'package:flutter/material.dart';

class AndroidPickerButtons extends StatelessWidget {
  final VoidCallback onPickFromGallery;
  final VoidCallback onTakePhoto;
  final Color accentColor;

  const AndroidPickerButtons({
    super.key,
    required this.onPickFromGallery,
    required this.onTakePhoto,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: onPickFromGallery,
          icon: const Icon(Icons.photo_outlined),
          label: const Text('Browse Gallery'),
          style: OutlinedButton.styleFrom(
            foregroundColor: accentColor,
            side: BorderSide(color: accentColor.withValues(alpha: 0.5)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        OutlinedButton.icon(
          onPressed: onTakePhoto,
          icon: const Icon(Icons.camera_alt_outlined),
          label: const Text('Take Photo'),
          style: OutlinedButton.styleFrom(
            foregroundColor: accentColor,
            side: BorderSide(color: accentColor.withValues(alpha: 0.5)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }
}
