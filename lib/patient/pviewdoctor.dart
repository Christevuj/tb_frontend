import 'package:flutter/material.dart';
import 'package:tb_frontend/models/doctor.dart';
import 'package:tb_frontend/patient/pbooking1.dart';

class PViewDoctor extends StatelessWidget {
  final Doctor doctor;

  const PViewDoctor({super.key, required this.doctor});

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
            fontSize: 20,
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
      backgroundColor: Colors.white,
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
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Top Banner + Back Button
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
                child: Row(
                  children: [
                    IconButton(
                      icon:
                          const Icon(Icons.arrow_back, color: Colors.redAccent),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Doctor Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
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
                                  width: 60,
                                  height: 60,
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
                            Text(doctor.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text(doctor.specialization,
                                style: const TextStyle(fontSize: 13)),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.location_on,
                                    size: 14, color: Colors.grey),
                                const SizedBox(width: 2),
                                Expanded(
                                  child: Text(
                                    doctor.facility,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12),
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
                            child: Row(
                              children: [
                                const Icon(Icons.star,
                                    size: 14, color: Colors.white),
                                const SizedBox(width: 2),
                                Text(doctor.rating.toStringAsFixed(1),
                                    style:
                                        const TextStyle(color: Colors.white)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Icon(Icons.favorite_border, color: Colors.pink),
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
                              color: const Color(0xFFFFA726),
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
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Dr. ${doctor.name} is a board-certified ${doctor.specialization.toLowerCase()} specializing in the diagnosis and treatment of tuberculosis and other respiratory conditions. They provide comprehensive care at ${doctor.facility}.',
                      style: const TextStyle(fontSize: 14, height: 1.4),
                    ),
                    const SizedBox(height: 20),

                    // Location Section
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Location',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      doctor.facility,
                      style: const TextStyle(fontSize: 14),
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
            ],
          ),
        ),
      ),
    );
  }
}
