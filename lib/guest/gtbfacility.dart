import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class GtbfacilityPage extends StatefulWidget {
  const GtbfacilityPage({super.key});

  @override
  State<GtbfacilityPage> createState() => _GtbfacilityPageState();
}

class _GtbfacilityPageState extends State<GtbfacilityPage> {
  final Completer<GoogleMapController> _controller = Completer();
  LatLng? _currentLocation;
  final Map<MarkerId, Marker> _markers = {};
  List<LatLng> _routeCoords = [];
  Map<String, dynamic>? _selectedFacility;

  final List<Map<String, String>> facilities = [
    {
      "name": "AGDAO",
      "address":
          "Agdao Public Market Corner Lapu-Lapu & C. Bangoy St., Agdao, Davao City",
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
      "address":
          "Daang Patnubay St., SIR Ph-1 Sandawa Road, Brgy., 76-A, Bucana, Matina, Davao City",
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
    }
  ];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    setState(() {
      _currentLocation = LatLng(position.latitude, position.longitude);
    });

    _addFacilityMarkers();
  }

  void _addFacilityMarkers() {
    for (var facility in facilities) {
      final markerId = MarkerId(facility["name"]!);
      final marker = Marker(
        markerId: markerId,
        position: _getRandomLatLng(), // Replace with actual coordinates later
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        onTap: () {
          setState(() {
            _selectedFacility = facility;
          });
        },
      );
      _markers[markerId] = marker;
    }
    setState(() {});
  }

  Future<void> _getDirections(LatLng destination) async {
    final apiKey = "YOUR_GOOGLE_MAPS_API_KEY";
    final origin =
        "${_currentLocation!.latitude},${_currentLocation!.longitude}";
    final dest = "${destination.latitude},${destination.longitude}";
    final url =
        "https://maps.googleapis.com/maps/api/directions/json?origin=$origin&destination=$dest&key=$apiKey";

    final response = await http.get(Uri.parse(url));
    final data = json.decode(response.body);

    if (data["routes"].isNotEmpty) {
      final points = data["routes"][0]["overview_polyline"]["points"];
      _routeCoords = _decodePolyline(points);
      setState(() {});
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      poly.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return poly;
  }

  LatLng _getRandomLatLng() {
    // Placeholder until you put actual coordinates
    return LatLng(7.0731, 125.6136);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _currentLocation == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GoogleMap(
                  onMapCreated: (controller) =>
                      _controller.complete(controller),
                  initialCameraPosition: CameraPosition(
                    target: _currentLocation!,
                    zoom: 14,
                  ),
                  markers: Set<Marker>.of(_markers.values),
                  polylines: {
                    Polyline(
                      polylineId: const PolylineId('route'),
                      points: _routeCoords,
                      color: Colors.blue,
                      width: 5,
                    )
                  },
                  myLocationEnabled: true,
                ),
                if (_selectedFacility != null)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Card(
                      margin: const EdgeInsets.all(10),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_selectedFacility!["name"]!,
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(_selectedFacility!["address"]!),
                            Text(_selectedFacility!["email"] ?? "No email"),
                            Row(
                              children: [
                                ElevatedButton(
                                  onPressed: () {
                                    // Replace with actual lat/lng
                                    _getDirections(LatLng(7.0731, 125.6136));
                                  },
                                  child: Text("Directions"),
                                ),
                                const SizedBox(width: 10),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.pushNamed(
                                        context, '/ghealthworkers');
                                  },
                                  child: Text("Contact"),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
              ],
            ),
    );
  }
}
