import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tb_frontend/patient/pdoclist.dart';
import 'package:tb_frontend/patient/pviewdoctor.dart';
import 'package:tb_frontend/guest/gconsultant.dart';
import 'package:tb_frontend/guest/gtbfacility.dart';
import 'package:tb_frontend/models/doctor.dart';

class PlandingPage extends StatefulWidget {
  const PlandingPage({super.key});

  @override
  State<PlandingPage> createState() => _PlandingPageState();
}

class _PlandingPageState extends State<PlandingPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<Doctor>> _getDoctors() {
    return _firestore.collection('doctors').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Doctor.fromFirestore(doc)).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo at the top, left-aligned
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Image.asset(
                  'assets/images/tbisita_logo2.png',
                  height: 44, // smaller size
                ),
              ),
            ),

            // Search bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const TextField(
                decoration: InputDecoration(
                  icon: Icon(Icons.search),
                  hintText: 'Search a Doctor',
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Quick Actions
            const Text(
              'Quick Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _quickAction(
                  context,
                  Icons.smart_toy,
                  'AI\nConsultant',
                  const GConsultant(),
                ),
                _quickAction(
                  context,
                  Icons.calendar_today,
                  'Book\nAppointment',
                  const Pdoclist(),
                ),
                _quickAction(
                  context,
                  Icons.local_hospital,
                  'TB DOTS\nFacilities',
                  const GtbfacilityPage(),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Top Doctors
            const Text(
              'Top Doctors',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Doctor List
            SizedBox(
              height: 440,
              child: StreamBuilder<List<Doctor>>(
                stream: _getDoctors(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('No doctors found'));
                  }

                  return ListView.builder(
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) => _doctorCard(
                      context,
                      snapshot.data![index],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _quickAction(
      BuildContext context, IconData icon, String label, Widget destination) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
            context, MaterialPageRoute(builder: (context) => destination));
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.redAccent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 4,
                  offset: Offset(2, 2),
                )
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _doctorPlaceholder(String name) {
    // Get the initials from the name
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

  Widget _doctorCard(BuildContext context, Doctor doctor) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 6,
            offset: const Offset(2, 2),
          )
        ],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: doctor.imageUrl.isNotEmpty &&
                      !doctor.imageUrl.startsWith('assets/')
                  ? Image.network(
                      doctor.imageUrl,
                      height: 80,
                      width: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _doctorPlaceholder(doctor.name);
                      },
                    )
                  : _doctorPlaceholder(doctor.name),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doctor.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  doctor.specialization,
                  style: const TextStyle(color: Colors.black54, fontSize: 13),
                ),
                Text(
                  doctor.facility,
                  style: const TextStyle(color: Colors.black45, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Row(
                  children: List.generate(5, (index) {
                    return Icon(
                      index < doctor.rating.floor()
                          ? Icons.star
                          : Icons.star_border,
                      size: 16,
                      color: Colors.orange,
                    );
                  }),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => PViewDoctor(doctor: doctor)),
              );
            },
            child: const Text(
              'View Details',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
