import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math' as math;
import '../../models/facility.dart';
import '../../services/facility_repository.dart';
import '../../services/geocoding_helper.dart';
import '../../services/config_service.dart';
import '../contacts/facility_contacts_page.dart';

class MapScreenEnhanced extends StatefulWidget {
  const MapScreenEnhanced({super.key});

  @override
  State<MapScreenEnhanced> createState() => _MapScreenEnhancedState();
}

class _MapScreenEnhancedState extends State<MapScreenEnhanced> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  List<Facility> _facilities = [];
  Facility? _selectedFacility;
  Position? _currentPosition;
  bool _isLoading = true;
  bool _locationPermissionGranted = false;
  String? _locationPermissionMessage;

  static const LatLng _davaoCenter = LatLng(7.0731, 125.6128);

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    try {
      final facilities = FacilityRepository.getAllFacilities();
      await _requestLocationPermission();

      if (_locationPermissionGranted) {
        await _getCurrentLocation();
      }

      await _createMarkers(facilities);

      setState(() {
        _facilities = facilities;
        _isLoading = false;
      });
    } catch (e) {
      print('Error initializing map: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _requestLocationPermission() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationPermissionGranted = false;
          _locationPermissionMessage =
              'Location permission is permanently denied.';
        });
        return;
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        setState(() {
          _locationPermissionGranted = true;
          _locationPermissionMessage = null;
        });
      }
    } catch (e) {
      print('Error requesting location permission: $e');
      setState(() {
        _locationPermissionGranted = false;
        _locationPermissionMessage = 'Unable to access location services.';
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentPosition = position;
      });
    } catch (e) {
      print('Error getting current location: $e');
    }
  }

  /// Centers the map on nearby facilities and shows them in order of proximity
  Future<void> _centerOnNearbyFacilities() async {
    if (_currentPosition == null || _mapController == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Please enable location services to find nearby facilities'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final currentLocation =
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude);

      // Get nearby facilities sorted by distance
      final nearbyFacilities =
          await FacilityRepository.getNearbyFacilities(currentLocation);

      if (nearbyFacilities.isNotEmpty) {
        // Update facilities list with sorted order
        setState(() {
          _facilities = nearbyFacilities;
        });

        // Get the nearest facility to center on
        final nearestFacility = nearbyFacilities.first;
        if (nearestFacility.coordinates != null) {
          // Calculate bounds to include current location and nearest facilities
          final bounds = _calculateBounds(currentLocation,
              nearbyFacilities.take(5).toList() // Include top 5 nearest
              );

          // Animate camera to show the bounds
          await _mapController!
              .animateCamera(CameraUpdate.newLatLngBounds(bounds, 50.0));

          // Show a snackbar with nearest facility info
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '📍 Nearest facility: ${nearestFacility.name} (${nearestFacility.distance?.toStringAsFixed(1)} km away)',
                  style: const TextStyle(fontSize: 14),
                ),
                backgroundColor: Colors.green.shade600,
                duration: const Duration(seconds: 3),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      print('Error centering on nearby facilities: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error finding nearby facilities: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Calculates bounds to include current location and facilities
  LatLngBounds _calculateBounds(
      LatLng currentLocation, List<Facility> facilities) {
    double minLat = currentLocation.latitude;
    double maxLat = currentLocation.latitude;
    double minLng = currentLocation.longitude;
    double maxLng = currentLocation.longitude;

    // Include current location
    minLat = math.min(minLat, currentLocation.latitude);
    maxLat = math.max(maxLat, currentLocation.latitude);
    minLng = math.min(minLng, currentLocation.longitude);
    maxLng = math.max(maxLng, currentLocation.longitude);

    // Include facilities
    for (final facility in facilities) {
      if (facility.coordinates != null) {
        minLat = math.min(minLat, facility.coordinates!.latitude);
        maxLat = math.max(maxLat, facility.coordinates!.latitude);
        minLng = math.min(minLng, facility.coordinates!.longitude);
        maxLng = math.max(maxLng, facility.coordinates!.longitude);
      }
    }

    // Add some padding
    const double padding = 0.01; // About 1km
    return LatLngBounds(
      southwest: LatLng(minLat - padding, minLng - padding),
      northeast: LatLng(maxLat + padding, maxLng + padding),
    );
  }

  Future<void> _createMarkers(List<Facility> facilities) async {
    final markers = <Marker>{};

    for (int i = 0; i < facilities.length; i++) {
      final facility = facilities[i];

      LatLng? coordinates = facility.coordinates;
      coordinates ??= await GeocodingHelper.getCoordinates(facility.address);

      if (coordinates != null) {
        final marker = Marker(
          markerId: MarkerId('facility_$i'),
          position: coordinates,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: facility.name,
            snippet: facility.address,
          ),
          onTap: () => _onMarkerTapped(facility),
        );
        markers.add(marker);
      }
    }

    setState(() {
      _markers = markers;
    });
  }

  void _onMarkerTapped(Facility facility) {
    setState(() {
      _selectedFacility = facility;
    });
  }

  void _dismissCard() {
    setState(() {
      _selectedFacility = null;
    });
  }

  void _viewContacts() {
    if (_selectedFacility != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              FacilityContactsPage(facility: _selectedFacility!),
        ),
      );
    }
  }

  Future<void> _seeDirections() async {
    if (_selectedFacility?.coordinates == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Unable to get directions: Facility location not available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final lat = _selectedFacility!.coordinates!.latitude;
    final lng = _selectedFacility!.coordinates!.longitude;

    // Always use Google Maps URL (removed iOS code)
    String url =
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving';

    if (_currentPosition != null) {
      url +=
          '&origin=${_currentPosition!.latitude},${_currentPosition!.longitude}';
    }

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Could not launch $url');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening maps: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
            },
            initialCameraPosition: const CameraPosition(
              target: _davaoCenter,
              zoom: 12,
            ),
            markers: _markers,
            myLocationEnabled: _locationPermissionGranted,
            myLocationButtonEnabled: _locationPermissionGranted,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: true,
          ),
          if (_locationPermissionMessage != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on,
                        color: Colors.orange.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _locationPermissionMessage!,
                        style: TextStyle(
                          color: Colors.orange.shade800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close,
                          color: Colors.orange.shade700, size: 20),
                      onPressed: () {
                        setState(() {
                          _locationPermissionMessage = null;
                        });
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
          if (_selectedFacility != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildInfoCard(),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _centerOnNearbyFacilities,
        icon: const Icon(Icons.near_me, color: Colors.white),
        label: const Text('Nearby', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green.shade600,
        heroTag: 'nearby_facilities',
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildInfoCard() {
    final facility = _selectedFacility!;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Icon(
                        Icons.local_hospital,
                        color: Colors.red.shade600,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            facility.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          if (facility.distance != null)
                            Text(
                              '${facility.distance!.toStringAsFixed(1)} km away',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: _dismissCard,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.location_on,
                        color: Colors.grey.shade600, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        facility.address,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                if (facility.email.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.email, color: Colors.grey.shade600, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          facility.email,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _viewContacts,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ).copyWith(
                          backgroundColor:
                              MaterialStateProperty.all(Colors.transparent),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFF2851E), Color(0xFFD14125)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Text(
                              'View Contacts',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _seeDirections,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey.shade700,
                          side: BorderSide(color: Colors.grey.shade400),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'See Directions',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
