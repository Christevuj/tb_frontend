import 'package:flutter/material.dart';

class Viewhistory extends StatelessWidget {
  final Map<String, dynamic> appointment;

  const Viewhistory({super.key, required this.appointment});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Material(
        color: Colors.white, // ✅ Solid white background
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with close button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "History Details",
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
              const InfoField(icon: Icons.email, text: "inno.villarazo@gmail.com"),
              const InfoField(icon: Icons.phone, text: "0992-324-2526"),

              const SizedBox(height: 20),

              // Appointment Details
              const SectionTitle(title: "Schedule"),
              InfoField(
                  icon: Icons.date_range,
                  text: appointment["date"].toString().split(" ")[0]),
              InfoField(icon: Icons.access_time, text: appointment["time"] ?? "-"),

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
              const InfoField(icon: Icons.picture_as_pdf, text: "cert.pdf"),
            ],
          ),
        ),
      ),
    );
  }
}

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
          Icon(icon, color: Colors.black54),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
