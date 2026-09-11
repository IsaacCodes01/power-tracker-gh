import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../utils/network_guard.dart';

class LocationService {
  // Shared by both the live-suggestions dropdown and the plain
  // single-result search below, so there's one place that knows how to
  // talk to Nominatim instead of two copies drifting apart.
  Future<List<dynamic>> searchAreas(String query, {int limit = 8}) async {
    final encoded = Uri.encodeComponent('$query, Ghana');
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search?q=$encoded&format=json&limit=$limit',
    );

    final response = await http
        .get(url, headers: {'User-Agent': 'PowerTrackerGH/1.0'})
        .withNetworkTimeout(duration: const Duration(seconds: 8));

    if (response.statusCode != 200 || response.body.isEmpty) return [];

    try {
      final results = jsonDecode(response.body);
      return results is List ? results : [];
    } catch (_) {
      return [];
    }
  }

  // Asks Nominatim (OpenStreetMap's free geocoding service) to convert
  // a typed area name into real latitude/longitude coordinates.
  Future<Map<String, double>?> getCoordinatesFromArea(String area) async {
    final results = await searchAreas(area, limit: 1);
    if (results.isEmpty) return null;
    final Map<String, dynamic> firstRecord = results[0];
    return {
      'latitude': double.parse(firstRecord['lat'] ?? '0.0'),
      'longitude': double.parse(firstRecord['lon'] ?? '0.0'),
    };
  }

  // Gets the device's real current GPS position, handling permission
  // requests along the way. Throws a plain string error if location
  // services are off or permission is denied, so the UI can show
  // a clear message instead of crashing.
  Future<Position> getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw 'Location services are turned off. Please enable them.';
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw 'Location permission was denied.';
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw 'Location permission is permanently denied. Enable it in settings.';
    }

    return await Geolocator.getCurrentPosition();
  }

  // Converts real coordinates back into a readable place name,
  // e.g. turning GPS numbers into "Oduman, Accra".
  Future<String?> reverseGeocode(double lat, double lon) async {
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json',
    );

    try {
      final response = await http
          .get(url, headers: {'User-Agent': 'PowerTrackerGH/1.0'})
          .withNetworkTimeout(duration: const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['display_name'];
      }
    } on NetworkTimeoutException {
      rethrow;
    } catch (e) {
      return null;
    }
    return null;
  }

  // Nominatim returns long, comma-separated addresses. This keeps just
  // the first two segments, e.g. "Free Pipe, Abeka Road" instead of
  // the full multi-part address down to country and region.
  String shortenLocationName(String fullName) {
    final parts = fullName.split(',').map((p) => p.trim()).toList();
    if (parts.length <= 2) return fullName;
    return '${parts[0]}, ${parts[1]}';
  }
}
