import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math';

class Facility {
  final String name;
  final String address;
  final String email;
  final LatLng? coordinates;
  double? _distance; // Distance from current location

  Facility({
    required this.name,
    required this.address,
    required this.email,
    this.coordinates,
  });

  // Getter for distance
  double? get distance => _distance;

  // Set distance from current location
  void setDistance(LatLng currentLocation) {
    if (coordinates != null) {
      _distance = _calculateDistance(currentLocation, coordinates!);
    }
  }

  // Calculate distance between two points using Haversine formula
  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    double lat1 = point1.latitude * pi / 180;
    double lat2 = point2.latitude * pi / 180;
    double deltaLat = (point2.latitude - point1.latitude) * pi / 180;
    double deltaLng = (point2.longitude - point1.longitude) * pi / 180;

    double a = sin(deltaLat / 2) * sin(deltaLat / 2) +
        cos(lat1) * cos(lat2) * sin(deltaLng / 2) * sin(deltaLng / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  // Clear distance (useful when location changes)
  void clearDistance() {
    _distance = null;
  }

  factory Facility.fromJson(Map<String, dynamic> json) {
    return Facility(
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      email: json['email'] ?? '',
      coordinates: json['coordinates'] != null
          ? LatLng(
              json['coordinates']['lat'],
              json['coordinates']['lng'],
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'address': address,
      'email': email,
      'coordinates': coordinates != null
          ? {'lat': coordinates!.latitude, 'lng': coordinates!.longitude}
          : null,
    };
  }

  @override
  String toString() {
    return 'Facility(name: $name, address: $address, email: $email, coordinates: $coordinates)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Facility &&
        other.name == name &&
        other.address == address &&
        other.email == email;
  }

  @override
  int get hashCode {
    return name.hashCode ^ address.hashCode ^ email.hashCode;
  }
}
