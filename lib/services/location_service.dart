import 'dart:convert';
import 'package:http/http.dart' as http;

class LocationService {
  // Asks Nominatim (OpenStreetMap's free geocoding service) to convert
  // a typed area name into real latitude/longitude coordinates.
  Future<Map<String, double>?> getCoordinatesFromArea(String area) async {
    final query = Uri.encodeComponent('$area, Ghana');
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=1',
    );

    try {
      final response = await http
          .get(url, headers: {'User-Agent': 'PowerTrackerGH/1.0'})
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final results = jsonDecode(response.body);
        
        if (results is List && results.isNotEmpty) {
          final first = results[0];
          return {
            'latitude': double.parse(first['lat'] ?? '0.0'),
            'longitude': double.parse(first['lon'] ?? '0.0'),
          };
        }
      }
    } catch (e) {
      // If geocoding fails (no internet, area not found, etc.),
      // we return null and let the caller decide what to do.
      return null;
    }

    return null;
  }
}
