import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tb_frontend/doctor/dappointment.dart';
import 'package:tb_frontend/doctor/viewpost.dart';

class Dpostappointment extends StatefulWidget {
  const Dpostappointment({super.key});

  @override
  State<Dpostappointment> createState() => _DpostappointmentState();
}

class _DpostappointmentState extends State<Dpostappointment> {
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ));
  }

  Future<void> _getCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _currentUserId = user.uid;
      });
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
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 20, 0, 8),
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
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const Dappointment()),
                          );
                        },
                      ),
                    ),

                    // Title
                    const Text(
                      "Post Appointments",
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

              const SizedBox(height: 20),

              // 🔹 List of Completed Appointments with Prescriptions
              StreamBuilder<QuerySnapshot>(
                stream: _currentUserId != null
                    ? FirebaseFirestore.instance
                        .collection('completed_appointments')
                        .where('doctorId', isEqualTo: _currentUserId)
                        .snapshots()
                    : const Stream.empty(),
                builder: (context, snapshot) {
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

                  final completedAppointments = snapshot.data?.docs ?? [];

                  // Sort appointments by completedAt timestamp (client-side to avoid index requirements)
                  completedAppointments.sort((a, b) {
                    final aData = a.data() as Map<String, dynamic>;
                    final bData = b.data() as Map<String, dynamic>;

                    final aCompleted = aData['completedAt'] as Timestamp?;
                    final bCompleted = bData['completedAt'] as Timestamp?;

                    if (aCompleted == null && bCompleted == null) return 0;
                    if (aCompleted == null) return 1;
                    if (bCompleted == null) return -1;

                    // Sort descending (newest first)
                    return bCompleted.compareTo(aCompleted);
                  });

                  if (completedAppointments.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 60),
                      child: Center(
                        child: Text(
                          "No completed appointments with prescriptions.",
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: completedAppointments.length,
                    itemBuilder: (context, index) {
                      final doc = completedAppointments[index];
                      final appointment = doc.data() as Map<String, dynamic>;

                      DateTime? date;
                      try {
                        final dynamic appointmentDate =
                            appointment["appointmentDate"];
                        if (appointmentDate is Timestamp) {
                          date = appointmentDate.toDate();
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
                            backgroundColor: Colors.green,
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
                              Text(
                                date != null
                                    ? "${date.toLocal().toString().split(" ")[0]} at ${appointment["appointmentTime"] ?? "No time"}"
                                    : "Date not set",
                              ),
                              const Text(
                                "Completed with Prescription",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios,
                              size: 16, color: Colors.grey),
                          onTap: () => _showCompletedAppointmentDetails({
                            ...appointment,
                            'id': doc.id,
                            'date': date,
                          }),
                        ),
                      );
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

  // ✅ Show completed appointment details with prescription and certificate option
  void _showCompletedAppointmentDetails(
      Map<String, dynamic> appointment) async {
    // Use the original appointmentId from the completed appointment data
    final originalAppointmentId =
        appointment['appointmentId'] ?? appointment['id'];

    // Fetch prescription data for this appointment using the original appointmentId
    final prescriptionSnapshot = await FirebaseFirestore.instance
        .collection('prescriptions')
        .where('appointmentId', isEqualTo: originalAppointmentId)
        .get();

    Map<String, dynamic>? prescriptionData;
    if (prescriptionSnapshot.docs.isNotEmpty) {
      prescriptionData = prescriptionSnapshot.docs.first.data();
    }

    // Fetch doctor information from doctors collection
    Map<String, dynamic>? doctorData;
    if (appointment['doctorId'] != null) {
      try {
        final doctorDoc = await FirebaseFirestore.instance
            .collection('doctors')
            .doc(appointment['doctorId'])
            .get();

        if (doctorDoc.exists) {
          doctorData = doctorDoc.data();
        }
      } catch (e) {
        debugPrint('Error fetching doctor data: $e');
      }
    }

    if (context.mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Viewpostappointment(
            appointment: {
              ...appointment,
              'prescriptionData': prescriptionData,
              'doctorData': doctorData,
              'showCertificateButton': true,
              // Use the completed appointment's document ID for certificate operations
              'id': appointment['appointmentId'] ?? appointment['id'],
            },
          ),
        ),
      );
    }
  }
}
