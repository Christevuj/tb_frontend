import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

Future<LatLng?> getCoordinatesFromAddress(String address, String apiKey) async {
  final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(address)}&key=$apiKey');

  final response = await http.get(url);

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    final results = data['results'];
    if (results.isNotEmpty) {
      final location = results[0]['geometry']['location'];
      return LatLng(location['lat'], location['lng']);
    }
  }
  return null;
}
