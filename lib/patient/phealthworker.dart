import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tb_frontend/services/chat_service.dart';
import 'package:tb_frontend/chat_screens/health_chat_screen.dart';

class Phealthworker extends StatelessWidget {
  final String facilityId;
  final String facilityName;
  final String facilityAddress;

  const Phealthworker({
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

                    // Combine health workers and doctors
                    List<Map<String, dynamic>> allStaff = [];

                    // Add health workers
                    for (var doc in healthcareSnapshot.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      allStaff.add({
                        ...data,
                        'id': doc.id,
                        'type': 'Health Worker',
                      });
                    }

                    // Add doctors who have this facility in their affiliations
                    for (var doc in doctorsSnapshot.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final affiliations = data['affiliations'] as List? ?? [];

                      // Check if this doctor is affiliated with this facility by address
                      for (var affiliation in affiliations) {
                        if (affiliation is Map &&
                            affiliation['address'] == facilityAddress) {
                          allStaff.add({
                            'name': data['fullName'] ??
                                data['name'], // Handle both field names
                            'fullName': data['fullName'],
                            'email': data['email'],
                            'role': data['role'],
                            'specialization': data['specialization'],
                            'profilePicture': data['profilePicture'],
                            'phone': affiliation['phone'] ?? data['phone'],
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
                        return _buildHealthWorkerCard(worker);
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

  Widget _buildHealthWorkerCard(Map<String, dynamic> worker) {
    final name = worker['name'] ?? worker['fullName'] ?? 'Unknown Name';
    final email = worker['email'] ?? 'No email provided';
    final phone = worker['phone'] ?? 'No phone provided';
    final position = worker['position'] ?? worker['type'] ?? 'Health Worker';
    final profilePicture = worker['profilePicture'] as String?;
    final type = worker['type'] ?? 'Health Worker';
    final workerId = worker['id'] ?? '';
    final isDoctor = type == 'Doctor';

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
                // Modern Profile Icon/Image
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDoctor
                          ? [
                              Colors.blue,
                              Colors.blue.withOpacity(0.8),
                            ]
                          : [
                              const Color(0xE0F44336),
                              const Color(0xE0F44336).withOpacity(0.8),
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color:
                            (isDoctor ? Colors.blue : const Color(0xE0F44336))
                                .withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: profilePicture != null && profilePicture.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            profilePicture,
                            fit: BoxFit.cover,
                            cacheWidth: 120,
                            cacheHeight: 120,
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            },
                          ),
                        )
                      : Center(
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                // Name and Status
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
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
                          color: isDoctor
                              ? Colors.blue.withOpacity(0.1)
                              : const Color(0xFF10B981).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: isDoctor
                                    ? Colors.blue
                                    : const Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              position,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isDoctor
                                    ? Colors.blue
                                    : const Color(0xFF10B981),
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
            const SizedBox(height: 12),
            // Contact Information with modern styling
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
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.email_rounded,
                        color: Color(0xFF6B7280),
                        size: 14,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          email,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF374151),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.phone_rounded,
                        color: Color(0xFF6B7280),
                        size: 14,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          phone,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF374151),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Show specialization for doctors
                  if (isDoctor && worker['specialization'] != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.medical_services_rounded,
                          color: Color(0xFF6B7280),
                          size: 14,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            worker['specialization'],
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF374151),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Message Button - Modern Style matching facility cards
            Builder(
              builder: (context) => ElevatedButton.icon(
                onPressed: () => _handleMessageTap(
                  context: context,
                  workerId: workerId,
                  workerName: name,
                  workerType: type,
                  profilePicture: profilePicture,
                ),
                icon: const Icon(Icons.message_rounded, size: 16),
                label: Text('Message ${isDoctor ? 'Doctor' : 'Health Worker'}'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xE0F44336),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 44),
                  elevation: 4,
                  shadowColor: const Color(0xE0F44336).withOpacity(0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleMessageTap({
    required BuildContext context,
    required String workerId,
    required String workerName,
    required String workerType,
    String? profilePicture,
  }) async {
    try {
      // Show loading indicator
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 12),
                Text('Opening chat...'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Wait a moment for auth state to stabilize
      await Future.delayed(const Duration(milliseconds: 300));

      // Try to reload the user in case the auth state is stale
      await FirebaseAuth.instance.currentUser?.reload();
      final currentUser = FirebaseAuth.instance.currentUser;

      debugPrint(
          '🔍 Checking auth state: User = ${currentUser?.uid ?? "null"}, Email = ${currentUser?.email ?? "null"}');

      if (currentUser == null) {
        debugPrint('❌ No authenticated user found');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Authentication error. Please log in again.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      final authUid = currentUser.uid;
      debugPrint(
          '💬 Opening chat with $workerType: $workerName (ID: $workerId)');

      // Initialize ChatService
      final chatService = ChatService();

      // Ensure both users exist in Firestore users collection
      final patientName = await _resolvePatientName(authUid);
      await chatService.createUserDoc(
        userId: authUid,
        name: patientName,
        role: 'patient',
      );

      final contactRole = workerType == 'Doctor' ? 'doctor' : 'healthcare';
      await chatService.createUserDoc(
        userId: workerId,
        name: workerName,
        role: contactRole,
      );

      debugPrint('✅ Opening chat with $workerType: $workerName');

      // Navigate to chat screen
      if (context.mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PatientHealthWorkerChatScreen(
              currentUserId: authUid,
              healthWorkerId: workerId,
              healthWorkerName: workerName,
              healthWorkerProfilePicture: profilePicture,
              role: contactRole,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error in _handleMessageTap: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening chat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String> _resolvePatientName(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (userDoc.exists) {
        return userDoc.data()?['name'] ?? 'Patient';
      }
      return 'Patient';
    } catch (e) {
      debugPrint('❌ Error resolving patient name: $e');
      return 'Patient';
    }
  }
}
