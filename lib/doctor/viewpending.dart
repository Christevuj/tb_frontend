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

  Future<void> _showRejectDialog() async {
    final TextEditingController reasonController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange.shade600),
              const SizedBox(width: 8),
              const Text(
                'Reject Appointment',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Please provide a reason for rejecting this appointment:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: InputDecoration(
                  hintText: 'Enter reason for rejection...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (reasonController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Please provide a reason for rejection'),
                      backgroundColor: Colors.orange.shade600,
                    ),
                  );
                  return;
                }
                Navigator.of(context).pop(reasonController.text.trim());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Confirm Reject'),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      await _rejectAppointment(result);
    }
  }

  Future<void> _rejectAppointment(String reason) async {
    try {
      final firestore = FirebaseFirestore.instance;

      // Move to rejected collection with reason
      await firestore.collection('rejected_appointments').add({
        ...widget.appointment,
        'status': 'rejected',
        'rejectionReason': reason,
        'rejectedAt': FieldValue.serverTimestamp(),
      });

      // Also save to history (you might want to create a separate history collection)
      await firestore.collection('appointment_history').add({
        ...widget.appointment,
        'status': 'rejected',
        'rejectionReason': reason,
        'rejectedAt': FieldValue.serverTimestamp(),
      });

      // Delete from pending collection
      if (widget.appointment['id'] != null) {
        await firestore
            .collection('pending_patient_data')
            .doc(widget.appointment['id'])
            .delete();
      }

      if (mounted) {
        Navigator.pop(context, 'rejected');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Appointment rejected successfully'),
            backgroundColor: Colors.orange.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error rejecting appointment: $e'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
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
                                "Pending Appointment",
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey.shade800,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Review appointment details",
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
                              icon: Icon(Icons.close, 
                                color: Colors.grey.shade700, 
                                size: 22,
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

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
                          height: 220,
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.grey.shade100,
                                Colors.grey.shade50,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 15,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.network(
                              appointment["idImageUrl"],
                              fit: BoxFit.cover,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CircularProgressIndicator(
                                        value: loadingProgress.expectedTotalBytes !=
                                                null
                                            ? loadingProgress
                                                    .cumulativeBytesLoaded /
                                                loadingProgress.expectedTotalBytes!
                                            : null,
                                        strokeWidth: 3,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.blue.shade600,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Loading image...',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade50,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          Icons.error_outline,
                                          color: Colors.red.shade400,
                                          size: 32,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Error loading image',
                                        style: TextStyle(
                                          color: Colors.red.shade600,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),

                      const SizedBox(height: 20),

                      // Schedule with edit
                      const SectionTitle(title: "Schedule"),
                      Container(
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
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.calendar_today,
                                color: Colors.orange.shade600,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                date != null
                                    ? "${date.toLocal().toString().split(" ")[0]} at ${appointment["appointmentTime"] ?? "-"}"
                                    : "-",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey.shade800,
                                  height: 1.3,
                                ),
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: IconButton(
                                icon: Icon(
                                  Icons.edit,
                                  color: Colors.blue.shade600,
                                  size: 20,
                                ),
                                onPressed: () {
                                  // TODO: Open date/time picker
                                },
                              ),
                            ),
                          ],
                        ),
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
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: appointment["meetingLink"] != null &&
                                  appointment["meetingLink"]
                                      .toString()
                                      .isNotEmpty
                              ? Colors.blue.shade50
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: appointment["meetingLink"] != null &&
                                    appointment["meetingLink"]
                                        .toString()
                                        .isNotEmpty
                                ? Colors.blue.shade200
                                : Colors.grey.shade200,
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: appointment["meetingLink"] != null &&
                                      appointment["meetingLink"]
                                          .toString()
                                          .isNotEmpty
                                  ? () async {
                                      await _launchUrl(
                                          appointment["meetingLink"]);
                                    }
                                  : null,
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: appointment["meetingLink"] != null &&
                                              appointment["meetingLink"]
                                                  .toString()
                                                  .isNotEmpty
                                          ? Colors.blue.shade100
                                          : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      appointment["meetingLink"] != null &&
                                              appointment["meetingLink"]
                                                  .toString()
                                                  .isNotEmpty
                                          ? Icons.videocam
                                          : Icons.link_off,
                                      color: appointment["meetingLink"] != null &&
                                              appointment["meetingLink"]
                                                  .toString()
                                                  .isNotEmpty
                                          ? Colors.blue.shade600
                                          : Colors.grey.shade500,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          appointment["meetingLink"] != null &&
                                                  appointment["meetingLink"]
                                                      .toString()
                                                      .isNotEmpty
                                              ? "Meeting link ready"
                                              : "No meeting link generated",
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: appointment["meetingLink"] != null &&
                                                    appointment["meetingLink"]
                                                        .toString()
                                                        .isNotEmpty
                                                ? Colors.blue.shade700
                                                : Colors.grey.shade600,
                                          ),
                                        ),
                                        if (appointment["meetingLink"] != null &&
                                            appointment["meetingLink"]
                                                .toString()
                                                .isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4),
                                            child: Text(
                                              appointment["meetingLink"],
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.blue.shade600,
                                                decoration: TextDecoration.underline,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (appointment["meetingLink"] != null &&
                                      appointment["meetingLink"]
                                          .toString()
                                          .isNotEmpty)
                                    Icon(
                                      Icons.open_in_new,
                                      color: Colors.blue.shade600,
                                      size: 16,
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  await _generateJitsiLink(widget.appointment);
                                },
                                icon: const Icon(Icons.video_call, size: 20),
                                label: Text(
                                  appointment["meetingLink"] != null &&
                                          appointment["meetingLink"]
                                              .toString()
                                              .isNotEmpty
                                      ? "Regenerate Link"
                                      : "Generate Meeting Link",
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade600,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
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
            bottom: 120,
            right: 20,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.orange.shade400,
                    Colors.orange.shade600,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    // TODO: Open chat/message screen
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: const Icon(
                      Icons.message_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Accept/Reject buttons
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Helpful message when no meeting link exists
                  if (appointment['meetingLink'] == null ||
                      appointment['meetingLink'].toString().isEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.orange.shade50, Colors.orange.shade100],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade200,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.info_rounded,
                              color: Colors.orange.shade700,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Generate a meeting link before accepting the appointment',
                              style: TextStyle(
                                color: Colors.orange.shade700,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: (appointment['meetingLink'] != null &&
                                      appointment['meetingLink']
                                          .toString()
                                          .isNotEmpty)
                                  ? [Colors.green.shade400, Colors.green.shade600]
                                  : [Colors.grey.shade400, Colors.grey.shade500],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: (appointment['meetingLink'] != null &&
                                        appointment['meetingLink']
                                            .toString()
                                            .isNotEmpty)
                                    ? Colors.green.withOpacity(0.3)
                                    : Colors.grey.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () async {
                                // Check if meeting link exists before allowing approval
                                if (appointment['meetingLink'] == null ||
                                    appointment['meetingLink'].toString().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                          'Please generate a meeting link before accepting the appointment'),
                                      backgroundColor: Colors.orange.shade600,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      duration: const Duration(seconds: 3),
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

                                  // Also save to history
                                  await firestore.collection('appointment_history').add({
                                    ...appointment,
                                    'status': 'approved',
                                    'approvedAt': FieldValue.serverTimestamp(),
                                  });

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
                                    SnackBar(
                                      content: const Text('Appointment approved successfully'),
                                      backgroundColor: Colors.green.shade600,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content:
                                          Text('Error approving appointment: $e'),
                                      backgroundColor: Colors.red.shade600,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  );
                                }
                              },
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (appointment['meetingLink'] == null ||
                                      appointment['meetingLink'].toString().isEmpty)
                                    const Icon(Icons.warning_rounded,
                                        size: 18, color: Colors.white),
                                  if (appointment['meetingLink'] == null ||
                                      appointment['meetingLink'].toString().isEmpty)
                                    const SizedBox(width: 8),
                                  if (appointment['meetingLink'] != null &&
                                      appointment['meetingLink'].toString().isNotEmpty)
                                    const Icon(Icons.check_circle_rounded,
                                        size: 18, color: Colors.white),
                                  if (appointment['meetingLink'] != null &&
                                      appointment['meetingLink'].toString().isNotEmpty)
                                    const SizedBox(width: 8),
                                  Text(
                                    (appointment['meetingLink'] != null &&
                                            appointment['meetingLink']
                                                .toString()
                                                .isNotEmpty)
                                        ? "Accept"
                                        : "Generate Link First",
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.red.shade400,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () async {
                                await _showRejectDialog();
                              },
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                    color: Colors.red.shade600,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Reject",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.red.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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

// Info Field
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

