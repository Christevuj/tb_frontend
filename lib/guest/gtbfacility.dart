// gtb_facility_page.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tb_frontend/models/facility.dart';

// Replace this import with the actual path in your project:
import 'package:tb_frontend/services/facility_repository.dart';
import 'glistfacility.dart' as glist;

class GtbfacilityPage extends StatefulWidget {
  const GtbfacilityPage({super.key});

  @override
  _GtbfacilityPageState createState() => _GtbfacilityPageState();
}

class _GtbfacilityPageState extends State<GtbfacilityPage> {
  final Completer<GoogleMapController> _mapController = Completer();
  final PageController _pageController = PageController(viewportFraction: 0.94);
  final String _apiKey =
      'AIzaSyB1qCMW00SQ5345y6l9SiVOaZn6rSyXpcs'; // Use your actual API key

  LatLng? _currentLocation;
  bool _loading = true;
  List<Facility> _facilities = [];
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  int _selectedIndex = 0;

  StreamSubscription<Position>? _positionStreamSubscription; // 👈 Added

  static const double _zoomLevel = 15.0;

  @override
  void initState() {
    super.initState();
    if (!Platform.isAndroid) {
      // This page is intended for Android only per your request.
      setState(() => _loading = false);
      return;
    }
    _initEverything();
  }

  Future<void> _initEverything() async {
    try {
      await _ensureLocationPermission();
      await _getCurrentLocation();

      // 👇 Start listening for continuous location updates
      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy
              .high, // Changed from 'best' to 'high' for better performance
          distanceFilter: 10, // Update every 10 meters to reduce battery usage
          timeLimit: Duration(seconds: 30), // Add timeout for position updates
        ),
      ).listen(
        (Position pos) {
          debugPrint(
              'Position update: ${pos.latitude}, ${pos.longitude} (accuracy: ${pos.accuracy}m)');

          // Validate the position
          if (pos.latitude == 0.0 && pos.longitude == 0.0) {
            debugPrint('Warning: Received (0,0) position, ignoring...');
            return;
          }

          final LatLng newPos = LatLng(pos.latitude, pos.longitude);

          setState(() {
            _currentLocation = newPos;
          });

          // Move map with you like Google Maps (but only if significant movement)
          if (_currentLocation != null) {
            _animateCameraTo(newPos, zoom: _zoomLevel);
          }

          // Rebuild "You are here" marker
          _buildMarkers();
        },
        onError: (error) {
          debugPrint('Position stream error: $error');
          // Don't show error to user for stream errors, just log them
        },
      );

      await _loadFacilities();
      _buildMarkers();

