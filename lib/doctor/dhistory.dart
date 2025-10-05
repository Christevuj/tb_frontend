import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tb_frontend/doctor/dappointment.dart';
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

      // Get appointments from appointment_history collection (primary source)
      for (var doc in snapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        allAppointments.add(data);
      }

      // If no documents found in appointment_history, try fallback collections for backward compatibility
      if (allAppointments.isEmpty) {
        try {
          // Get approved appointments
          final approvedSnapshot = await FirebaseFirestore.instance
              .collection('approved_appointments')
              .where('doctorId', isEqualTo: _currentDoctorId)
              .get();

          for (var doc in approvedSnapshot.docs) {
            final data = doc.data();
            data['id'] = doc.id;
            allAppointments.add(data);
          }

          // Get rejected appointments
          final rejectedSnapshot = await FirebaseFirestore.instance
              .collection('rejected_appointments')
              .where('doctorId', isEqualTo: _currentDoctorId)
              .get();

          for (var doc in rejectedSnapshot.docs) {
            final data = doc.data();
            data['id'] = doc.id;
            allAppointments.add(data);
          }
        } catch (e) {
          debugPrint('Error loading from fallback collections: $e');
        }
      }

      // Sort by timestamp (either approvedAt or rejectedAt)
      allAppointments.sort((a, b) {
        final timestampA = a['approvedAt'] ?? a['rejectedAt'];
        final timestampB = b['approvedAt'] ?? b['rejectedAt'];
        if (timestampA == null && timestampB == null) return 0;
        if (timestampA == null) return 1;
        if (timestampB == null) return -1;
        return timestampB.compareTo(timestampA);
      });

      return allAppointments;
    });
  }

  // ✅ Show appointment details in full screen
  void _showAppointmentDetails(Map<String, dynamic> appointment) {
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
        child: Viewhistory(appointment: appointment),
      ),
    );
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
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const Dappointment()),
                            );
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
                                  fontSize: 16,
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
                        // Use the timestamp when the data was sent to history (approvedAt or rejectedAt)
                        DateTime? historyDate;
                        String? historyTime;
                        var approvedAt = appointment['approvedAt'];
                        var rejectedAt = appointment['rejectedAt'];
                        var timestamp = approvedAt ?? rejectedAt;
                        
                        if (timestamp is Timestamp) {
                          historyDate = timestamp.toDate();
                          // Format time in AM/PM format
                          int hour = historyDate.hour;
                          int minute = historyDate.minute;
                          String period = hour >= 12 ? 'PM' : 'AM';
                          if (hour > 12) hour -= 12;
                          if (hour == 0) hour = 12;
                          historyTime = "${hour.toString()}:${minute.toString().padLeft(2, '0')} $period";
                        } else if (timestamp is String) {
                          try {
                            historyDate = DateTime.parse(timestamp);
                            // Format time in AM/PM format
                            int hour = historyDate.hour;
                            int minute = historyDate.minute;
                            String period = hour >= 12 ? 'PM' : 'AM';
                            if (hour > 12) hour -= 12;
                            if (hour == 0) hour = 12;
                            historyTime = "${hour.toString()}:${minute.toString().padLeft(2, '0')} $period";
                          } catch (e) {
                            historyDate = null;
                            historyTime = null;
                          }
                        }

                        String status = appointment['status'] ?? 'unknown';
                        // If status is 'approved', show as 'completed' in UI
                        if (status.toLowerCase() == 'approved') {
                          status = 'completed';
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
                              backgroundColor: status.toLowerCase() == 'completed' 
                                  ? Colors.green 
                                  : status.toLowerCase() == 'rejected' 
                                      ? Colors.redAccent 
                                      : Colors.orange,
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
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  historyDate != null 
                                      ? "${historyDate.day}/${historyDate.month}/${historyDate.year} at ${historyTime ?? "No time"}"
                                      : "Date not set",
                                ),
                                Text(
                                  status.toLowerCase() == 'completed' ? "Completed" : status.toLowerCase() == 'rejected' ? "Rejected" : status,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: status.toLowerCase() == 'completed' 
                                        ? Colors.green 
                                        : status.toLowerCase() == 'rejected' 
                                            ? Colors.redAccent 
                                            : Colors.orange,
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
