import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class GtbfacilityPage extends StatefulWidget {
  const GtbfacilityPage({super.key});

  @override
  State<GtbfacilityPage> createState() => _GtbfacilityPageState();
}

class _GtbfacilityPageState extends State<GtbfacilityPage> {
  final MapController _mapController = MapController();

  final List<Map<String, dynamic>> facilities = [
    {
      'name': 'AGDAO',
      'location': 'Agdao Public Market Corner Lapu-Lapu & C. Bangoy St., Agdao, Davao City',
      'lat': 7.0862,
      'lng': 125.6264,
    },
    {
      'name': 'BAGUIO (MALAGOS HC)',
      'location': 'Purok 2A Malagos, Baguio District, Davao City',
      'lat': 7.1886,
      'lng': 125.3576,
    },
    {
      'name': 'BUHANGIN (NHA BUHANGIN HC)',
      'location': 'NHA Chapet St., Buhangin, Davao City',
      'lat': 7.1245,
      'lng': 125.6131,
    },
    // Add more here as needed
  ];

  Widget _buildFacilityCard(Map<String, dynamic> facility) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.local_hospital, size: 40, color: Colors.redAccent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    facility['name'],
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    facility['location'],
                    style: const TextStyle(color: Colors.black87),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Fixed center location (Davao City)
    final LatLng centerLocation = LatLng(7.0731, 125.6127);

    return Scaffold(
      appBar: AppBar(title: const Text('TB DOTS Facilities Locator')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Locations Nearby',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('${facilities.length} available facilities'),
                const SizedBox(height: 8),
                const Text('Current location feature disabled'),
              ],
            ),
          ),
          SizedBox(
            height: 200,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                onTap: (tapPosition, latLng) {
                  // Handle map tap
                  print("Tapped at: $latLng");
                },
                crs: const Epsg3857(),
              ),
              children: [
                TileLayer(
                  urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                  subdomains: const ['a', 'b', 'c'],
                ),
                MarkerLayer(
                  markers: facilities.map(
                    (facility) => Marker(
                      point: LatLng(facility['lat'], facility['lng']),
                      child: const Icon(
                        Icons.local_hospital,
                        size: 30,
                        color: Colors.red,
                      ),
                    ),
                  ).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView(
              children: facilities.map((f) => _buildFacilityCard(f)).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
