import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tb_frontend/doctor/dpost.dart';
import 'package:tb_frontend/doctor/dhistory.dart';
import 'package:tb_frontend/doctor/viewpending.dart';
import 'package:tb_frontend/doctor/daccount.dart';

class Dappointment extends StatefulWidget {
  const Dappointment({super.key});

  @override
  State<Dappointment> createState() => _DappointmentState();
}

class _DappointmentState extends State<Dappointment> {
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    // Get the current user's ID (doctor's ID)
    _getCurrentUser();
  }

  Future<void> _getCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        // Get the doctor document using the auth UID
        final doctorDoc = await FirebaseFirestore.instance
            .collection('doctors')
            .doc(user.uid)
            .get();

        if (doctorDoc.exists) {
          setState(() {
            // Use the UID as the currentUserId - this matches what's stored in pending_patient_data
            _currentUserId = user.uid;
          });
          debugPrint('Found doctor with UID: $_currentUserId');

          // Debug: Print current pending appointments
          final pendingSnapshot = await FirebaseFirestore.instance
              .collection('pending_patient_data')
              .where('doctorId', isEqualTo: _currentUserId)
              .get();

          debugPrint(
              'Found ${pendingSnapshot.docs.length} pending appointments');
          for (var doc in pendingSnapshot.docs) {
            debugPrint('Appointment: ${doc.data()}');
          }
        } else {
          debugPrint('Doctor document not found');
        }
      } catch (e) {
        debugPrint('Error getting doctor data: $e');
      }
    } else {
      debugPrint('No user logged in');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 🔹 Header
              const Padding(
                padding: EdgeInsets.fromLTRB(0, 20, 0, 8),
                child: Center(
                  child: Text(
                    "My Appointments",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xE0F44336),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Post Appointment + History buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text(
                        "Post Appointment",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const Dpostappointment(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[800],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.history),
                      label: const Text(
                        "History",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const Dhistory(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Pending Appointments Section
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Pending Appointments",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              FutureBuilder<List<QueryDocumentSnapshot>>(
                future: FirebaseFirestore.instance
                    .collection('pending_patient_data')
                    .get()
                    .then((snapshot) => snapshot.docs
                        .where((doc) => doc['doctorId'] == _currentUserId)
                        .toList()),
                builder: (context, snapshot) {
                  // Detailed debug information
                  debugPrint('====== Pending Appointments Debug ======');
                  debugPrint('StreamBuilder rebuilding');
                  debugPrint('Current doctor UID (doctorId): $_currentUserId');
                  debugPrint('Has error: ${snapshot.hasError}');
                  if (snapshot.hasError) {
                    debugPrint('Error details: ${snapshot.error}');
                    debugPrint('Stack trace: ${snapshot.stackTrace}');
                  }
                  debugPrint('Connection state: ${snapshot.connectionState}');
                  if (snapshot.hasData) {
                    debugPrint('Number of documents: ${snapshot.data?.length}');
                    if ((snapshot.data?.isNotEmpty ?? false)) {
                      final firstDoc =
                          snapshot.data?.first.data() as Map<String, dynamic>;
                      debugPrint('First document data: $firstDoc');
                    }
                  }
                  debugPrint('======================================');
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final appointments = snapshot.data ?? [];
                  debugPrint(
                      'Number of appointments found: ${appointments.length}');

                  if (appointments.isNotEmpty) {
                    // Print the first appointment data for debugging
                    final firstAppointment =
                        appointments.first.data() as Map<String, dynamic>;
                    debugPrint('Sample appointment data: $firstAppointment');
                  }

                  if (appointments.isEmpty) {
                    debugPrint('No appointments found in the collection');
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          "No pending appointments.",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: appointments.map((doc) {
                      final appointment = doc.data() as Map<String, dynamic>;
                      debugPrint(
                          'Processing appointment: ${appointment['patientName']}');

                      DateTime? date;
                      try {
                        final dynamic appointmentDate =
                            appointment["appointmentDate"];
                        if (appointmentDate is Timestamp) {
                          date = appointmentDate.toDate();
                        } else {
                          debugPrint(
                              'appointmentDate is not a Timestamp: $appointmentDate');
                        }
                      } catch (e) {
                        debugPrint('Error converting appointmentDate: $e');
                      }

                      return Card(
                        color: Colors.white,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.orange,
                            child: Text(
                              appointment["patientName"]
                                      ?.substring(0, 1)
                                      .toUpperCase() ??
                                  "P",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            appointment["patientName"] ?? "Unknown Patient",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    date != null
                                        ? "${date.toLocal().toString().split(" ")[0]} at ${appointment["appointmentTime"] ?? "No time"}"
                                        : "Date not set",
                                  ),
                                  Text(
                                    "Pending",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right,
                              color: Colors.grey),
                          onTap: () async {
                            final result = await showModalBottomSheet<String>(
                              context: context,
                              isScrollControlled: true,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(20)),
                              ),
                              builder: (context) => Padding(
                                padding: EdgeInsets.only(
                                  bottom:
                                      MediaQuery.of(context).viewInsets.bottom,
                                ),
                                child: Viewpending(appointment: {
                                  ...appointment,
                                  'id': doc.id,
                                  'date': date,
                                }),
                              ),
                            );

                            // Handle the result from ViewPending
                            if (result == 'approved') {
                              if (context.mounted) {
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const Daccount(),
                                  ),
                                  (route) => false,
                                );
                              }
                            } else if (result == 'rejected') {
                              // Appointment was rejected and moved to history
                              // The StreamBuilder will automatically refresh and hide this appointment
                              if (context.mounted) {
                                setState(() {
                                  // Trigger a rebuild to refresh the appointments list
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Appointment has been rejected and moved to history'),
                                    backgroundColor: Colors.orange.shade600,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      );
                    }).toList(),
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
