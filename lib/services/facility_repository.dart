import 'package:tb_frontend/services/geocoding_helper.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/facility.dart';

class FacilityRepository {
  static final List<Facility> _facilities = [
    Facility(
      name: "AGDAO",
      address:
          "Agdao Public Market Corner Lapu-Lapu & C. Bangoy St., Agdao, Davao City",
    ),
    Facility(
      name: "BAGUIO (MALAGOS HC)",
      address: "Purok 2A Malagos, Baguio District, Davao City",
    ),
    Facility(
      name: "BUHANGIN (NHA BUHANGIN HC)",
      address: "NHA Chapet St., Buhangin, Davao City",
    ),
    Facility(
      name: "BUNAWAN",
      address: "Bunawan District Health Center, Davao City",
    ),
    Facility(
      name: "CALINAN",
      address: "P34, Aurora St., Calinan, Davao City",
    ),
    Facility(
      name: "DAVAO CHEST CENTER",
      address: "Villa Abrille St., Brgy 30-C, Davao City",
    ),
    Facility(
      name: "DISTRICT A (TOMAS CLAUDIO HC)",
      address: "Camus Ext., Corner Quirino Ave., Davao City",
    ),
    Facility(
      name: "DISTRICT B (EL RIO HC)",
      address: "Garcia Heights, Bajada, Davao City",
    ),
    Facility(
      name: "DISTICT C (MINIFOREST HC)",
      address: "Brgy 23-C, Quezon Boulevard, Davao City",
    ),
    Facility(
      name: "DISTRICT D (JACINTO HC)",
      address: "Emilio Jacinto St., Davao City",
    ),
    Facility(
      name: "MARILOG (MARAHAN HC)",
      address: "Sitio Marahan, Brgy. Marilog, Davao City",
    ),
    Facility(
      name: "PAQUIBATO (MALABOG HC)",
      address: "Brgy Malabog, Davao City",
    ),
    Facility(
      name: "SASA",
      address: "Bangoy Km 9,  Sasa, Davao City",
    ),
    Facility(
      name: "TALOMO CENTRAL (GSIS HC)",
      address: "GSIS Village, Matina, Davao City",
    ),
    Facility(
      name: "TALOMO NORTH (SIR HC)",
      address: "Daang Patnubay St., SIR Ph-1, Sandawa, Davao City",
    ),
    Facility(
      name: "TALOMO SOUTH (PUAN HC)",
      address: "Puan, Talomo, Davao City",
    ),
    Facility(
      name: "TORIL A",
      address: "Agton St., Toril, Davao City",
    ),
    Facility(
      name: "TORIL B",
      address: "Juan Dela Cruz St., Daliao, Toril, Davao City",
    ),
    Facility(
      name: "TUGBOK",
      address: "Sampaguita St., Mintal, Tugbok District, Davao City",
    ),
  ];

  /// Returns all health facilities in Davao
  static List<Facility> getAllFacilities() {
    return List.unmodifiable(_facilities);
  }

  /// Returns facilities with geocoded coordinates
  static Future<List<Facility>> getFacilitiesWithCoordinates() async {
    final facilities = getAllFacilities();
    final geocodedFacilities = <Facility>[];

    for (final facility in facilities) {
      if (facility.coordinates != null) {
        geocodedFacilities.add(facility);
      } else {
        // Try to geocode the address
        final coordinates =
            await GeocodingHelper.getCoordinates(facility.address);
        if (coordinates != null) {
          geocodedFacilities.add(Facility(
            name: facility.name,
            address: facility.address,
            email: facility.email,
            coordinates: coordinates,
          ));
        }
      }
    }

    return geocodedFacilities;
  }

  /// Returns facilities sorted by distance from current location
  static Future<List<Facility>> getNearbyFacilities(
      LatLng currentLocation) async {
    final facilities = await getFacilitiesWithCoordinates();

    // Calculate distances for each facility
    for (final facility in facilities) {
      facility.setDistance(currentLocation);
    }

    // Sort by distance (nearest first)
    facilities.sort((a, b) {
      if (a.distance == null && b.distance == null) return 0;
      if (a.distance == null) return 1;
      if (b.distance == null) return -1;
      return a.distance!.compareTo(b.distance!);
    });

    return facilities;
  }

  /// Returns the nearest facility to the current location
  static Future<Facility?> getNearestFacility(LatLng currentLocation) async {
    final nearbyFacilities = await getNearbyFacilities(currentLocation);
    return nearbyFacilities.isNotEmpty ? nearbyFacilities.first : null;
  }

  /// Returns facilities within a specified radius (in kilometers)
  static Future<List<Facility>> getFacilitiesWithinRadius(
      LatLng currentLocation, double radiusKm) async {
    final nearbyFacilities = await getNearbyFacilities(currentLocation);
    return nearbyFacilities
        .where((facility) =>
            facility.distance != null && facility.distance! <= radiusKm)
        .toList();
  }
}
