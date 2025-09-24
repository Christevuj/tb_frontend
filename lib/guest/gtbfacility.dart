// gtb_facility_page.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:tb_frontend/models/facility.dart';

// Replace this import with the actual path in your project:
import 'package:tb_frontend/services/facility_repository.dart';

class GtbfacilityPage extends StatefulWidget {
  const GtbfacilityPage({super.key});

  @override
  _GtbfacilityPageState createState() => _GtbfacilityPageState();
}

class _GtbfacilityPageState extends State<GtbfacilityPage> {
  final Completer<GoogleMapController> _mapController = Completer();
  final PageController _pageController = PageController(viewportFraction: 0.94);
  final String _apiKey = 'YOUR_GOOGLE_MAPS_API_KEY_HERE'; // or load from secure storage

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
          accuracy: LocationAccuracy.best,
          distanceFilter: 5, // update every 5 meters
        ),
      ).listen((Position pos) {
        final LatLng newPos = LatLng(pos.latitude, pos.longitude);

        setState(() {
          _currentLocation = newPos;
        });

        // Move map with you like Google Maps
        _animateCameraTo(newPos, zoom: _zoomLevel);

        // Rebuild "You are here" marker
        _buildMarkers();
      });

      await _loadFacilities();
      _buildMarkers();

      // center map on first facility or current location
      if (_facilities.isNotEmpty && _facilities[0].coordinates != null) {
        _animateCameraTo(_facilities[0].coordinates!, zoom: _zoomLevel);
      } else if (_currentLocation != null) {
        _animateCameraTo(_currentLocation!, zoom: _zoomLevel);
      }
    } catch (e) {
      debugPrint('Init error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _ensureLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw 'Location services are disabled.';
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw 'Location permission denied';
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw 'Location permission denied forever';
    }
  }

  Future<void> _getCurrentLocation() async {
    Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best);
    setState(() {
      _currentLocation = LatLng(pos.latitude, pos.longitude);
    });
  }

  Future<void> _loadFacilities() async {
    final f = await FacilityRepository.getFacilitiesWithCoordinates();
    setState(() {
      _facilities = f;
    });
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
        markerId: MarkerId(facility.name + '_$i'),
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
      CameraUpdate.newCameraPosition(CameraPosition(target: target, zoom: zoom)),
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

  Future<void> _openExternalMaps(LatLng dest) async {
    final googleUrl = 'google.navigation:q=${dest.latitude},${dest.longitude}';
    if (await canLaunchUrl(Uri.parse(googleUrl))) {
      await launchUrl(Uri.parse(googleUrl));
    } else {
      final mapsUrl =
          'https://www.google.com/maps/dir/?api=1&destination=${dest.latitude},${dest.longitude}';
      if (await canLaunchUrl(Uri.parse(mapsUrl))) {
        await launchUrl(Uri.parse(mapsUrl));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open maps app.')));
      }
    }
  }

  void _onSeeDirectionsPressed() {
    final facility = _facilities[_selectedIndex];
    if (facility.coordinates == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No coordinates for this facility')));
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
            if (facility.address != null) Text(facility.address!),
            const SizedBox(height: 8),
            if (facility.email != null)
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

  Widget _buildBottomCard() {
    if (_facilities.isEmpty) {
      return const SizedBox.shrink();
    }
    final facility = _facilities[_selectedIndex];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.local_hospital, color: Colors.red),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(facility.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    child: Text(
                      facility.address ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _onViewContactsPressed,
                  style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 12)),
                  child: const Text('View Contacts'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _onSeeDirectionsPressed,
                  style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 12)),
                  child: const Text('See Directions'),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isAndroid) {
      return Scaffold(
        appBar: AppBar(title: const Text('Facilities (Android only)')),
        body: const Center(child: Text('This map page is intended for Android devices only.')),
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
                          (_facilities.isNotEmpty && _facilities[0].coordinates != null
                              ? _facilities[0].coordinates!
                              : const LatLng(7.1907, 125.4553)),
                      zoom: _zoomLevel),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  markers: _markers,
                  polylines: _polylines,
                  onMapCreated: (GoogleMapController controller) {
                    if (!_mapController.isCompleted) _mapController.complete(controller);
                  },
                ),
                Positioned(
                  left: 12,
                  top: 40,
                  child: FloatingActionButton.small(
                    heroTag: 'btn-recenter',
                    onPressed: () {
                      if (_currentLocation != null) _animateCameraTo(_currentLocation!, zoom: _zoomLevel);
                    },
                    child: const Icon(Icons.my_location),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 160,
                          child: PageView.builder(
                            controller: _pageController,
                            itemCount: _facilities.length,
                            onPageChanged: _onPageChanged,
                            itemBuilder: (context, index) {
                              final f = _facilities[index];
                              final bool selected = index == _selectedIndex;
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                child: Material(
                                  elevation: selected ? 6 : 2,
                                  borderRadius: BorderRadius.circular(12),
                                  child: InkWell(
                                    onTap: () {
                                      _onMarkerTapped(index);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        color: Colors.white,
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 54,
                                            height: 54,
                                            decoration: BoxDecoration(
                                              color: Colors.red.shade50,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Icon(Icons.local_hospital, color: Colors.red),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text(f.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                                const SizedBox(height: 6),
                                                Text(f.address ?? '', style: const TextStyle(fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            icon: const Icon(Icons.directions),
                                            onPressed: () {
                                              _onMarkerTapped(index);
                                              _onSeeDirectionsPressed();
                                            },
                                          )
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          child: _buildBottomCard(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
