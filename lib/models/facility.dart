import 'package:google_maps_flutter/google_maps_flutter.dart';

class Facility {
  final String name;
  final String address;
  final String? email;
  final LatLng location;

  Facility({
    required this.name,
    required this.address,
    this.email,
    required this.location,
  });
}
