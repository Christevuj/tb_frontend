import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geocoding/geocoding.dart';

// TODO: Load this from secure storage, .env, or local.properties for production
const String googleAPIKey = "AIzaSyB1qCMW00SQ5345y6l9SiVOaZn6rSyXpcs";

class GtbfacilityPage extends StatefulWidget {
  const GtbfacilityPage({super.key});

  @override
  State<GtbfacilityPage> createState() => _GtbfacilityPageState();
}

class _GtbfacilityPageState extends State<GtbfacilityPage> {
  final Completer<GoogleMapController> _controller = Completer();
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  Position? _currentPosition;
  late PolylinePoints polylinePoints;

  final List<Map<String, String>> _facilities = [
    {
      "name": "AGDAO",
      "address": "Agdao Public Market Corner Lapu-Lapu & C. Bangoy St., Agdao, Davao City",
      "email": "agdaohealthcenter@gmail.com"
    },
    {
      "name": "BAGUIO (MALAGOS HC)",
      "address": "Purok 2A Malagos, Baguio District, Davao City",
      "email": "baguiodistricthealthcenter@gmail.com"
    },
    {
      "name": "BUHANGIN (NHA BUHANGIN HC)",
      "address": "NHA Chapet St., Buhangin, Davao City",
      "email": "buhanginhealthdistrict01@gmail.com"
    },
    {
      "name": "BUNAWAN",
      "address": "Daang Maharlika Highway, Bunawan, Davao City",
      "email": "bunawandistrict2020@gmail.com"
    },
    {
      "name": "CALINAN",
      "address": "P34, Aurora St., Calinan, Davao City",
      "email": "calinanruralhealthcenter@gmail.com"
    },
    {
      "name": "DAVAO CHEST CENTER",
      "address": "Villa Abrille St., Brgy 30-C, Davao City",
      "email": "davaochestcenter2021@gmail.com"
    },
    {
      "name": "DISTRICT A (TOMAS CLAUDIO HC)",
      "address": "Camus Ext., Corner Quirino St., Davao City",
      "email": "tomasclaudiohc.davao@gmail.com"
    },
    {
      "name": "DISTRICT B (EL RIO HC)",
      "address": "Garcia Heights, Bajada, Davao City",
      "email": "bdistrict20@gmail.com"
    },
    {
      "name": "DISTICT C (MINIFOREST HC)",
      "address": "Brgy 23-C, Quezon Boulevard, Davao City",
      "email": "districtc2020@gmail.com"
    },
    {
      "name": "DISTRICT D (JACINTO HC)",
      "address": "Emilio Jacinto St., Davao City",
      "email": "healthcenterjacinto@gmail.com"
    },
    {
      "name": "MARILOG (MARAHAN HC)",
      "address": "Sitio Marahan, Brgy. Marilog, Davao City",
      "email": "dmarilog@gmail.com"
    },
    {
      "name": "PAQUIBATO (MALABOG HC)",
      "address": "Brgy Malabog, Davao City",
      "email": ""
    },
    {
      "name": "SASA",
      "address": "Bangoy Km 9,  Sasa, Davao City",
      "email": "sasadistrict@gmail.com"
    },
    {
      "name": "TALOMO CENTRAL (GSIS HC)",
      "address": "GSIS Village, Matina, Davao City",
      "email": "talcencho@gmail.com"
    },
    {
      "name": "TALOMO NORTH (SIR HC)",
      "address": "Daang Patnubay St., SIR Ph-1 Sandawa Road, Brgy., 76-A, Bucana, Matina, Davao City",
      "email": "northtalomo2019@gmail.com"
    },
    {
      "name": "TALOMO SOUTH (PUAN HC)",
      "address": "Puan, Talomo, Davao City",
      "email": "talomo.south@gmail.com"
    },
    {
      "name": "TORIL A",
      "address": "Agton St., Toril, Davao City",
      "email": "torilhealthcenter2@gmail.com"
    },
    {
      "name": "TORIL B",
      "address": "Juan Dela Cruz St., Daliao, Toril, Davao City",
      "email": "chotorilb@gmail.com"
    },
    {
      "name": "TUGBOK",
      "address": "Sampaguita St., Mintal, Tugbok District, Davao City",
      "email": "tugbokruralhealthunit@gmail.com"
    },
  ];

  @override
  void initState() {
    super.initState();
    polylinePoints = PolylinePoints(apiKey: googleAPIKey);
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    setState(() {
      _currentPosition = position;
    });

    await _addMarkers();
    _moveCamera();
  }

  Future<void> _moveCamera() async {
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(
        target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        zoom: 13,
      ),
    ));
  }

  Future<void> _addMarkers() async {
    for (var facility in _facilities) {
      try {
        final List<Location> locations =
            await locationFromAddress(facility['address']!);
        if (locations.isNotEmpty) {
          final LatLng position = LatLng(
              locations.first.latitude, locations.first.longitude);
          _markers.add(
            Marker(
              markerId: MarkerId(facility['name']!),
              position: position,
              infoWindow: InfoWindow(
                title: facility['name'],
                snippet: facility['address'],
                onTap: () => _showBottomSheet(facility, position),
              ),
            ),
          );
        }
      } catch (e) {
        debugPrint("Geocoding failed for ${facility['address']}: $e");
      }
    }
    setState(() {});
  }

  void _showBottomSheet(Map<String, String> facility, LatLng location) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(facility['name']!,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(facility['address']!),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.directions),
                  label: const Text("Directions"),
                  onPressed: () => _showDirections(location),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.email),
                  label: const Text("Contact"),
                  onPressed: () async {
                    final email = facility['email'];
                    if (email != null && email.isNotEmpty) {
                      final uri = Uri.parse("mailto:$email");
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      }
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDirections(LatLng destination) async {
    if (_currentPosition == null) return;

    final result = await polylinePoints.getRouteBetweenCoordinates(
      request: PolylineRequest(
        origin: PointLatLng(
            _currentPosition!.latitude, _currentPosition!.longitude),
        destination: PointLatLng(destination.latitude, destination.longitude),
        mode: TravelMode.driving,
      ),
    );

    if (result.points.isNotEmpty) {
      List<LatLng> polylineCoordinates = result.points
          .map((p) => LatLng(p.latitude, p.longitude))
          .toList();
      setState(() {
        _polylines.clear();
        _polylines.add(
          Polyline(
            polylineId: const PolylineId("route"),
            points: polylineCoordinates,
            width: 5,
            color: Colors.blue,
          ),
        );
      });
    } else {
      debugPrint("No route found: ${result.errorMessage}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("TBisita Facilities")),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.my_location),
        onPressed: _getCurrentLocation,
      ),
      body: _currentPosition == null
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(_currentPosition!.latitude,
                    _currentPosition!.longitude),
                zoom: 13,
              ),
              onMapCreated: (controller) => _controller.complete(controller),
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              markers: _markers,
              polylines: _polylines,
            ),
    );
  }
}
