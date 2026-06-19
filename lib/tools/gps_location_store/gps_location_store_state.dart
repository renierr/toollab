import 'package:flutter/material.dart';

import 'gps_location_store_db_helper.dart';
import 'location_capture_service.dart';
import 'saved_location.dart';

class GpsLocationStoreState extends ChangeNotifier {
  List<SavedLocation> _locations = [];
  bool _isLoading = false;
  bool _isCapturing = false;

  List<SavedLocation> get locations => _locations;
  bool get isLoading => _isLoading;
  bool get isCapturing => _isCapturing;

  SavedLocation? get lastLocation =>
      _locations.isEmpty ? null : _locations.first;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      _locations = await GpsLocationStoreDbHelper.instance.getLocations();
    } catch (e) {
      debugPrint('[GpsLocationStoreState] Failed to load locations: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Captures the current position. Returns the fix for preview; does not store.
  Future<LocationFix> captureCurrent() async {
    _isCapturing = true;
    notifyListeners();
    try {
      return await LocationCaptureService.capture();
    } finally {
      _isCapturing = false;
      notifyListeners();
    }
  }

  Future<void> saveFix(LocationFix fix, String description) async {
    await GpsLocationStoreDbHelper.instance.insertLocation(
      latitude: fix.latitude,
      longitude: fix.longitude,
      accuracy: fix.accuracy,
      description: description.trim(),
      source: fix.source,
    );
    await load();
  }

  Future<void> updateDescription(int id, String description) async {
    await GpsLocationStoreDbHelper.instance.updateDescription(
      id,
      description.trim(),
    );
    await load();
  }

  Future<void> deleteLocation(int id) async {
    await GpsLocationStoreDbHelper.instance.deleteLocation(id);
    await load();
  }
}
