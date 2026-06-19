import 'package:flutter/material.dart';

import 'gps_location_store_db_helper.dart';
import 'location_capture_service.dart';
import 'saved_location.dart';

class GpsLocationStoreState extends ChangeNotifier {
  List<SavedLocation> _locations = [];
  bool _isLoading = false;
  LocationFix? _currentPosition;
  bool _isLocatingCurrent = false;

  List<SavedLocation> get locations => _locations;
  bool get isLoading => _isLoading;

  /// Live position used to display the current spot and compute
  /// distance/direction to stored locations. `null` until located.
  LocationFix? get currentPosition => _currentPosition;
  bool get isLocatingCurrent => _isLocatingCurrent;

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

  /// Resolves the live position (GPS, falling back to IP) for display and
  /// distance/direction calculations. Does not store anything. Returns `true`
  /// on success.
  Future<bool> locateCurrent() async {
    _isLocatingCurrent = true;
    notifyListeners();
    try {
      _currentPosition = await LocationCaptureService.capture();
      return true;
    } catch (e) {
      debugPrint('[GpsLocationStoreState] Current position unavailable: $e');
      return false;
    } finally {
      _isLocatingCurrent = false;
      notifyListeners();
    }
  }

  Future<void> saveFix(LocationFix fix, String description) async {
    _currentPosition = fix;
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
