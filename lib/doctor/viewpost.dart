import 'package:flutter/material.dart';

class Viewpostappointment extends StatelessWidget {
  final Map<String, dynamic> appointment;

  const Viewpostappointment({super.key, required this.appointment});

  @override
  Widget build(BuildContext context) {
    final date = appointment["date"] as DateTime?;

    return SingleChildScrollView(
      child: Material(
        color: Colors.white, // ✅ Solid white background
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min, // wrap content
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with close button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Post Appointment",
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

              // Schedule (dynamic)
              const SectionTitle(title: "Schedule"),
              InfoField(
                  icon: Icons.calendar_today,
                  text: date != null
                      ? "${date.toLocal().toString().split(" ")[0]}"
                      : "-"),
              InfoField(
                  icon: Icons.access_time,
                  text: appointment["time"] ?? "-"),

              const SizedBox(height: 20),

              // Doctor Info
              const SectionTitle(title: "Doctor"),
              InfoField(icon: Icons.person, text: appointment["doctorName"] ?? "-"),
              InfoField(icon: Icons.local_hospital, text: appointment["facility"] ?? "-"),
              InfoField(icon: Icons.badge, text: "Experience: ${appointment["experience"] ?? "-"}"),

              const SizedBox(height: 20),

              // Meeting Link
              const SectionTitle(title: "Meeting Link"),
              const InfoField(icon: Icons.link, text: "doc-consult.com"),

              const SizedBox(height: 20),

              // E-Prescription
              const SectionTitle(title: "E-Prescription"),
              const InfoField(icon: Icons.picture_as_pdf, text: "e-prescription.pdf"),

              const SizedBox(height: 20),

              // Treatment Completion
              const SectionTitle(title: "Treatment Completion"),
              const InfoField(icon: Icons.check_box, text: "-"),

              const SizedBox(height: 20),

              // Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    "Create Certificate",
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

// 🔹 Section Title Widget
class SectionTitle extends StatelessWidget {
  final String title;
  const SectionTitle({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// 🔹 Info Field Widget with thin black border and shadow
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
        color: Colors.white, // ✅ Solid white background
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
