import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/facility.dart';
import '../../services/facility_repository.dart';
import '../../services/geocoding_helper.dart';
import 'dart:math';
import '../contacts/facility_contacts_page.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
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
    setState(() {
      _isLoading = true;
    });

    try {
      // Request location permission first
      await _requestLocationPermission();

      // Get facilities only after permissions are handled
      final facilities = await FacilityRepository.getAllFacilities();

      if (_locationPermissionGranted) {
        await _getCurrentLocation();
      }

      if (mounted) {
        await _createMarkers(facilities);

        setState(() {
          _facilities = facilities;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error initializing map: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
      debugPrint('Error requesting location permission: $e');
      setState(() {
        _locationPermissionGranted = false;
        _locationPermissionMessage = 'Unable to access location services.';
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );

      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
    } catch (e) {
      debugPrint('Error getting current location: $e');
    }
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

    if (mounted) {
      setState(() {
        _markers = markers;
      });
    }
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

    // Always use Google Maps for directions
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening maps: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _centerOnNearbyFacilities() {
    if (_mapController != null && _facilities.isNotEmpty) {
      double minLat = double.infinity;
      double maxLat = -double.infinity;
      double minLng = double.infinity;
      double maxLng = -double.infinity;

      for (final facility in _facilities) {
        if (facility.coordinates != null) {
          minLat = min(minLat, facility.coordinates!.latitude);
          maxLat = max(maxLat, facility.coordinates!.latitude);
          minLng = min(minLng, facility.coordinates!.longitude);
          maxLng = max(maxLng, facility.coordinates!.longitude);
        }
      }

      if (minLat != double.infinity && maxLat != -double.infinity) {
        final bounds = LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        );

        _mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 50.0),
        );
      } else {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(_davaoCenter, 12),
        );
      }
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
            color: Colors.black.withValues(alpha: 0.1),
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
                      child: Text(
                        facility.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
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
                              WidgetStateProperty.all(Colors.transparent),
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
