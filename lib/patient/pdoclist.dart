import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tb_frontend/models/doctor.dart';
import 'package:tb_frontend/patient/pviewdoctor.dart';
import 'package:tb_frontend/patient/pbooking1.dart';

class Pdoclist extends StatefulWidget {
  const Pdoclist({super.key});

  @override
  State<Pdoclist> createState() => _PdoclistState();
}

class _PdoclistState extends State<Pdoclist> {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _searchQuery = "";

  Stream<List<Doctor>> _getDoctors() {
    return _firestore.collection('doctors').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Doctor.fromFirestore(doc)).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F5),
      body: SafeArea(
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
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) =>
                            setState(() => _searchQuery = value),
                        decoration: const InputDecoration(
                          hintText: 'Search Doctor',
                          border: InputBorder.none,
                          suffixIcon: Icon(Icons.search),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Title
              const Text(
                'Available Doctors',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // List of doctor cards
              StreamBuilder<List<Doctor>>(
                stream: _getDoctors(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Error: ${snapshot.error}'),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final doctors = snapshot.data ?? [];

                    final filteredDoctors = doctors.where((doc) {
                      final name = doc.name.toLowerCase();
                      return name.contains(_searchQuery.toLowerCase());
                    }).toList()
                      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

                  if (filteredDoctors.isEmpty) {
                    return const Center(
                      child: Text('No doctors found'),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredDoctors.length,
                    itemBuilder: (context, index) {
                      final doctor = filteredDoctors[index];
                      return DoctorCard(doctor: doctor);
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DoctorCard extends StatelessWidget {
  final Doctor doctor;

  const DoctorCard({
    super.key,
    required this.doctor,
  });

  Widget _doctorPlaceholder(String name) {
    final initials = name.isNotEmpty
        ? name.trim().split(' ').map((e) => e[0]).take(2).join().toUpperCase()
        : '?';

    return Container(
      color: Colors.redAccent.withOpacity(0.1),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.redAccent,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => PViewDoctor(doctor: doctor)),
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
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: doctor.imageUrl.isNotEmpty &&
                            !doctor.imageUrl.startsWith('assets/')
                        ? Image.network(
                            doctor.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _doctorPlaceholder(doctor.name);
                            },
                          )
                        : _doctorPlaceholder(doctor.name),
                  ),
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(doctor.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 4),
          Text(
            doctor.experience.isNotEmpty ? '${doctor.experience} years experience' : 'Experience N/A',
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 6),
          const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.location_on,
                              size: 17, color: Colors.blue),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  doctor.facility, // Facility name
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.blue,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (doctor.facilityAddress.isNotEmpty)
                                  Text(
                                    doctor.facilityAddress, // Facility address
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      // Rating removed
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
                      builder: (context) => Pbooking1(doctor: doctor),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.pink),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  "Book Appointment",
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
