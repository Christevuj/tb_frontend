import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tb_frontend/doctor/dappointment.dart';
import 'package:tb_frontend/doctor/viewpost.dart'; // ✅ Correct import

class Dpostappointment extends StatefulWidget {
  const Dpostappointment({super.key});

  @override
  State<Dpostappointment> createState() => _DpostappointmentState();
}

class _DpostappointmentState extends State<Dpostappointment> {
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
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ));
  }

  // ✅ Show appointment details in a floating dialog
  void _showAppointmentDetails(Map<String, dynamic> appointment) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          insetPadding: const EdgeInsets.all(20),
          child:
              Viewpostappointment(appointment: appointment), // ✅ Correct widget
        );
      },
    );
  }

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
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 20, 0, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back Button
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
                        icon: const Icon(Icons.arrow_back,
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

              // 🔹 List of Appointments
              pendingAppointments.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.only(top: 60),
                      child: Center(
                        child: Text(
                          "No pending appointments.",
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: pendingAppointments.length,
                      itemBuilder: (context, index) {
                        final appointment = pendingAppointments[index];
                        final date = appointment["date"] as DateTime;

                        return Card(
                          color: Colors.white,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Colors.orange,
                              child: Icon(Icons.schedule, color: Colors.white),
                            ),
                            title: Text(
                              appointment["doctorName"],
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              "${appointment["facility"]}\n"
                              "${date.toLocal().toString().split(" ")[0]} at ${appointment["time"]}",
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios,
                                size: 16, color: Colors.grey),
                            onTap: () => _showAppointmentDetails(appointment),
                          ),
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
