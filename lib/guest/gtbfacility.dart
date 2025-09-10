import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class GtbfacilityPage extends StatefulWidget {
  const GtbfacilityPage({super.key});

  @override
  State<GtbfacilityPage> createState() => _GtbfacilityPageState();
}

class _GtbfacilityPageState extends State<GtbfacilityPage> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  final Set<Marker> _markers = {};
  bool _isLoading = true;

  // Davao City center coordinates
  final LatLng _davaoCenter = const LatLng(7.0707, 125.6087);

  // TB DOTS Facilities data
  final List<Map<String, dynamic>> _facilities = [
    {
      "name": "Southern Philippines Medical Center",
      "address": "JP Laurel Ave, Bajada, Davao City",
      "position": const LatLng(7.0907, 125.6126),
    },
    {
      "name": "Davao City Health Office",
      "address": "Pichon Street, Davao City",
      "position": const LatLng(7.0722, 125.6127),
    },
    {
      "name": "Talomo District Health Center",
      "address": "Talomo, Davao City",
      "position": const LatLng(7.0503, 125.5989),
    },
    {
      "name": "Buhangin District Health Center",
      "address": "Buhangin, Davao City",
      "position": const LatLng(7.1044, 125.6297),
    },
    {
      "name": "Toril District Health Center",
      "address": "Toril, Davao City",
      "position": const LatLng(7.0247, 125.5019),
    },
  ];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _addFacilityMarkers();
  }

  void _addFacilityMarkers() {
    for (var facility in _facilities) {
      setState(() {
        _markers.add(
          Marker(
            markerId: MarkerId(facility['name']),
            position: facility['position'],
            infoWindow: InfoWindow(
              title: facility['name'],
              snippet: facility['address'],
            ),
            icon:
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          ),
        );
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _isLoading = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isLoading = false);
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _markers.add(
            Marker(
              markerId: const MarkerId('currentLocation'),
              position: LatLng(position.latitude, position.longitude),
              infoWindow: const InfoWindow(title: 'Your Location'),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueBlue),
            ),
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'TB DOTS Facilities',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.redAccent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : kIsWeb
              ? Container(
                  // Add a container for web
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _currentPosition != null
                          ? LatLng(
                              _currentPosition!.latitude,
                              _currentPosition!.longitude,
                            )
                          : _davaoCenter,
                      zoom: 12,
                    ),
                    markers: _markers,
                    mapType: MapType.normal,
                    myLocationEnabled: false, // Disable for web
                    myLocationButtonEnabled: false, // Disable for web
                    zoomControlsEnabled: true,
                    mapToolbarEnabled: true,
                    trafficEnabled: true,
                    onMapCreated: (GoogleMapController controller) {
                      _mapController = controller;
                      // Force a rebuild after map is created to ensure markers are added properly
                      if (mounted) setState(() {});
                    },
                  ),
                )
              : GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _currentPosition != null
                        ? LatLng(
                            _currentPosition!.latitude,
                            _currentPosition!.longitude,
                          )
                        : _davaoCenter,
                    zoom: 12,
                  ),
                  markers: _markers,
                  mapType: MapType.normal,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: true,
                  mapToolbarEnabled: true,
                  trafficEnabled: true,
                  buildingsEnabled: true,
                  compassEnabled: true,
                  indoorViewEnabled: true,
                  onMapCreated: (GoogleMapController controller) {
                    _mapController = controller;
                    if (mounted) setState(() {});
                  },
                ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
