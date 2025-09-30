// Test script to verify Google Maps API key
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final apiKey = 'AIzaSyB1qCMW00SQ5345y6l9SiVOaZn6rSyXpcs';

  // Test Geocoding API
  final address =
      'Agdao Public Market Corner Lapu-Lapu & C. Bangoy St., Agdao, Davao City';
  final url =
      'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(address)}&key=$apiKey';

  print('Testing Geocoding API...');
  print('URL: $url');

  try {
    final response = await http.get(Uri.parse(url));
    print('Status Code: ${response.statusCode}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('Response: ${json.encode(data)}');

      if (data['status'] == 'OK') {
        print('✅ Geocoding API is working!');
      } else {
        print('❌ Geocoding API failed with status: ${data['status']}');
        print('Error message: ${data['error_message'] ?? 'No error message'}');
      }
    } else {
      print('❌ HTTP Error: ${response.statusCode}');
      print('Response: ${response.body}');
    }
  } catch (e) {
    print('❌ Exception: $e');
  }
}
