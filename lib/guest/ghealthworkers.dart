import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GHealthWorkers extends StatelessWidget {
  final String facilityId;
  final String facilityName;
  final String facilityAddress;

  const GHealthWorkers({
    super.key,
    required this.facilityId,
    required this.facilityName,
    required this.facilityAddress,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F5),
      body: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Modern Back Button
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new,
                        color: Color(0xFF1F2937), size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const Expanded(
                  child: Text(
                    "Health Workers",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xE0F44336),
                    ),
                  ),
                ),
                const SizedBox(width: 48), // spacing balance
              ],
            ),
          ),

          // Facility Info Card
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(20),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  facilityName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: Color(0xFF7F8C8D),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        facilityAddress,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF7F8C8D),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Health Workers and Doctors List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('healthcare')
                  .where('facility.address', isEqualTo: facilityAddress)
                  .snapshots(),
              builder: (context, healthcareSnapshot) {
                if (healthcareSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xE0F44336)),
                    ),
                  );
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('doctors')
                      .snapshots(),
                  builder: (context, doctorsSnapshot) {
                    if (doctorsSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Color(0xE0F44336)),
                        ),
                      );
                    }

                    if (healthcareSnapshot.hasError ||
                        doctorsSnapshot.hasError) {
                      return const Center(
                        child: Text(
                          'Error loading staff',
                          style: TextStyle(color: Colors.red),
                        ),
                      );
                    }

                    if (!healthcareSnapshot.hasData ||
                        !doctorsSnapshot.hasData) {
                      return const Center(
                        child: Text(
                          'No data available',
                          style: TextStyle(color: Colors.red),
                        ),
                      );
                    }

                    List<Map<String, dynamic>> allStaff = [];

                    // Add health workers
                    for (var doc in healthcareSnapshot.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      allStaff.add({
                        ...data,
                        'id': doc.id,
                        'type': 'Health Worker',
                        'name': data['fullName'] ?? data['name'] ?? 'No info',
                        'email': data['email'] ?? 'No info',
                        'position': data['role'] ?? 'No info',
                        'profilePicture': data['profilePicture'] ?? '',
                      });
                    }

                    // Add doctors who have this facility in their affiliations
                    for (var doc in doctorsSnapshot.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final affiliations = data['affiliations'] as List? ?? [];
                      for (var affiliation in affiliations) {
                        if (affiliation is Map &&
                            affiliation['address'] == facilityAddress) {
                          allStaff.add({
                            'name':
                                data['fullName'] ?? data['name'] ?? 'No info',
                            'fullName': data['fullName'] ?? 'No info',
                            'email': data['email'] ?? 'No info',
                            'role': data['role'] ?? 'No info',
                            'specialization':
                                data['specialization'] ?? 'No info',
                            'profilePicture': data['profilePicture'] ?? '',
                            'phone': affiliation['phone'] ??
                                data['phone'] ??
                                'No info',
                            'position': data['role'] ?? 'Doctor',
                            'id': doc.id,
                            'type': 'Doctor',
                            'schedules': affiliation['schedules'] ?? [],
                          });
                        }
                      }
                    }

                    if (allStaff.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No health workers found',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'This facility has no registered health workers yet.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: allStaff.length,
                      itemBuilder: (context, index) {
                        final worker = allStaff[index];
                        return _buildHealthWorkerCard(context, worker);
                      },
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

  Widget _buildHealthWorkerCard(
      BuildContext context, Map<String, dynamic> worker) {
    final name = worker['name'] ?? worker['fullName'] ?? 'No info';
    final email = worker['email'] ?? 'No info';
    final phone = worker['phone'] ?? 'No info';
    final position = worker['position'] ?? worker['type'] ?? 'No info';
    final profilePicture = worker['profilePicture'] as String?;
    final type = worker['type'] ?? 'Health Worker';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Profile Picture
                CircleAvatar(
                  radius: 30,
                  backgroundColor: const Color(0xE0F44336),
                  backgroundImage:
                      profilePicture != null && profilePicture.isNotEmpty
                          ? NetworkImage(profilePicture)
                          : null,
                  child: profilePicture == null || profilePicture.isEmpty
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 16),

                // Worker Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: type == 'Doctor'
                              ? const Color.fromARGB(255, 243, 33, 33)
                                  .withOpacity(0.1)
                              : const Color.fromRGBO(244, 67, 54, 0.878)
                                  .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          position,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: type == 'Doctor'
                                ? Colors.blue
                                : const Color(0xE0F44336),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.email_outlined,
                            color: Color(0xFF7F8C8D),
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              email,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF7F8C8D),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.phone_outlined,
                            color: Color(0xFF7F8C8D),
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              phone,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF7F8C8D),
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Show specialization for doctors
                      if (type == 'Doctor' &&
                          worker['specialization'] != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.medical_services_outlined,
                              color: Color(0xFF7F8C8D),
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                worker['specialization'],
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF7F8C8D),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            // Messenger-style Message Button
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (worker['type'] == 'Doctor') {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Login Required'),
                              content: const Text(
                                  'You need to login to message a doctor.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('OK'),
                                ),
                              ],
                            ),
                          );
                        } else {
                          // TODO: Implement messaging for non-doctor
                        }
                      },
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.messenger_outline,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Message',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
