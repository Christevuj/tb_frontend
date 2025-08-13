import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../utils/polyline_decoder.dart'; // We'll make this too

Future<List<LatLng>> getRoutePoints(
    LatLng start, LatLng end, String apiKey) async {
  final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json?origin=${start.latitude},${start.longitude}&destination=${end.latitude},${end.longitude}&key=$apiKey');

  final response = await http.get(url);

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    final points = data['routes'][0]['overview_polyline']['points'];
    return decodePolyline(points);
  }

  return [];
}
