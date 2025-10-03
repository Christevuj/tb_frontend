import 'package:flutter/material.dart';

class Viewhistory extends StatelessWidget {
  final Map<String, dynamic> appointment;

  const Viewhistory({super.key, required this.appointment});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.grey.shade50,
            Colors.white,
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 16, bottom: 12),
              height: 5,
              width: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.grey.shade300, Colors.grey.shade400],
                ),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "History Details",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey.shade800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "View appointment history",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.close,
                            color: Colors.grey.shade700,
                            size: 22,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24), // Patient Details
                  const SectionTitle(title: "Patient Details"),
                  InfoField(
                      icon: Icons.person,
                      text: appointment["patientName"] ?? "Unknown Patient"),
                  InfoField(
                      icon: Icons.email,
                      text: appointment["patientEmail"] ?? "No email provided"),
                  InfoField(
                      icon: Icons.phone,
                      text: appointment["patientPhone"] ?? "No phone provided"),

                  const SizedBox(height: 20),

                  // Appointment Details
                  const SectionTitle(title: "Schedule"),
                  InfoField(
                      icon: Icons.date_range,
                      text: appointment["date"].toString().split(" ")[0]),
                  InfoField(
                      icon: Icons.access_time,
                      text: appointment["time"] ?? "-"),

                  const SizedBox(height: 20),

                  // Status Section
                  const SectionTitle(title: "Status"),
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: appointment["status"]
                                        ?.toString()
                                        .toLowerCase() ==
                                    "approved"
                                ? Colors.green.shade50
                                : appointment["status"]
                                            ?.toString()
                                            .toLowerCase() ==
                                        "rejected"
                                    ? Colors.red.shade50
                                    : Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            appointment["status"]?.toString().toLowerCase() ==
                                    "approved"
                                ? Icons.check_circle
                                : appointment["status"]
                                            ?.toString()
                                            .toLowerCase() ==
                                        "rejected"
                                    ? Icons.cancel
                                    : Icons.pending,
                            color: appointment["status"]
                                        ?.toString()
                                        .toLowerCase() ==
                                    "approved"
                                ? Colors.green.shade600
                                : appointment["status"]
                                            ?.toString()
                                            .toLowerCase() ==
                                        "rejected"
                                    ? Colors.red.shade600
                                    : Colors.orange.shade600,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            (appointment["status"]?.toString().toLowerCase() ==
                                    "approved"
                                ? "COMPLETED"
                                : appointment["status"]
                                        ?.toString()
                                        .toUpperCase() ??
                                    "UNKNOWN"),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: appointment["status"]
                                          ?.toString()
                                          .toLowerCase() ==
                                      "approved"
                                  ? Colors.green.shade700
                                  : appointment["status"]
                                              ?.toString()
                                              .toLowerCase() ==
                                          "rejected"
                                      ? Colors.red.shade700
                                      : Colors.orange.shade700,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Show rejection reason if appointment is rejected
                  if (appointment["status"]?.toString().toLowerCase() ==
                          "rejected" &&
                      appointment["rejectionReason"] != null)
                    Column(
                      children: [
                        const SizedBox(height: 20),
                        const SectionTitle(title: "Rejection Reason"),
                        InfoField(
                          icon: Icons.info_outline,
                          text: appointment["rejectionReason"] ??
                              "No reason provided",
                        ),
                      ],
                    ),

                  const SizedBox(height: 20),

                  // Meeting Link (only show for approved appointments)
                  if (appointment["status"]?.toString().toLowerCase() ==
                      "approved") ...[
                    const SectionTitle(title: "Meeting Link"),
                    InfoField(
                        icon: Icons.link,
                        text: appointment["meetingLink"] ?? "doc-consult.com"),
                    const SizedBox(height: 20),
                  ],

                  // E-Prescription (only show for approved appointments)
                  if (appointment["status"]?.toString().toLowerCase() ==
                      "approved") ...[
                    const SectionTitle(title: "E-Prescription"),
                    const InfoField(
                        icon: Icons.picture_as_pdf, text: "e-prescription.pdf"),
                    const SizedBox(height: 20),
                  ],

                  // Treatment Completion (only show for approved appointments)
                  if (appointment["status"]?.toString().toLowerCase() ==
                      "approved") ...[
                    const SectionTitle(title: "Treatment Completion"),
                    const InfoField(
                        icon: Icons.picture_as_pdf, text: "cert.pdf"),
                  ],
                ],
              ),
            ),
          ],
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
    return Container(
      margin: const EdgeInsets.only(top: 24, bottom: 16),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.blue.shade400,
                  Colors.blue.shade600,
                ],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
              letterSpacing: -0.3,
            ),
          ),
        ],
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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: Colors.blue.shade600,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade800,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
