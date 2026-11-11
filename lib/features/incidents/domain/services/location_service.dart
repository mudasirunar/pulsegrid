import 'dart:convert';
import 'dart:io';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

abstract class LocationService {
  Future<({double latitude, double longitude})?> getCurrentLocation();
  Future<String?> reverseGeocode({required double latitude, required double longitude});
  Future<bool> checkPermission();
  Future<bool> requestPermission();
}

class LocationServiceImpl implements LocationService {
  @override
  Future<bool> checkPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  @override
  Future<bool> requestPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  @override
  Future<({double latitude, double longitude})?> getCurrentLocation() async {
    try {
      final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isServiceEnabled) return null;

      final hasPermission = await requestPermission();
      if (!hasPermission) return null;

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );
      } catch (_) {
        // Fallback to last known position if satellite acquisition times out indoors
        position = await Geolocator.getLastKnownPosition();
      }

      if (position == null) return null;
      return (latitude: position.latitude, longitude: position.longitude);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    // 1. First attempt OpenStreetMap Nominatim for precise neighbourhood, town, and street data
    try {
      final osmAddress = await _reverseGeocodeOSM(latitude, longitude);
      if (osmAddress != null && osmAddress.isNotEmpty) {
        return osmAddress;
      }
    } catch (_) {}

    // 2. Fall back to native OS Geocoder (Apple CoreLocation / Android Geocoder)
    try {
      final placemarks = await Geocoding().placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isEmpty) return null;

      final place = placemarks.first;
      final parts = <String>[];

      void addPart(String? val) {
        if (val == null) return;
        final clean = val.trim();
        if (clean.isEmpty) return;
        if (!parts.any((p) => p.toLowerCase() == clean.toLowerCase())) {
          parts.add(clean);
        }
      }

      // Specific landmark, building, block, or venue name
      if (place.name != null &&
          place.name != place.locality &&
          place.name != place.administrativeArea &&
          place.name != place.country) {
        addPart(place.name);
      }

      // Street & thoroughfare
      addPart(place.street);
      addPart(place.thoroughfare);

      // Neighborhood / Town / Sector (e.g. Clifton, Gulshan, PECHS)
      addPart(place.subLocality);

      // District / Sub-administrative area (e.g. Karachi East, Central)
      addPart(place.subAdministrativeArea);

      // City (e.g. Karachi)
      addPart(place.locality);

      // State / Province (e.g. Sindh)
      addPart(place.administrativeArea);

      return parts.isNotEmpty ? parts.join(', ') : null;
    } catch (_) {
      // Offline fallback: Returns null if network is unavailable or lookup fails
      return null;
    }
  }

  Future<String?> _reverseGeocodeOSM(double latitude, double longitude) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 8);
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=$latitude&lon=$longitude&format=json&accept-language=en',
      );
      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', 'PulseGrid-App/1.0 (contact@pulsegrid.org)');
      final response = await request.close().timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;

      final body = await response.transform(utf8.decoder).join();
      final data = json.decode(body) as Map<String, dynamic>;
      final address = data['address'] as Map<String, dynamic>?;
      if (address == null) return null;

      final parts = <String>[];
      void add(dynamic val) {
        if (val is String && val.trim().isNotEmpty && !parts.contains(val.trim())) {
          parts.add(val.trim());
        }
      }

      add(address['road'] ?? address['pedestrian']);
      add(address['neighbourhood'] ?? address['suburb']);
      add(address['town'] ?? address['residential']);
      add(address['city_district'] ?? address['district']);
      add(address['city'] ?? address['county']);

      return parts.isNotEmpty ? parts.join(', ') : null;
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }
}

