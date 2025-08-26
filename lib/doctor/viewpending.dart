import 'package:flutter/material.dart';

class Viewpending extends StatelessWidget {
  final Map<String, dynamic> appointment;

  const Viewpending({super.key, required this.appointment});

  @override
  Widget build(BuildContext context) {
    final date = appointment["date"] as DateTime?;

    return Stack(
      children: [
        Container(
          color: Colors.white,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Pending Appointment",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.grey),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const Divider(),

                      // Patient Details
                      const SectionTitle(title: "Patient Details"),
                      const InfoField(icon: Icons.person, text: "Inno Marco Villarazo"),
                      const InfoField(icon: Icons.email, text: "@gmail.com"),
                      const InfoField(icon: Icons.phone, text: "09923242526"),
                      const InfoField(icon: Icons.male, text: "Male"),
                      const InfoField(icon: Icons.calendar_today, text: "23"),

                      const SizedBox(height: 20),

                      // Schedule with edit
                      const SectionTitle(title: "Schedule"),
                      Row(
                        children: [
                          Expanded(
                            child: InfoField(
                              icon: Icons.calendar_today,
                              text: date != null ? "${date.toLocal().toString().split(" ")[0]} at ${appointment["time"] ?? "-"}" : "-",
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () {
                              // TODO: Open date/time picker
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Doctor Info
                      const SectionTitle(title: "Doctor"),
                      InfoField(icon: Icons.person, text: appointment["doctorName"] ?? "-"),
                      InfoField(icon: Icons.local_hospital, text: appointment["facility"] ?? "-"),
                      InfoField(icon: Icons.badge, text: "Experience: ${appointment["experience"] ?? "-"}"),

                      const SizedBox(height: 20),

                      // Meeting Link with Generate Button
                      const SectionTitle(title: "Meeting Link"),
                      Row(
                        children: [
                          Expanded(
                            child: InfoField(icon: Icons.link, text: appointment["meetingLink"] ?? ""),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              // TODO: Generate video consultation link
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              elevation: 4,
                            ),
                            child: const Text(
                              "Generate Link",
                              style: TextStyle(color: Colors.white), // ✅ White text
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // Floating message button
        Positioned(
          bottom: 100,
          right: 20,
          child: PhysicalModel(
            color: Colors.transparent,
            shadowColor: Colors.black26,
            elevation: 6,
            shape: BoxShape.circle,
            child: FloatingActionButton(
              backgroundColor: const Color(0xFFFF7648),
              child: const Icon(Icons.message, color: Colors.white),
              onPressed: () {
                // TODO: Open chat/message screen
              },
            ),
          ),
        ),

        // Accept/Reject buttons
        Positioned(
          bottom: 20,
          left: 16,
          right: 16,
          child: Row(
            children: [
              Expanded(
                child: PhysicalModel(
                  color: Colors.transparent,
                  shadowColor: Colors.black26,
                  elevation: 6,
                  borderRadius: BorderRadius.circular(8),
                  child: ElevatedButton(
                    onPressed: () {
                      // TODO: Accept appointment
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      "Accept",
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PhysicalModel(
                  color: Colors.transparent,
                  shadowColor: Colors.black26,
                  elevation: 6,
                  borderRadius: BorderRadius.circular(8),
                  child: ElevatedButton(
                    onPressed: () {
                      // TODO: Reject appointment
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Colors.redAccent, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      "Reject",
                      style: TextStyle(fontSize: 16, color: Colors.redAccent),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Section Title
class SectionTitle extends StatelessWidget {
  final String title;
  const SectionTitle({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }
}

// Info Field
class InfoField extends StatelessWidget {
  final IconData icon;
  final String text;
  const InfoField({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12, width: 0.8),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}
