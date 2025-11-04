import 'package:tb_frontend/services/geocoding_helper.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/facility.dart';

class FacilityRepository {
  static final List<Facility> _facilities = [
    Facility(
      name: "AGDAO HEALTH CENTER",
      address:
          "Agdao Public Market Corner Lapu-Lapu & C. Bangoy St., Agdao, Davao City",
          coordinates: LatLng(7.083224419753201, 125.62108753025124),
    ),
    Facility(
      name: "BAGUIO (MALAGOS HC)",
      address: "Purok 2A Malagos, Baguio District, Davao City",
      coordinates: LatLng(16.401165336943944, 120.59657459551488),
    ),
    Facility(
      name: "BUHANGIN DISTRICT HEALTH CENTER",
      address: "NHA Chapet St., Buhangin, Davao City",
      coordinates: LatLng(7.114167790393465, 125.62471551084745),
    ),
    Facility(
      name: "BUNAWAN HEALTH CENTER",
      address: "Bunawan District Health Center, Davao City",
      coordinates: LatLng(7.235900918467278, 125.64249908245937),
    ),
    Facility(
      name: "CALINAN HEALTH CENTER",
      address: "P34, Aurora St., Calinan, Davao City",
      coordinates: LatLng(7.189184580341376, 125.46046316039299),
    ),
    Facility(
      name: "DAVAO CHEST CENTER",
      address: "Villa Abrille St., Brgy 30-C, Davao City",
      coordinates: LatLng(7.07501181393132, 125.61431072528602),
    ),
    Facility(
      name: "TOMAS CLAUDIO HEALTH CENTER)",
      address: "Camus Ext., Corner Quirino Ave., Davao City",
      coordinates: LatLng(7.071525208465989, 125.60716688811394),
    ),
    Facility(
      name: "EL RIO HEALTH CENTER)",
      address: "Garcia Heights, Bajada, Davao City",
      coordinates: LatLng(7.103864073971893, 125.60032955425771),
    ),
    Facility(
      name: "MINIFOREST HEALTH CENTER",
      address: "Brgy 23-C, Quezon Boulevard, Davao City",
      coordinates: LatLng(7.071483721930537, 125.62176782542137),
    ),
    Facility(
      name: "JACINTO HEALTH CENTER",
      address: "Emilio Jacinto St., Davao City",
      coordinates: LatLng(7.068855794704188, 125.6165630324464),
    ),
    Facility(
      name: "MARAHAN HEALTH CENTER",
      address: "Sitio Marahan, Brgy. Marilog, Davao City",
      coordinates: LatLng(7.405536933260433, 125.2525052051529),
    ),
    Facility(
      name: "MALABOG HEALTH CENTER",
      address: "Brgy Malabog, Davao City",
      coordinates: LatLng(7.3260187712857645, 125.46043634482088),
    ),
    Facility(
      name: "SASA DISTRICT HEALTH CENTER",
      address: "Bangoy Km 9,  Sasa, Davao City",
      coordinates: LatLng(7.103888952423774, 125.64306296792718),
    ),
    Facility(
      name: "TALOMO CENTRAL (GSIS HC)",
      address: "GSIS Village, Matina, Davao City",
      coordinates: LatLng(7.0593640606768515, 125.57439647337574),
    ),
    Facility(
      name: "TALOMO NORTH (SIR HC)",
      address: "Daang Patnubay St., SIR Ph-1, Sandawa, Davao City",
      coordinates: LatLng(7.0599590784711, 125.59960883221592),
    ),
    Facility(
      name: "TALOMO SOUTH (PUAN HC)",
      address: "Puan, Talomo, Davao City",
      coordinates: LatLng(7.05121225928667, 125.54096999999926),
    ),
    Facility(
      name: "TORIL A HEALTH CENTER",
      address: "Agton St., Toril, Davao City",
      coordinates: LatLng(7.019900094625708, 125.49729801740932),
    ),
    Facility(
      name: "TORIL B HEALTH CENTER",
      address: "Juan Dela Cruz St., Daliao, Toril, Davao City",
      coordinates: LatLng(7.0116456012198825, 125.50187380358807),
    ),
    Facility(
      name: "TUGBOK (MINTAL HC)",
      address: "Sampaguita St., Mintal, Tugbok District, Davao City",
      coordinates: LatLng(7.090383316303254, 125.50127145425716),
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
