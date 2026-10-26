import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/city.dart';

class LocationService {
  static bool _hasLoggedDenied = false;

  /// Calculate distance between two coordinates in kilometers using Haversine formula
  static double calculateDistanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadiusKm = 6371.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _toRadians(double degree) => degree * math.pi / 180.0;

  /// Find the geographically nearest city from a list of cities
  static City findNearestCity(
    double userLat,
    double userLng,
    List<City> cities,
  ) {
    if (cities.isEmpty) {
      throw ArgumentError('Cities list cannot be empty');
    }

    City nearest = cities.first;
    double minDistance = calculateDistanceKm(userLat, userLng, nearest.lat, nearest.lng);

    for (int i = 1; i < cities.length; i++) {
      final city = cities[i];
      final dist = calculateDistanceKm(userLat, userLng, city.lat, city.lng);
      if (dist < minDistance) {
        minDistance = dist;
        nearest = city;
      }
    }

    return nearest;
  }

  /// Check and request location permission from the operating system
  static Future<bool> checkAndRequestPermission() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[LocationService] Location services are disabled on device');
        return false;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('[LocationService] Location permissions are denied');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!_hasLoggedDenied) {
          debugPrint('[LocationService] Location permissions are permanently denied');
          _hasLoggedDenied = true;
        }
        return false;
      }

      return permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
    } catch (e) {
      debugPrint('[LocationService] Error checking permissions: $e');
      return false;
    }
  }

  /// Get device current GPS position with fallback to last known position
  static Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await checkAndRequestPermission();
      if (!hasPermission) return null;

      try {
        return await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 8),
          ),
        );
      } catch (timeout) {
        debugPrint('[LocationService] Current position timed out, trying last known');
        return await Geolocator.getLastKnownPosition();
      }
    } catch (e) {
      debugPrint('[LocationService] Error acquiring position: $e');
      return null;
    }
  }

  /// Detect device GPS location and find the nearest city
  static Future<City?> detectNearestCity(List<City> cities) async {
    if (cities.isEmpty) return null;
    final position = await getCurrentPosition();
    if (position == null) return null;

    final nearest = findNearestCity(position.latitude, position.longitude, cities);
    final distance = calculateDistanceKm(
      position.latitude,
      position.longitude,
      nearest.lat,
      nearest.lng,
    );
    debugPrint('[LocationService] Detected nearest city: ${nearest.ku} (${nearest.id}), distance: ${distance.toStringAsFixed(1)} km');
    return nearest;
  }
}
