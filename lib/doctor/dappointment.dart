import 'package:flutter/material.dart';
import 'package:tb_frontend/doctor/dpost.dart';
import 'package:tb_frontend/doctor/dhistory.dart';
import 'package:tb_frontend/doctor/viewpending.dart'; // ✅ Import Viewpending

class Dappointment extends StatefulWidget {
  const Dappointment({super.key});

  @override
  State<Dappointment> createState() => _DappointmentState();
}

class _DappointmentState extends State<Dappointment> {
  final List<Map<String, dynamic>> _appointments = [
    {
      "date": DateTime.now().add(const Duration(days: 1)),
      "status": "Pending",
      "doctorName": "Dr. Juan Dela Cruz",
      "facility": "Buhangin TB DOTS",
      "experience": "7 years",
      "time": "2:00 PM",
    },
    {
      "date": DateTime.now().subtract(const Duration(days: 3)),
      "status": "Completed",
      "doctorName": "Dr. Maria Santos",
      "facility": "Agdao TB DOTS",
      "experience": "10 years",
      "time": "10:00 AM",
    },
  ];

  @override
  Widget build(BuildContext context) {
    final pendingAppointments =
        _appointments.where((a) => a["status"] == "Pending").toList();

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

              pendingAppointments.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          "No pending appointments.",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  : Column(
                      children: pendingAppointments.map((appointment) {
                        final date = appointment["date"] as DateTime;
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
                              child: const Icon(
                                Icons.schedule,
                                color: Colors.white,
                              ),
                            ),
                            title: Text(
                              appointment["doctorName"],
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              "${appointment["facility"]}\n${date.toLocal().toString().split(" ")[0]} at ${appointment["time"]}",
                            ),
                            trailing: const Icon(Icons.more_vert),
                            onTap: () {
                              // ✅ Show floating/bubble bottom sheet
                              showModalBottomSheet(
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
                                  child: Viewpending(
                                      appointment: appointment), // pass appointment
                                ),
                              );
                            },
                          ),
                        );
                      }).toList(),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
