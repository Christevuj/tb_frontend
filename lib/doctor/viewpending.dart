import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class Viewpending extends StatefulWidget {
  final Map<String, dynamic> appointment;

  const Viewpending({super.key, required this.appointment});

  @override
  State<Viewpending> createState() => _ViewpendingState();
}

class _ViewpendingState extends State<Viewpending> {
  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not launch meeting link'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _generateJitsiLink(Map<String, dynamic> appointment) async {
    try {
      // Generate a unique room name using appointment ID and timestamp
      final roomName =
          'appointment_${appointment['id']}_${DateTime.now().millisecondsSinceEpoch}';
      final jitsiLink = 'https://meet.jit.si/$roomName';

      // Update the appointment in pending_patient_data collection (where it currently exists)
      await FirebaseFirestore.instance
          .collection('pending_patient_data')
          .doc(appointment['id'])
          .update({
        'meetingLink': jitsiLink,
        'linkGeneratedAt': FieldValue.serverTimestamp(),
      });

      // Update the local appointment data to reflect the change immediately
      setState(() {
        widget.appointment['meetingLink'] = jitsiLink;
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Meeting link generated successfully!'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'Copy Link',
              textColor: Colors.white,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: jitsiLink));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Link copied to clipboard!'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating link: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appointment = widget.appointment;
    DateTime? date;
    try {
      final dynamic appointmentDate = appointment["appointmentDate"];
      if (appointmentDate is Timestamp) {
        date = appointmentDate.toDate();
      }
    } catch (e) {
      debugPrint('Error converting appointmentDate: $e');
    }

    // Validate required fields
    final requiredFields = [
      'patientName',
      'patientEmail',
      'patientPhone',
      'patientAge',
      'patientGender',
      'idType',
      'idImageUrl',
      'appointmentDate',
      'appointmentTime',
      'facility'
    ];

    for (final field in requiredFields) {
      if (!appointment.containsKey(field) || appointment[field] == null) {
        debugPrint('Missing required field: $field');
      }
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(
                bottom: 180), // To avoid overlap with buttons
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
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
                              color: Color(0xE0F44336),
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
                      InfoField(
                          icon: Icons.person,
                          text: appointment["patientName"] ?? "-"),
                      InfoField(
                          icon: Icons.email,
                          text: appointment["patientEmail"] ?? "-"),
                      InfoField(
                          icon: Icons.phone,
                          text: appointment["patientPhone"] ?? "-"),
                      InfoField(
                          icon: Icons.person_outline,
                          text: appointment["patientGender"] ?? "-"),
                      InfoField(
                          icon: Icons.cake,
                          text: appointment["patientAge"]?.toString() ?? "-"),
                      InfoField(
                          icon: Icons.badge,
                          text: appointment["idType"] ?? "-"),

                      // ID Image Section
                      const SectionTitle(title: "ID Image"),
                      if (appointment["idImageUrl"] != null)
                        Container(
                          width: double.infinity,
                          height: 200,
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.black12),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              appointment["idImageUrl"],
                              fit: BoxFit.cover,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes !=
                                            null
                                        ? loadingProgress
                                                .cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return const Center(
                                  child: Text(
                                    'Error loading image',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),

                      const SizedBox(height: 20),

                      // Schedule with edit
                      const SectionTitle(title: "Schedule"),
                      Row(
                        children: [
                          Expanded(
                            child: InfoField(
                              icon: Icons.calendar_today,
                              text: date != null
                                  ? "${date.toLocal().toString().split(" ")[0]} at ${appointment["appointmentTime"] ?? "-"}"
                                  : "-",
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
                      const SectionTitle(title: "Doctor Info"),
                      FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('doctors')
                            .doc(appointment["doctorId"])
                            .get(),
                        builder: (context, snapshot) {
                          debugPrint('\n=== Doctor Info Debug ===');
                          debugPrint('DoctorId: ${appointment["doctorId"]}');
                          debugPrint('Has data: ${snapshot.hasData}');

                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          if (snapshot.hasError) {
                            debugPrint('Error: ${snapshot.error}');
                            return const InfoField(
                              icon: Icons.error,
                              text: "Error loading doctor info",
                            );
                          }

                          if (snapshot.hasData && snapshot.data!.exists) {
                            final doctorData =
                                snapshot.data!.data() as Map<String, dynamic>;
                            debugPrint('Full doctor data: $doctorData');

                            // Get address from affiliations array if it exists
                            String address = "No address available";
                            if (doctorData["affiliations"] != null &&
                                (doctorData["affiliations"] as List)
                                    .isNotEmpty) {
                              address = (doctorData["affiliations"][0]
                                          ["address"] ??
                                      "")
                                  .toString();
                            }

                            return Column(
                              children: [
                                InfoField(
                                  icon: Icons.person,
                                  text: doctorData["fullName"] ??
                                      "No name available",
                                ),
                                InfoField(
                                    icon: Icons.location_on, text: address),
                                InfoField(
                                  icon: Icons.badge,
                                  text:
                                      "${doctorData["experience"] ?? "0"} years of experience",
                                ),
                              ],
                            );
                          }

                          return const InfoField(
                            icon: Icons.person,
                            text: "Doctor information not found",
                          );
                        },
                      ),

                      const SizedBox(height: 20),

                      // Meeting Link with Generate Button
                      const SectionTitle(title: "Meeting Link"),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: appointment["meetingLink"] != null &&
                                      appointment["meetingLink"]
                                          .toString()
                                          .isNotEmpty
                                  ? () async {
                                      await _launchUrl(
                                          appointment["meetingLink"]);
                                    }
                                  : null,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 14),
                                decoration: BoxDecoration(
                                  color: appointment["meetingLink"] != null &&
                                          appointment["meetingLink"]
                                              .toString()
                                              .isNotEmpty
                                      ? Colors.blue.shade50
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color:
                                          appointment["meetingLink"] != null &&
                                                  appointment["meetingLink"]
                                                      .toString()
                                                      .isNotEmpty
                                              ? Colors.blue
                                              : Colors.black12,
                                      width: 0.8),
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
                                    Icon(
                                      appointment["meetingLink"] != null &&
                                              appointment["meetingLink"]
                                                  .toString()
                                                  .isNotEmpty
                                          ? Icons.videocam
                                          : Icons.link,
                                      color:
                                          appointment["meetingLink"] != null &&
                                                  appointment["meetingLink"]
                                                      .toString()
                                                      .isNotEmpty
                                              ? Colors.blue
                                              : Colors.grey,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        appointment["meetingLink"] != null &&
                                                appointment["meetingLink"]
                                                    .toString()
                                                    .isNotEmpty
                                            ? appointment["meetingLink"]
                                            : "No link generated yet",
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: appointment["meetingLink"] !=
                                                      null &&
                                                  appointment["meetingLink"]
                                                      .toString()
                                                      .isNotEmpty
                                              ? Colors.blue
                                              : Colors.grey[600],
                                          decoration:
                                              appointment["meetingLink"] !=
                                                          null &&
                                                      appointment["meetingLink"]
                                                          .toString()
                                                          .isNotEmpty
                                                  ? TextDecoration.underline
                                                  : TextDecoration.none,
                                        ),
                                      ),
                                    ),
                                    if (appointment["meetingLink"] != null &&
                                        appointment["meetingLink"]
                                            .toString()
                                            .isNotEmpty)
                                      const Icon(
                                        Icons.open_in_new,
                                        color: Colors.blue,
                                        size: 16,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () async {
                              await _generateJitsiLink(widget.appointment);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              elevation: 4,
                            ),
                            child: const Text(
                              "Generate Link",
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ],
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Helpful message when no meeting link exists
                if (appointment['meetingLink'] == null ||
                    appointment['meetingLink'].toString().isEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info,
                            color: Colors.orange.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Generate a meeting link before accepting the appointment',
                            style: TextStyle(
                              color: Colors.orange.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: PhysicalModel(
                        color: Colors.transparent,
                        shadowColor: Colors.black26,
                        elevation: 6,
                        borderRadius: BorderRadius.circular(8),
                        child: ElevatedButton(
                          onPressed: () async {
                            // Check if meeting link exists before allowing approval
                            if (appointment['meetingLink'] == null ||
                                appointment['meetingLink'].toString().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Please generate a meeting link before accepting the appointment'),
                                  backgroundColor: Colors.orange,
                                  duration: Duration(seconds: 3),
                                ),
                              );
                              return; // Prevent approval
                            }

                            try {
                              final firestore = FirebaseFirestore.instance;

                              // First, create a copy in approved_appointments
                              final approvedRef = await firestore
                                  .collection('approved_appointments')
                                  .add({
                                ...appointment,
                                'status': 'approved',
                                'approvedAt': FieldValue.serverTimestamp(),
                              });

                              debugPrint(
                                  'Created approved appointment: ${approvedRef.id}');

                              // Also update the patient's profile with this appointment
                              if (appointment['patientUid'] != null) {
                                await firestore
                                    .collection('users')
                                    .doc(appointment['patientUid'])
                                    .collection('appointments')
                                    .add({
                                  ...appointment,
                                  'status': 'approved',
                                  'approvedAt': FieldValue.serverTimestamp(),
                                });
                              }

                              // Delete from pending collection
                              if (appointment['id'] != null) {
                                await firestore
                                    .collection('pending_patient_data')
                                    .doc(appointment['id'])
                                    .delete();
                              }

                              Navigator.pop(context,
                                  'approved'); // Return 'approved' status
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Appointment approved successfully'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      Text('Error approving appointment: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                (appointment['meetingLink'] != null &&
                                        appointment['meetingLink']
                                            .toString()
                                            .isNotEmpty)
                                    ? Colors.redAccent
                                    : Colors.grey,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (appointment['meetingLink'] == null ||
                                  appointment['meetingLink'].toString().isEmpty)
                                const Icon(Icons.warning,
                                    size: 16, color: Colors.white),
                              if (appointment['meetingLink'] == null ||
                                  appointment['meetingLink'].toString().isEmpty)
                                const SizedBox(width: 4),
                              Text(
                                (appointment['meetingLink'] != null &&
                                        appointment['meetingLink']
                                            .toString()
                                            .isNotEmpty)
                                    ? "Accept"
                                    : "Generate Link First",
                                style: const TextStyle(
                                    fontSize: 16, color: Colors.white),
                              ),
                            ],
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
                          onPressed: () async {
                            try {
                              final firestore = FirebaseFirestore.instance;

                              // Move to rejected collection
                              await firestore
                                  .collection('rejected_appointments')
                                  .add({
                                ...appointment,
                                'status': 'rejected',
                                'rejectedAt': FieldValue.serverTimestamp(),
                              });

                              // Delete from pending collection
                              if (appointment['id'] != null) {
                                await firestore
                                    .collection('pending_patient_data')
                                    .doc(appointment['id'])
                                    .delete();
                              }

                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Appointment rejected'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      Text('Error rejecting appointment: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(
                                color: Colors.redAccent, width: 2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            "Reject",
                            style: TextStyle(
                                fontSize: 16, color: Colors.redAccent),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
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