      // Center map on current location first, then facilities
      if (_currentLocation != null) {
        debugPrint('Centering map on current location: $_currentLocation');
        _animateCameraTo(_currentLocation!, zoom: _zoomLevel);
      } else if (_facilities.isNotEmpty && _facilities[0].coordinates != null) {
        debugPrint('No current location, centering on first facility');
        _animateCameraTo(_facilities[0].coordinates!, zoom: _zoomLevel);
      } else {
        debugPrint(
            'No location or facilities available for initial camera position');
      }
    } catch (e) {
      debugPrint('Init error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _ensureLocationPermission() async {
    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    debugPrint('Location services enabled: $serviceEnabled');

    if (!serviceEnabled) {
      // Show dialog to user about enabling location services
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Please enable location services in your device settings'),
            duration: Duration(seconds: 5),
          ),
        );
      }
      throw 'Location services are disabled. Please enable location services in your device settings.';
    }

    // Check permission status
    LocationPermission permission = await Geolocator.checkPermission();
    debugPrint('Current location permission: $permission');

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      debugPrint('Permission after request: $permission');

      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Location permission is required to show your position on the map'),
              duration: Duration(seconds: 5),
            ),
          );
        }
        throw 'Location permission denied';
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Location permission permanently denied. Please enable in app settings.'),
            duration: Duration(seconds: 5),
          ),
        );
      }
      throw 'Location permission denied forever. Please enable location permission in app settings.';
    }

    debugPrint('Location permission granted successfully');
  }

  Future<void> _getCurrentLocation() async {
    try {
      debugPrint('Getting current location...');

      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15), // Add timeout
      );

      debugPrint('Location obtained: ${pos.latitude}, ${pos.longitude}');
      debugPrint('Location accuracy: ${pos.accuracy} meters');
      debugPrint('Location timestamp: ${pos.timestamp}');

      // Validate that we got a reasonable location (not 0,0 or obviously wrong)
      if (pos.latitude == 0.0 && pos.longitude == 0.0) {
        debugPrint('Warning: Got (0,0) location, this might be invalid');
      }

      setState(() {
        _currentLocation = LatLng(pos.latitude, pos.longitude);
      });

      debugPrint('Current location set successfully');
    } catch (e) {
      debugPrint('Error getting current location: $e');

      // Try to get last known position as fallback
      try {
        debugPrint('Trying to get last known position...');
        Position? lastPos = await Geolocator.getLastKnownPosition();

        if (lastPos != null) {
          debugPrint(
              'Last known location: ${lastPos.latitude}, ${lastPos.longitude}');
          setState(() {
            _currentLocation = LatLng(lastPos.latitude, lastPos.longitude);
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Using last known location. Current location unavailable.'),
                duration: Duration(seconds: 3),
              ),
            );
          }
        } else {
          debugPrint('No last known location available');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Unable to determine your location. Please check your location settings.'),
                duration: Duration(seconds: 5),
              ),
            );
          }
        }
      } catch (lastPosError) {
        debugPrint('Error getting last known position: $lastPosError');
      }

      // Don't rethrow the error, let the app continue without current location
    }
  }

  Future<void> _loadFacilities() async {
    final f = await FacilityRepository.getFacilitiesWithCoordinates();
    setState(() {
      _facilities = f;
    });
  }

  Future<int> _getTotalWorkersByAddress(String address) async {
    try {
      // Count healthcare workers with matching facility.address
      final healthcareSnap = await FirebaseFirestore.instance
          .collection('healthcare')
          .where('facility.address', isEqualTo: address)
          .get();
      int healthcareCount = healthcareSnap.docs.length;

      // Count doctors with matching address in any affiliation
      final doctorsSnap =
          await FirebaseFirestore.instance.collection('doctors').get();
      int doctorCount = 0;
      for (var doc in doctorsSnap.docs) {
        final data = doc.data();
        if (data['affiliations'] is List) {
          for (var aff in data['affiliations']) {
            if (aff is Map && aff['address'] == address) {
              doctorCount++;
            }
          }
        }
      }
      return healthcareCount + doctorCount;
    } catch (e) {
      debugPrint('Error getting worker count: $e');
      return 0;
    }
  }

  void _buildMarkers() {
    final Set<Marker> markers = {};

    // Marker for current location
    if (_currentLocation != null) {
      markers.add(Marker(
        markerId: const MarkerId('current_location'),
        position: _currentLocation!,
        infoWindow: const InfoWindow(title: 'You are here'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ));
    }

    for (int i = 0; i < _facilities.length; i++) {
      final facility = _facilities[i];
      if (facility.coordinates == null) continue;
      final bool isSelected = i == _selectedIndex;
      markers.add(Marker(
        markerId: MarkerId('${facility.name}_$i'),
        position: facility.coordinates!,
        infoWindow: InfoWindow(title: facility.name, snippet: facility.address),
        icon: isSelected
            ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)
            : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        onTap: () => _onMarkerTapped(i),
      ));
    }

    setState(() {
      _markers = markers;
    });
  }

  void _onMarkerTapped(int index) {
    setState(() => _selectedIndex = index);
    _pageController.animateToPage(index,
        duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    final coords = _facilities[index].coordinates;
    if (coords != null) {
      _animateCameraTo(coords, zoom: _zoomLevel + 1);
      _createRouteToFacility(coords);
    }
    _buildMarkers();
  }

  void _onPageChanged(int index) {
    if (index < 0 || index >= _facilities.length) return;
    setState(() => _selectedIndex = index);
    final coords = _facilities[index].coordinates;
    if (coords != null) {
      _animateCameraTo(coords, zoom: _zoomLevel + 1);
      _createRouteToFacility(coords);
    }
    _buildMarkers();
  }

  Future<void> _animateCameraTo(LatLng target, {double zoom = 15.0}) async {
    if (!_mapController.isCompleted) return;
    final controller = await _mapController.future;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
          CameraPosition(target: target, zoom: zoom)),
    );
  }

  Future<void> _createRouteToFacility(LatLng destination) async {
    if (_currentLocation == null) return;
    try {
      final points = await _getDirections(_currentLocation!, destination);
      if (points.isEmpty) {
        setState(() => _polylines = {});
        return;
      }
      final polyline = Polyline(
        polylineId: const PolylineId('route'),
        points: points,
        width: 6,
        color: const Color(0xE0F44336), // Red accent color
      );
      setState(() {
        _polylines = {polyline};
      });
    } catch (e) {
      debugPrint('Error creating route: $e');
    }
  }

  Future<List<LatLng>> _getDirections(LatLng origin, LatLng dest) async {
    final originStr = '${origin.latitude},${origin.longitude}';
    final destStr = '${dest.latitude},${dest.longitude}';
    final url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=$originStr&destination=$destStr&mode=driving&key=$_apiKey';

    final resp = await http.get(Uri.parse(url));
    if (resp.statusCode != 200) {
      throw 'Directions API returned ${resp.statusCode}';
    }
    final json = jsonDecode(resp.body);
    if (json['routes'] == null || (json['routes'] as List).isEmpty) {
      return [];
    }
    final overview = json['routes'][0]['overview_polyline']['points'] as String;
    return _decodePolyline(overview);
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> poly = [];
    int index = 0;
    int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int shift = 0;
      int result = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      final latitude = lat / 1e5;
      final longitude = lng / 1e5;
      poly.add(LatLng(latitude, longitude));
    }

    return poly;
  }

  void _onSeeDirectionsPressed() {
    final facility = _facilities[_selectedIndex];
    if (facility.coordinates == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No coordinates for this facility')));
      return;
    }
    _createRouteToFacility(facility.coordinates!);
  }

  void _onViewContactsPressed() {
    final facility = _facilities[_selectedIndex];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(facility.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(facility.address),
            const SizedBox(height: 8),
            if (facility.email != null && facility.email!.isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.email, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(facility.email!)),
                ],
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _positionStreamSubscription?.cancel(); // 👈 Cancel stream
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isAndroid) {
      return Scaffold(
        appBar: AppBar(title: const Text('Facilities (Android only)')),
        body: const Center(
            child: Text('This map page is intended for Android devices only.')),
      );
    }

    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                      target: _currentLocation ??
                          (_facilities.isNotEmpty &&
                                  _facilities[0].coordinates != null
                              ? _facilities[0].coordinates!
                              : const LatLng(7.0731,
                                  125.6128)), // Davao City center as default
                      zoom: _zoomLevel),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  markers: _markers,
                  polylines: _polylines,
                  onMapCreated: (GoogleMapController controller) {
                    if (!_mapController.isCompleted)
                      _mapController.complete(controller);
                  },
                ),
                Positioned(
                  left: 12,
                  top: 40,
                  child: FloatingActionButton.small(
                    heroTag: 'btn-recenter',
                    onPressed: () {
                      if (_currentLocation != null)
                        _animateCameraTo(_currentLocation!, zoom: _zoomLevel);
                    },
                    child: const Icon(Icons.my_location),
                  ),
                ),
                // List View Floating Button
                Positioned(
                  right: 16,
                  bottom: 280, // Position above the container
                  child: FloatingActionButton.extended(
                    heroTag: 'btn-list-view',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const glist.GListFacility(),
                        ),
                      );
                    },
                    backgroundColor: const Color(0xE0F44336),
                    foregroundColor: Colors.white,
                    icon: const Icon(Icons.list_rounded, size: 20),
                    label: const Text('List View',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SafeArea(
                    child: SizedBox(
                      height: 260, // Reduced height to prevent overflow
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: _facilities.length,
                        onPageChanged: _onPageChanged,
                        itemBuilder: (context, index) {
                          final facility = _facilities[index];
                          final bool isSelected = index == _selectedIndex;

                          return FutureBuilder<int>(
                            future: _getTotalWorkersByAddress(facility.address),
                            builder: (context, snapshot) {
                              final count = snapshot.data ?? 0;
                              final isActive = count > 0;

                              return Container(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isSelected
                                          ? Colors.grey.shade300
                                          : Colors.grey.shade100,
                                      blurRadius: isSelected ? 12 : 8,
                                      offset: isSelected
                                          ? const Offset(0, 4)
                                          : const Offset(0, 2),
                                      spreadRadius: 0,
                                    ),
                                  ],
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xE0F44336)
                                            .withOpacity(0.2)
                                        : Colors.grey.shade100,
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(
                                      12), // Reduced padding
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          // Modern Facility Icon
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  const Color(0xE0F44336)
                                                      .withOpacity(0.1),
                                                  const Color(0xE0F44336)
                                                      .withOpacity(0.05),
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: const Icon(
                                              Icons.local_hospital_rounded,
                                              color: Color(0xE0F44336),
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          // Facility Name and Status
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  facility.name,
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF1A1A1A),
                                                    letterSpacing: -0.2,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: isActive
                                                        ? const Color(
                                                                0xFF10B981)
                                                            .withOpacity(0.1)
                                                        : Colors.grey.shade100,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Container(
                                                        width: 4,
                                                        height: 4,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: isActive
                                                              ? const Color(
                                                                  0xFF10B981)
                                                              : Colors.grey
                                                                  .shade400,
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        isActive
                                                            ? 'Active'
                                                            : 'No Workers',
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: isActive
                                                              ? const Color(
                                                                  0xFF10B981)
                                                              : Colors.grey
                                                                  .shade600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      // Address with modern styling
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade50,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.location_on_rounded,
                                              color: Color(0xFF6B7280),
                                              size: 14,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                facility.address,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0xFF374151),
                                                  height: 1.4,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      // Health Workers Count
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 8),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              const Color(0xE0F44336)
                                                  .withOpacity(0.08),
                                              const Color(0xE0F44336)
                                                  .withOpacity(0.04),
                                            ],
                                            begin: Alignment.centerLeft,
                                            end: Alignment.centerRight,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                            color: const Color(0xE0F44336)
                                                .withOpacity(0.1),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: const Color(0xE0F44336)
                                                    .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: const Icon(
                                                Icons.people_rounded,
                                                color: Color(0xE0F44336),
                                                size: 12,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '$count Health Worker${count != 1 ? 's' : ''} Available',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xE0F44336),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      // Buttons section - made more compact
                                      Row(
                                        children: [
                                          Expanded(
                                            child: ElevatedButton(
                                              onPressed: () =>
                                                  _onViewContactsPressed(),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    const Color(0xE0F44336),
                                                foregroundColor: Colors.white,
                                                elevation: 0,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                padding: const EdgeInsets
                                                    .symmetric(
                                                    vertical:
                                                        8), // Reduced padding
                                                minimumSize: const Size(
                                                    0, 36), // Set minimum size
                                              ),
                                              child: const Text('Contacts',
                                                  style: TextStyle(
                                                      fontSize:
                                                          11, // Reduced font size
                                                      fontWeight:
                                                          FontWeight.w600)),
                                            ),
                                          ),
                                          const SizedBox(
                                              width: 8), // Reduced spacing
                                          Expanded(
                                            child: OutlinedButton(
                                              onPressed: () =>
                                                  _onSeeDirectionsPressed(),
                                              style: OutlinedButton.styleFrom(
                                                side: const BorderSide(
                                                    color: Color(0xE0F44336),
                                                    width: 1.5),
                                                foregroundColor:
                                                    const Color(0xE0F44336),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                padding: const EdgeInsets
                                                    .symmetric(
                                                    vertical:
                                                        8), // Reduced padding
                                                minimumSize: const Size(
                                                    0, 36), // Set minimum size
                                              ),
                                              child: const Text('Directions',
                                                  style: TextStyle(
                                                      fontSize:
                                                          11, // Reduced font size
                                                      fontWeight:
                                                          FontWeight.w600)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
