import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:tb_frontend/services/config_service.dart'; // <-- Reads .env API key

class GeocodingHelper {
  static const String _baseUrl =
      'https://maps.googleapis.com/maps/api/geocode/json';

  // Use API key from ConfigService
  static String get _apiKey => ConfigService.googleMapsApiKey ?? '';

  // In-memory cache to avoid repeated API calls
  static final Map<String, LatLng> _cache = {};

  /// Converts an address to coordinates using Google Geocoding API
  /// Returns null if geocoding fails or address is invalid
  static Future<LatLng?> getCoordinates(String address) async {
    // Check cache first
    if (_cache.containsKey(address)) {
      return _cache[address];
    }

    if (_apiKey.isEmpty) {
      print('❌ Google Maps API key is missing in ConfigService!');
      return null;
    }

    try {
      final encodedAddress = Uri.encodeComponent(address);
      final url = '$_baseUrl?address=$encodedAddress&key=$_apiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final location = data['results'][0]['geometry']['location'];
          final lat = location['lat'] as double;
          final lng = location['lng'] as double;

          final coordinates = LatLng(lat, lng);

          // Cache the result
          _cache[address] = coordinates;

          print('✅ Geocoded: $address → $coordinates');
          return coordinates;
        } else {
          print('❌ Geocoding failed for: $address - Status: ${data['status']}');
          return null;
        }
      } else {
        print('❌ HTTP error ${response.statusCode} for: $address');
        return null;
      }
    } catch (e) {
      print('❌ Geocoding error for $address: $e');
      return null;
    }
  }

  /// Clears the geocoding cache
  static void clearCache() {
    _cache.clear();
  }

  /// Returns the number of cached entries
  static int getCacheSize() {
    return _cache.length;
  }

  /// Preloads coordinates for a list of addresses concurrently
  static Future<void> preloadCoordinates(List<String> addresses) async {
    await Future.wait(addresses.map((address) => getCoordinates(address)));
  }
}
