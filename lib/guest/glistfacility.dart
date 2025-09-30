import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'ghealthworkers.dart';

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
  Future<int> _getTotalWorkersByAddress(String address) async {
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
  }

  final TextEditingController _searchController = TextEditingController();
  List<Facility> filteredFacilities = [];

  @override
  void initState() {
    super.initState();
    filteredFacilities = facilities;
    _searchController.addListener(_filterFacilities);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterFacilities() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        filteredFacilities = facilities;
      } else {
        filteredFacilities = facilities.where((facility) {
          return facility.name.toLowerCase().contains(query) ||
              facility.address.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  // Static list of 19 TB DOTS facilities
  static final List<Facility> facilities = [
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
      address: "Daang Maharlika Highway, Bunawan, Davao City",
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Back Button
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade300,
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios,
                        color: Color(0xE0F44336)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const Text(
                  "TB DOTS Facilities",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xE0F44336),
                  ),
                ),
                const SizedBox(width: 48), // spacing balance
              ],
            ),
          ),
          // Modern Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade200,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {}); // Refresh UI to show/hide clear button
                },
                decoration: InputDecoration(
                  hintText: 'Search facilities...',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 16,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Colors.grey.shade500,
                    size: 22,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear,
                            color: Colors.grey.shade500,
                            size: 20,
                          ),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF2C3E50),
                ),
              ),
            ),
          ),
          // Results count
          if (_searchController.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '${filteredFacilities.length} result${filteredFacilities.length != 1 ? 's' : ''} found',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          // Facilities List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('affiliation')
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
                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      'Error loading facilities',
                      style: TextStyle(color: Colors.red),
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
        return GestureDetector(
          onTap: () {
            if (isActive) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GHealthWorkers(
                    facilityId: '',
                    facilityName: facility.name,
                    facilityAddress: facility.address,
                  ),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('No health workers found for ${facility.name}'),
                  backgroundColor: Colors.orange,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            }
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade100,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                  spreadRadius: 0,
                ),
              ],
              border: Border.all(
                color: Colors.grey.shade100,
                width: 1,
              ),
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
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xE0F44336).withOpacity(0.1),
                              const Color(0xE0F44336).withOpacity(0.05),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
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
                      // Modern Arrow Icon
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xE0F44336).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: Color(0xE0F44336),
                          size: 12,
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
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Row(
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
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Health Workers Count
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xE0F44336).withOpacity(0.08),
                          const Color(0xE0F44336).withOpacity(0.04),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xE0F44336).withOpacity(0.1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xE0F44336).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
