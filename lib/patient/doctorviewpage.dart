import 'package:flutter/material.dart';
import 'package:tb_frontend/models/doctor.dart';
import 'package:tb_frontend/patient/pbooking1.dart';

class DoctorViewPage extends StatelessWidget {
  final Doctor doctor;

  const DoctorViewPage({
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
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F5),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => Pbooking1(doctor: doctor),
            ),
          );
        },
        backgroundColor: Colors.black,
        icon: const Icon(Icons.calendar_today, color: Colors.white),
        label: const Text(
          'Book Appointment',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Back Button (fixed to go to Pdoclist)
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
                    icon:
                        const Icon(Icons.arrow_back, color: Color(0xE0F44336)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const Text(
                  "Doctor Details",
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

          const SizedBox(height: 10),

          // Doctor Card-style Design
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade200,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doctor.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          doctor.specialization,
                          style: const TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        if (doctor.facility.isNotEmpty)
                          Row(
                            children: [
                              Icon(Icons.location_on,
                                  size: 14, color: Colors.grey),
                              SizedBox(width: 2),
                              Expanded(
                                child: Text(
                                  'Talomo South Health Center',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.star, size: 14, color: Colors.white),
                            SizedBox(width: 2),
                            Text('4.2', style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Icon(Icons.favorite, color: Colors.pink),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Patients and Experience Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.pinkAccent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Column(
                          children: [
                            Text('Patient',
                                style: TextStyle(color: Colors.white)),
                            SizedBox(height: 8),
                            Text('500+',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Color(0xFFFFA726),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Column(
                          children: [
                            Text('Experience',
                                style: TextStyle(color: Colors.white)),
                            SizedBox(height: 8),
                            Text('08 Year +',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // About Section
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('About Doctor',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Dr. Miguel Rosales is a board-certified pulmonologist specializing in the diagnosis and treatment of respiratory conditions such as asthma, pneumonia, and tuberculosis. With extensive experience in pulmonary medicine, he is dedicated to providing comprehensive care to patients with lung-related health concerns.',
                  style: TextStyle(fontSize: 14, height: 1.4),
                ),
                const SizedBox(height: 20),

                // Location Section
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Location',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Talomo South Health Center (TB DOTS Clinic)\nLibby Road, Puan, Talomo District, Davao City',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    'assets/images/map1.png',
                    height: 180,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),

          const SizedBox(height: 80), // Extra space for FAB
        ],
      ),
    );
  }
}
