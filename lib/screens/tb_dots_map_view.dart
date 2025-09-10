import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../data/tb_dots_facilities.dart';

class TBDotsFacilitiesMap extends StatefulWidget {
  const TBDotsFacilitiesMap({super.key});

  @override
  State<TBDotsFacilitiesMap> createState() => _TBDotsFacilitiesMapState();
}

class _TBDotsFacilitiesMapState extends State<TBDotsFacilitiesMap> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  Set<Marker> _markers = {};
  bool _isLoading = true;

  // Davao City center coordinates
  static const LatLng _davaoCenter = LatLng(7.0707, 125.6087);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getCurrentLocation();
      _loadTBDotsFacilities();
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = position;
        _isLoading = false;
      });

      _addCurrentLocationMarker();
    } catch (e) {
      debugPrint('Error getting current location: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _loadTBDotsFacilities() {
    setState(() {
      _markers.addAll(
        tbDotsFacilities.map(
          (facility) => Marker(
            markerId: MarkerId(facility.name),
            position: LatLng(facility.latitude, facility.longitude),
            infoWindow: InfoWindow(
              title: facility.name,
              snippet: '${facility.address}\n'
                  '${facility.phoneNumber != null ? 'Phone: ${facility.phoneNumber}\n' : ''}'
                  '${facility.operatingHours != null ? 'Hours: ${facility.operatingHours}' : ''}',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueRed,
            ),
          ),
        ),
      );
    });
  }

  void _addCurrentLocationMarker() {
    if (_currentPosition != null) {
      setState(() {
        _markers.add(
          Marker(
            markerId: const MarkerId('currentLocation'),
            position: LatLng(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
            ),
            infoWindow: const InfoWindow(
              title: 'Your Location',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueBlue,
            ),
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'TB DOTS Facilities',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
              ),
        ),
        backgroundColor: Colors.redAccent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _currentPosition != null
                    ? LatLng(
                        _currentPosition!.latitude,
                        _currentPosition!.longitude,
                      )
                    : _davaoCenter,
                zoom: 13,
              ),
              onMapCreated: (controller) => _mapController = controller,
              markers: _markers,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              mapToolbarEnabled: true,
              zoomControlsEnabled: true,
              zoomGesturesEnabled: true,
            ),
    );
  }
}
