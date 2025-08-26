import 'package:flutter/material.dart';
import 'package:tb_frontend/patient/doctorviewpage.dart';

class Pdoclist extends StatefulWidget {
  const Pdoclist({super.key});

  @override
  State<Pdoclist> createState() => _PdoclistState();
}

class _PdoclistState extends State<Pdoclist> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  final List<Map<String, dynamic>> doctors = [
    {
      "name": "Dr. Zubaear Rahim",
      "specialty": "MD, Pulmonologist",
      "location": "Davao Doctors Hospital",
      "image": "assets/images/doc1.png",
    },
    {
      "name": "Dr. Arlyn Santos",
      "specialty": "MD, Pulmonologist",
      "location": "Chest Center",
      "image": "assets/images/doc2.png",
    },
    {
      "name": "Dr. Miguel Rosales",
      "specialty": "MD, Pulmonologist",
      "location": "Talomo South Health Center",
      "image": "assets/images/doc3.png",
    },
    {
      "name": "Dr. Lianne Ortega",
      "specialty": "MD, Pulmonologist",
      "location": "Southern Philippines Medical Center",
      "image": "assets/images/doc2.png",
    },
    {
      "name": "Dr. Carlos Buenafe",
      "specialty": "MD, Pulmonologist",
      "location": "Southern Philippines Medical Center",
      "image": "assets/images/doc3.png",
    },
  ];

  @override
  Widget build(BuildContext context) {
    // Filter doctors list by search query
    final filteredDoctors = doctors.where((doc) {
      final name = doc['name'].toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F5),
      body: SafeArea(   // ✅ FIX: Move SafeArea here
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back and Search container
              Row(
                children: [
                  // Circular Back button
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.shade300,
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.pink),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Search bar
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade300,
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onChanged: (value) {
                                setState(() {
                                  _searchQuery = value;
                                });
                              },
                              decoration: const InputDecoration(
                                hintText: "Search a doctor",
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.search, color: Colors.pink),
                            onPressed: () {
                              setState(() {
                                _searchQuery = _searchController.text;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                "Available Doctors",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 10),
              // Dynamic list of doctors
              filteredDoctors.isNotEmpty
                  ? ListView.builder(
                      itemCount: filteredDoctors.length,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemBuilder: (context, index) {
                        final doc = filteredDoctors[index];
                        return DoctorCard(
                          image: doc['image'],
                          name: doc['name'],
                          specialty: doc['specialty'],
                          location: doc['location'],
                        );
                      },
                    )
                  : const Text(
                      "No doctors found.",
                      style: TextStyle(color: Colors.grey),
                    ),
            ],
          ),
        ),
      ),
      // Floating button
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 25),
        child: SizedBox(
          width: 160,
          height: 50,
          child: FloatingActionButton.extended(
            onPressed: () {
              // Add your Map View action here
            },
            backgroundColor: Colors.redAccent,
            icon: const Icon(Icons.map, color: Colors.white),
            label: const Text(
              "Map View",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class DoctorCard extends StatelessWidget {
  final String image;
  final String name;
  final String specialty;
  final String location;

  const DoctorCard({
    super.key,
    required this.image,
    required this.name,
    required this.specialty,
    required this.location,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const DoctorViewPage()),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Photo
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    image: DecorationImage(
                      image: AssetImage(image),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 4),
                      Text(specialty, style: const TextStyle(fontSize: 14)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.location_on,
                              size: 17, color: Colors.blue),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              location,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.blue),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Outlined button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const DoctorViewPage()),
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.pink),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(30), // oval edges
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  "Check Details",
                  style: TextStyle(
                      color: Colors.pink, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
