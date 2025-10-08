import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'ghealthworkers.dart';
import 'gtbfacility.dart';

class Facility {
  final String name;
  final String address;

  Facility({required this.name, required this.address});
}

class GListFacility extends StatefulWidget {
  const GListFacility({super.key});

  @override
  State<GListFacility> createState() => _GListFacilityState();
}

class _GListFacilityState extends State<GListFacility> {
  final TextEditingController _searchController = TextEditingController();
  List<Facility> filteredFacilities = [];

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

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      final query = _searchController.text.toLowerCase();
      setState(() {
        if (query.isEmpty) {
          filteredFacilities = facilities;
        } else {
          filteredFacilities = facilities
              .where((facility) =>
                  facility.name.toLowerCase().contains(query) ||
                  facility.address.toLowerCase().contains(query))
              .toList();
        }
      });
    });
    filteredFacilities = facilities;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  final List<Facility> facilities = [
    Facility(
      name: "AGDAO",
      address:
          "Agdao Public Market Corner Lapu-Lapu & C. Bangoy St., Agdao, Davao City",
    ),
    Facility(
      name: "BAGUIO (MALAGOS HC)",
      address: "Purok 2A Malagos, Baguio District, Davao City",
    ),
    Facility(
      name: "BUHANGIN (NHA BUHANGIN HC)",
      address: "NHA Chapet St., Buhangin, Davao City",
    ),
    Facility(
      name: "BUNAWAN",
      address: "Bunawan District Health Center, Davao City",
    ),
    Facility(
      name: "CALINAN",
      address: "P34, Aurora St., Calinan, Davao City",
    ),
    Facility(
      name: "DAVAO CHEST CENTER",
      address: "Villa Abrille St., Brgy 30-C, Davao City",
    ),
    Facility(
      name: "DISTRICT A (TOMAS CLAUDIO HC)",
      address: "Camus Ext., Corner Quirino Ave., Davao City",
    ),
    Facility(
      name: "DISTRICT B (EL RIO HC)",
      address: "Garcia Heights, Bajada, Davao City",
    ),
    Facility(
      name: "DISTICT C (MINIFOREST HC)",
      address: "Brgy 23-C, Quezon Boulevard, Davao City",
    ),
    Facility(
      name: "DISTRICT D (JACINTO HC)",
      address: "Emilio Jacinto St., Davao City",
    ),
    Facility(
      name: "MARILOG (MARAHAN HC)",
      address: "Sitio Marahan, Brgy. Marilog, Davao City",
    ),
    Facility(
      name: "PAQUIBATO (MALABOG HC)",
      address: "Brgy Malabog, Davao City",
    ),
    Facility(
      name: "SASA",
      address: "Bangoy Km 9,  Sasa, Davao City",
    ),
    Facility(
      name: "TALOMO CENTRAL (GSIS HC)",
      address: "GSIS Village, Matina, Davao City",
    ),
    Facility(
      name: "TALOMO NORTH (SIR HC)",
      address: "Daang Patnubay St., SIR Ph-1, Sandawa, Davao City",
    ),
    Facility(
      name: "TALOMO SOUTH (PUAN HC)",
      address: "Puan, Talomo, Davao City",
    ),
    Facility(
      name: "TORIL A",
      address: "Agton St., Toril, Davao City",
    ),
    Facility(
      name: "TORIL B",
      address: "Juan Dela Cruz St., Daliao, Toril, Davao City",
    ),
    Facility(
      name: "TUGBOK",
      address: "Sampaguita St., Mintal, Tugbok District, Davao City",
    ),
  ];

  void _onViewContactsPressed(Facility facility) {
    // Navigate directly to GHealthWorkers page with the selected facility
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GHealthWorkers(
          facilityId: facility
              .name, // Use facility name as ID since queries use address
          facilityName: facility.name,
          facilityAddress: facility.address,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xE0F44336),
        elevation: 0,
        title: const Text(
          'Health Facilities',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xE0F44336),
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search facilities...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
            ),
          ),
          // Facility List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('facilities')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xE0F44336)),
                    ),
                  );
                }
                // Create a map of Firebase facilities for quick lookup
                Map<String, String> firebaseFacilities = {};
                if (snapshot.hasData) {
                  for (var doc in snapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    firebaseFacilities[data['name']] = doc.id;
                  }
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredFacilities.length,
                  itemBuilder: (context, index) {
                    final facility = filteredFacilities[index];
                    return _buildFacilityCard(
                      context,
                      facility,
                      firebaseFacilities[facility.name],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFacilityCard(
      BuildContext context, Facility facility, String? facilityId) {
    return FutureBuilder<int>(
      future: _getTotalWorkersByAddress(facility.address),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        final isActive = count > 0;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Modern Facility Icon
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xE0F44336),
                            const Color(0xE0F44336).withOpacity(0.8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xE0F44336).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.local_hospital_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Facility Name and Status
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? const Color(0xFF10B981).withOpacity(0.1)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? const Color(0xFF10B981)
                                        : Colors.grey.shade400,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isActive ? 'Active' : 'No Workers',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: isActive
                                        ? const Color(0xFF10B981)
                                        : Colors.grey.shade600,
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
                const SizedBox(height: 6),
                // Address with modern styling
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.grey.shade200,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
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
                const SizedBox(height: 4),
                // Health Workers Count
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xE0F44336).withOpacity(0.1),
                        const Color(0xE0F44336).withOpacity(0.05),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xE0F44336).withOpacity(0.2),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xE0F44336).withOpacity(0.1),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xE0F44336),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xE0F44336).withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.people_rounded,
                          color: Colors.white,
                          size: 14,
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
                const SizedBox(height: 4),
                // Buttons section - sleek design
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _onViewContactsPressed(facility),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xE0F44336),
                          foregroundColor: Colors.white,
                          elevation: 4,
                          shadowColor: const Color(0xE0F44336).withOpacity(0.3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'Contacts',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          // Navigate to map view with selected facility
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (context) => GtbfacilityPage(
                                selectedFacilityName: facility.name,
                                selectedFacilityAddress: facility.address,
                              ),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: Color(0xE0F44336),
                            width: 2,
                          ),
                          foregroundColor: const Color(0xE0F44336),
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'See Directions',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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
  }
}
