import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tb_frontend/doctor/viewhistory.dart'; // Import Viewhistory

class Dhistory extends StatefulWidget {
  const Dhistory({super.key});

  @override
  State<Dhistory> createState() => _DhistoryState();
}

class _DhistoryState extends State<Dhistory> {
  String? _currentDoctorId;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ));
    _getCurrentDoctorId();
  }

  Future<void> _getCurrentDoctorId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _currentDoctorId = user.uid;
      });
    }
  }

  // Load appointments from history collection
  Stream<List<Map<String, dynamic>>> _getHistoryStream() {
    if (_currentDoctorId == null) {
      return Stream.value([]);
    }

    return FirebaseFirestore.instance
        .collection('appointment_history')
        .where('doctorId', isEqualTo: _currentDoctorId)
        .snapshots()
        .asyncMap((snapshot) async {
      List<Map<String, dynamic>> allAppointments = [];

      // Get appointments from appointment_history collection (fully completed treatments)
      for (var doc in snapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        data['source'] = 'appointment_history';
        allAppointments.add(data);
      }

      // Also get appointments from completed_appointments collection (post-consultation appointments)
      final completedAppointmentsSnapshot = await FirebaseFirestore.instance
          .collection('completed_appointments')
          .where('doctorId', isEqualTo: _currentDoctorId)
          .get();

      for (var doc in completedAppointmentsSnapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        data['source'] = 'completed_appointments';
        allAppointments.add(data);
      }

      // History shows all post-consultation appointments: both completed meetings and fully completed treatments

      // Sort by most relevant timestamp (prioritize treatment completed appointments)
      allAppointments.sort((a, b) {
        // Get the most relevant timestamp for each appointment
        final timestampA = a['treatmentCompletedAt'] ??
            a['movedToHistoryAt'] ??
            a['completedAt'] ??
            a['approvedAt'] ??
            a['rejectedAt'];
        final timestampB = b['treatmentCompletedAt'] ??
            b['movedToHistoryAt'] ??
            b['completedAt'] ??
            b['approvedAt'] ??
            b['rejectedAt'];

        if (timestampA == null && timestampB == null) return 0;
        if (timestampA == null) return 1;
        if (timestampB == null) return -1;

        // Sort descending (newest first)
        return timestampB.compareTo(timestampA);
      });

      return allAppointments;
    });
  }

  // ✅ Show appointment details in full screen
  void _showAppointmentDetails(Map<String, dynamic> appointment) async {
    // Fetch additional data similar to dpost.dart
    final originalAppointmentId =
        appointment['appointmentId'] ?? appointment['id'];

    // Fetch prescription data for this appointment
    Map<String, dynamic>? prescriptionData;
    if (appointment['prescriptionData'] != null) {
      // Use existing prescription data if already available
      prescriptionData = appointment['prescriptionData'];
    } else {
      // Fetch prescription data from collection
      try {
        final prescriptionSnapshot = await FirebaseFirestore.instance
            .collection('prescriptions')
            .where('appointmentId', isEqualTo: originalAppointmentId)
            .get();

        if (prescriptionSnapshot.docs.isNotEmpty) {
          prescriptionData = prescriptionSnapshot.docs.first.data();
        }
      } catch (e) {
        debugPrint('Error fetching prescription data: $e');
      }
    }

    // Fetch certificate data for this appointment
    Map<String, dynamic>? certificateData;
    if (appointment['certificateData'] != null) {
      // Use existing certificate data if already available
      certificateData = appointment['certificateData'];
    } else {
      // Fetch certificate data from collection
      try {
        final certificateSnapshot = await FirebaseFirestore.instance
            .collection('certificates')
            .where('appointmentId', isEqualTo: originalAppointmentId)
            .get();

        if (certificateSnapshot.docs.isNotEmpty) {
          certificateData = certificateSnapshot.docs.first.data();
        }
      } catch (e) {
        debugPrint('Error fetching certificate data: $e');
      }
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
          child: Viewhistory(
            appointment: {
              ...appointment,
              'prescriptionData': prescriptionData,
              'certificateData': certificateData,
              'doctorData': doctorData,
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 20, 0, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
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
                            Navigator.pop(context);
                          },
                        ),
                      ),
                      const Text(
                        "Appointment History",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xE0F44336),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // StreamBuilder for history data
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _getHistoryStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error loading history: ${snapshot.error}',
                          style: const TextStyle(color: Colors.red),
                        ),
                      );
                    }

                    final appointments = snapshot.data ?? [];

                    if (appointments.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: Column(
                            children: [
                              Icon(
                                Icons.history,
                                size: 64,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                "No appointment history yet.",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                "Completed consultations and treatments will appear here",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: appointments.length,
                      itemBuilder: (context, index) {
                        final appointment = appointments[index];

                        // Determine the most relevant timestamp and status based on source
                        DateTime? historyDate;
                        String? historyTime;
                        String status = 'unknown';
                        String statusDisplayText = 'Unknown';
                        Color statusColor = Colors.orange;

                        var timestamp;

                        // Different logic based on source collection
                        if (appointment['source'] == 'appointment_history') {
                          // From appointment_history - treatment completed
                          var treatmentCompletedAt =
                              appointment['treatmentCompletedAt'];
                          var movedToHistoryAt =
                              appointment['movedToHistoryAt'];

                          if (treatmentCompletedAt != null) {
                            timestamp = treatmentCompletedAt;
                            status = 'treatment_completed';
                            statusDisplayText = 'Treatment Completed';
                            statusColor = Colors.purple;
                          } else if (movedToHistoryAt != null) {
                            timestamp = movedToHistoryAt;
                            status = 'treatment_completed';
                            statusDisplayText = 'Treatment Completed';
                            statusColor = Colors.purple;
                          }
                        } else {
                          // From completed_appointments - consultation completed, awaiting treatment completion
                          var completedAt = appointment['completedAt'];
                          if (completedAt != null) {
                            timestamp = completedAt;
                            status = 'consultation_completed';
                            statusDisplayText = 'Consultation Completed';
                            statusColor = Colors.blue;
                          }
                        }

                        // Fallback logic for other statuses
                        if (timestamp == null) {
                          var approvedAt = appointment['approvedAt'];
                          var rejectedAt = appointment['rejectedAt'];

                          if (approvedAt != null) {
                            timestamp = approvedAt;
                            status = 'approved';
                            statusDisplayText = 'Approved';
                            statusColor = Colors.green;
                          } else if (rejectedAt != null) {
                            timestamp = rejectedAt;
                            status = 'rejected';
                            statusDisplayText = 'Rejected';
                            statusColor = Colors.red;
                          } else {
                            // Final fallback to appointment status
                            status = appointment['status'] ?? 'unknown';
                            statusDisplayText =
                                status.replaceAll('_', ' ').toUpperCase();
                          }
                        }

                        if (timestamp is Timestamp) {
                          historyDate = timestamp.toDate();
                          // Format time in AM/PM format
                          int hour = historyDate.hour;
                          int minute = historyDate.minute;
                          String period = hour >= 12 ? 'PM' : 'AM';
                          if (hour > 12) hour -= 12;
                          if (hour == 0) hour = 12;
                          historyTime =
                              "${hour.toString()}:${minute.toString().padLeft(2, '0')} $period";
                        } else if (timestamp is String) {
                          try {
                            historyDate = DateTime.parse(timestamp);
                            // Format time in AM/PM format
                            int hour = historyDate.hour;
                            int minute = historyDate.minute;
                            String period = hour >= 12 ? 'PM' : 'AM';
                            if (hour > 12) hour -= 12;
                            if (hour == 0) hour = 12;
                            historyTime =
                                "${hour.toString()}:${minute.toString().padLeft(2, '0')} $period";
                          } catch (e) {
                            historyDate = null;
                            historyTime = null;
                          }
                        }

                        // Check if appointment has prescription or certificate data
                        final hasPrescription =
                            appointment['prescriptionData'] != null;
                        final hasCertificate =
                            appointment['certificateData'] != null;

                        return Card(
                          color: Colors.white,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: statusColor,
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
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    appointment["patientName"] ??
                                        "Unknown Patient",
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                // Show indicators for prescription and certificate
                                if (hasPrescription)
                                  Container(
                                    margin: const EdgeInsets.only(left: 4),
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Icon(
                                      Icons.medical_services,
                                      size: 16,
                                      color: Colors.blue,
                                    ),
                                  ),
                                if (hasCertificate)
                                  Container(
                                    margin: const EdgeInsets.only(left: 4),
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.purple.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Icon(
                                      Icons.card_membership,
                                      size: 16,
                                      color: Colors.purple,
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  historyDate != null
                                      ? "${historyDate.day}/${historyDate.month}/${historyDate.year} at ${historyTime ?? "No time"}"
                                      : "Date not set",
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    statusDisplayText,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: statusColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            trailing: const Icon(Icons.chevron_right,
                                color: Colors.grey),
                            onTap: () => _showAppointmentDetails({
                              ...appointment,
                              'date': historyDate,
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
      ),
    );
  }
}
