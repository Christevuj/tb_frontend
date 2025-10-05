import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:printing/printing.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:typed_data';
import 'dart:io';
import 'certificate.dart';
import 'prescription.dart';
import '../services/chat_service.dart';
import '../chat_screens/chat_screen.dart';

class Viewpostappointment extends StatefulWidget {
  final Map<String, dynamic> appointment;

  const Viewpostappointment({super.key, required this.appointment});

  @override
  State<Viewpostappointment> createState() => _ViewpostappointmentState();
}

class _ViewpostappointmentState extends State<Viewpostappointment> {
  bool _isPatientInfoExpanded = false;
  bool _isScheduleExpanded = false;
  bool _isPrescriptionExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.teal.shade50,
            Colors.white,
          ],
        ),
      ),
      child: SingleChildScrollView(
        child: Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 3,
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Modern Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.teal.shade600,
                      Colors.teal.shade400,
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.medical_information,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Post Appointment Details",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.visible,
                            maxLines: 2,
                            softWrap: true,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Comprehensive appointment summary",
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                            overflow: TextOverflow.visible,
                            maxLines: 2,
                            softWrap: true,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 28),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Content Container
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

              // Patient Details Section - Collapsible Card
              _buildCollapsibleCard(
                title: "Patient Information",
                subtitle: "Complete patient details available",
                isExpanded: _isPatientInfoExpanded,
                onToggle: () {
                  setState(() {
                    _isPatientInfoExpanded = !_isPatientInfoExpanded;
                  });
                },
                bullets: [
                  'Full Name: ${widget.appointment["patientName"] ?? "Unknown Patient"}',
                  'Email: ${widget.appointment["patientEmail"] ?? "No email provided"}',
                  'Phone: ${widget.appointment["patientPhone"] ?? "No phone provided"}',
                  'Gender: ${widget.appointment["patientGender"] ?? "Not specified"} | Age: ${widget.appointment["patientAge"]?.toString() ?? "Not specified"}',
                ],
                buttonText: 'MESSAGE PATIENT',
                onPressed: _openChat,
              ),

              const SizedBox(height: 12),

              // Schedule Section - Enhanced Card Design
              _buildScheduleCard(
                title: "Appointment Schedule",
                subtitle: "Scheduled appointment details",
                isExpanded: _isScheduleExpanded,
                onToggle: () {
                  setState(() {
                    _isScheduleExpanded = !_isScheduleExpanded;
                  });
                },
                appointment: widget.appointment,
              ),

              const SizedBox(height: 12),

              // Electronic Prescription Section - Collapsible Card
              _buildCollapsibleCard(
                title: "Electronic Prescription",
                subtitle: "Prescription details and medication list",
                isExpanded: _isPrescriptionExpanded,
                onToggle: () {
                  setState(() {
                    _isPrescriptionExpanded = !_isPrescriptionExpanded;
                  });
                },
                bullets: _buildPrescriptionBullets(),
                buttonText: 'View prescription PDF',
                onPressed: () {
                  _viewPrescriptionPdf(context, widget.appointment);
                },
              ),

              const SizedBox(height: 16),

              // Certificate Management Section - Updated UI
              _buildCertificateCard(widget.appointment),

              const SizedBox(height: 16),

              // Patient Journey Timeline Section - Enhanced Design
              _buildTimelineCard(),

              const SizedBox(height: 32),

              // Action Buttons Section
              _buildActionButtons(widget.appointment),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Method to open chat with patient
  Future<void> _openChat() async {
    try {
      final ChatService chatService = ChatService();
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('No authenticated user found');
      }

      final patientId = widget.appointment['patientUid'];
      final patientName =
          widget.appointment['patientName'] ?? 'Unknown Patient';

      if (patientId == null) {
        throw Exception('Patient ID not found');
      }

      // Create or update user docs for chat - ensure both users exist in users collection
      await chatService.createUserDoc(
        userId: currentUser.uid,
        name: 'Dr. ${currentUser.displayName ?? 'Doctor'}',
        role: 'doctor',
      );

      await chatService.createUserDoc(
        userId: patientId,
        name: patientName,
        role: 'patient',
      );

      // Navigate to chat screen
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              currentUserId: currentUser.uid,
              otherUserId: patientId,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening chat: $e'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    }
  }



  // Helper method to build timeline card
  Widget _buildTimelineCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('prescriptions')
          .where('appointmentId', isEqualTo: widget.appointment['appointmentId'])
          .snapshots(),
      builder: (context, prescriptionSnapshot) {
        bool hasPrescription = false;

        if (prescriptionSnapshot.hasData && prescriptionSnapshot.data!.docs.isNotEmpty) {
          hasPrescription = true;
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('certificates')
              .where('appointmentId', isEqualTo: widget.appointment['appointmentId'])
              .snapshots(),
          builder: (context, certificateSnapshot) {
            bool hasCertificate = false;

            if (certificateSnapshot.hasData && certificateSnapshot.data!.docs.isNotEmpty) {
              hasCertificate = true;
            }

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200, width: 1),
              ),
              color: Colors.white,
              child: Column(
                children: [
                  // Card Header with Blue Accent Strip
                  Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF0A84FF),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      margin: const EdgeInsets.only(left: 4),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0A84FF).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.timeline,
                              color: Color(0xFF0A84FF),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Patient Journey Timeline',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Treatment progress tracking',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Timeline Content
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Step-by-step Instructions Container
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildStepInstruction(
                                stepNumber: '1',
                                instruction: 'Patient requested appointment with a Doctor',
                                isCompleted: true,
                              ),
                              const SizedBox(height: 8),
                              _buildStepInstruction(
                                stepNumber: '2',
                                instruction: 'Doctor confirmed and approved the appointment schedule',
                                isCompleted: true,
                              ),
                              const SizedBox(height: 8),
                              _buildStepInstruction(
                                stepNumber: '3',
                                instruction: 'Consultation completed with prescription issued',
                                isCompleted: hasPrescription, // Now checks if prescription exists
                              ),
                              const SizedBox(height: 8),
                              _buildStepInstruction(
                                stepNumber: '4',
                                instruction: 'Treatment completion certificate delivered',
                                isCompleted: hasCertificate, // Now checks if certificate exists
                              ),
                              const SizedBox(height: 8),
                              _buildStepInstruction(
                                stepNumber: '5',
                                instruction: 'Full TB treatment program completed',
                                isCompleted: widget.appointment["treatmentCompleted"] == true,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Helper method to build step instruction
  Widget _buildStepInstruction({
    required String stepNumber,
    required String instruction,
    required bool isCompleted,
  }) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: isCompleted ? Colors.green.shade600 : Colors.grey.shade300,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : Text(
                    stepNumber,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            instruction,
            style: TextStyle(
              fontSize: 13,
              color: isCompleted ? Colors.green.shade800 : Colors.grey.shade700,
              fontWeight: isCompleted ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  // Helper method to get icon for bullet points
  static IconData _iconForBullet(String text) {
    if (text.toLowerCase().contains('phone')) return Icons.phone;
    if (text.toLowerCase().contains('email')) return Icons.email;
    if (text.toLowerCase().contains('name')) return Icons.person;
    if (text.toLowerCase().contains('date')) return Icons.calendar_today;
    if (text.toLowerCase().contains('time')) return Icons.access_time;
    if (text.toLowerCase().contains('facility')) return Icons.location_on;
    if (text.toLowerCase().contains('prescription')) return Icons.medical_services;
    if (text.toLowerCase().contains('medicine')) return Icons.medication;
    if (text.toLowerCase().contains('gender')) return Icons.people;
    return Icons.info;
  }

  // Helper method to build styled text with bold labels
  Widget _buildStyledBulletText(String text) {
    final colonIndex = text.indexOf(':');
    if (colonIndex != -1 && colonIndex < text.length - 1) {
      final label = text.substring(0, colonIndex + 1);
      final value = text.substring(colonIndex + 1);
      return RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 14, color: Colors.black87),
          children: [
            TextSpan(
              text: label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value),
          ],
        ),
      );
    }
    return Text(
      text,
      style: const TextStyle(fontSize: 14),
    );
  }

  // Helper method to build collapsible detailed card
  Widget _buildCollapsibleCard({
    required String title,
    required String subtitle,
    required bool isExpanded,
    required VoidCallback onToggle,
    required List<String> bullets,
    required String buttonText,
    required VoidCallback onPressed,
  }) {
    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          // Header - Always visible
          InkWell(
            onTap: onToggle,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
              ),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Color(0xFF0A84FF),
                      borderRadius: BorderRadius.all(Radius.circular(3)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: const Color(0xFF0A84FF),
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
          // Expandable content
          if (isExpanded) ...[
            const Divider(height: 1),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: bullets
                        .map((b) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6.0),
                              child: Row(
                                children: [
                                  Icon(
                                    _iconForBullet(b),
                                    size: 18,
                                    color: const Color(0xFF0A84FF),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _buildStyledBulletText(b),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  // Consistent button styling for all actions
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: onPressed,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF0A84FF)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      icon: buttonText.contains('MESSAGE')
                          ? const Icon(Icons.message, color: Color(0xFF0A84FF), size: 16)
                          : const Icon(Icons.visibility, color: Color(0xFF0A84FF), size: 16),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10),
                        child: Text(
                          buttonText,
                          style: const TextStyle(color: Color(0xFF0A84FF)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Helper method to build schedule card (read-only for approved appointments)
  Widget _buildScheduleCard({
    required String title,
    required String subtitle,
    required bool isExpanded,
    required VoidCallback onToggle,
    required Map<String, dynamic> appointment,
  }) {
    DateTime? date;
    try {
      final dynamic appointmentDate = appointment["date"];
      if (appointmentDate is Timestamp) {
        date = appointmentDate.toDate();
      } else if (appointmentDate is DateTime) {
        date = appointmentDate;
      }
    } catch (e) {
      debugPrint('Error converting appointmentDate: $e');
    }

    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          // Header - Always visible
          InkWell(
            onTap: onToggle,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
              ),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Color(0xFF0A84FF),
                      borderRadius: BorderRadius.all(Radius.circular(3)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: const Color(0xFF0A84FF),
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
          // Expandable content
          if (isExpanded) ...[
            const Divider(height: 1),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
              ),
              child: Column(
                children: [
                  'Date: ${date != null ? date.toLocal().toString().split(" ")[0] : "Not specified"}',
                  'Time: ${appointment["appointmentTime"] ?? "No time set"}',
                ]
                    .map((b) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                          child: Row(
                            children: [
                              Icon(
                                _iconForBullet(b),
                                size: 18,
                                color: const Color(0xFF0A84FF),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildStyledBulletText(b),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Helper method to build prescription bullets
  List<String> _buildPrescriptionBullets() {
    final prescriptionData = widget.appointment["prescriptionData"];
    List<String> bullets = [];
    
    if (prescriptionData == null) {
      bullets.add('No prescription data available');
      return bullets;
    }

    if (prescriptionData["medicines"] != null) {
      final medicines = prescriptionData["medicines"] as List;
      for (var medicine in medicines) {
        bullets.add('${medicine['name']} - ${medicine['dosage']} (${medicine['frequency']})');
      }
    }

    if (prescriptionData["notes"] != null && prescriptionData["notes"].toString().isNotEmpty) {
      bullets.add('Additional notes: ${prescriptionData["notes"]}');
    }

    if (bullets.isEmpty) {
      bullets.add('Prescription details available');
    }

    return bullets;
  }

  // Helper method to build certificate card with new UI
  Widget _buildCertificateCard(Map<String, dynamic> appointment) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('certificates')
          .where('appointmentId', isEqualTo: appointment['appointmentId'])
          .snapshots(),
      builder: (context, snapshot) {
        bool hasCertificate = false;

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          hasCertificate = true;
        }

        return Card(
          elevation: 2,
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
            ),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Color(0xFF0A84FF),
                    borderRadius: BorderRadius.all(Radius.circular(3)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Certificate Of Completion",
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasCertificate
                            ? "Certificate available for viewing"
                            : "Issue completion certificate",
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: appointment["meetingCompleted"] == true
                              ? () {
                                  if (hasCertificate) {
                                    // View certificate if already created
                                    _viewCertificatePdf(context, appointment);
                                  } else {
                                    // Create certificate if not created yet
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            Certificate(appointment: appointment),
                                      ),
                                    );
                                  }
                                }
                              : null,
                          icon: Icon(
                            appointment["meetingCompleted"] == true
                                ? (hasCertificate ? Icons.visibility : Icons.add)
                                : Icons.lock,
                            size: 20,
                          ),
                          label: Text(
                            appointment["meetingCompleted"] == true
                                ? (hasCertificate ? "View Certificate" : "Add Certificate")
                                : "Complete Meeting First",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: appointment["meetingCompleted"] == true
                                ? Colors.orange.shade600
                                : Colors.grey.shade400,
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
              ],
            ),
          ),
        );
      },
    );
  }

  // Build action buttons for Complete Meeting/Treatment
  Widget _buildActionButtons(Map<String, dynamic> appointment) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('prescriptions')
          .where('appointmentId', isEqualTo: appointment['appointmentId'])
          .snapshots(),
      builder: (context, prescriptionSnapshot) {
        bool hasPrescription = false;
        Map<String, dynamic>? prescriptionData;

        if (prescriptionSnapshot.hasData && prescriptionSnapshot.data!.docs.isNotEmpty) {
          hasPrescription = true;
          prescriptionData =
              prescriptionSnapshot.data!.docs.first.data() as Map<String, dynamic>;
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('certificates')
              .where('appointmentId', isEqualTo: appointment['appointmentId'])
              .snapshots(),
          builder: (context, certificateSnapshot) {
            bool hasCertificate = false;

            if (certificateSnapshot.hasData && certificateSnapshot.data!.docs.isNotEmpty) {
              hasCertificate = true;
            }

            return Container(
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
                  // E-prescription requirement message when no prescription exists
                  if (!hasPrescription)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.orange.shade50,
                            Colors.orange.shade100
                          ],
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
                              Icons.medical_services_rounded,
                              color: Colors.orange.shade700,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Create an e-prescription first before proceeding with appointment actions',
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
                  
                  // Certificate requirement message when prescription exists but no certificate
                  if (hasPrescription && !hasCertificate)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.orange.shade50,
                            Colors.orange.shade100
                          ],
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
                              Icons.card_membership,
                              color: Colors.orange.shade700,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Create certificate of completion first before marking treatment as completed',
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
                  
                  // Upload Prescription First Button
                  if (!hasPrescription)
                    Container(
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.grey.shade400,
                            Colors.grey.shade500
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            // Navigate to prescription creation
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => Prescription(
                                  appointment: appointment,
                                ),
                              ),
                            );
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle_rounded,
                                  size: 18, color: Colors.white),
                              const SizedBox(width: 8),
                              const Text(
                                "Complete Meeting",
                                style: TextStyle(
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

                  // Treatment Completed button - only enabled when both prescription and certificate exist
                  if (hasPrescription)
                    Container(
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: hasCertificate
                              ? [
                                  Colors.green.shade400,
                                  Colors.green.shade600
                                ]
                              : [
                                  Colors.grey.shade400,
                                  Colors.grey.shade500
                                ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: hasCertificate 
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
                          onTap: hasCertificate ? () async {
                            try {
                              // Create a completed appointment record first
                              await FirebaseFirestore.instance
                                  .collection('completed_appointments')
                                  .add({
                                ...appointment,
                                'prescriptionData': prescriptionData,
                                'meetingCompleted': true,
                                'completedAt': FieldValue.serverTimestamp(),
                              });

                              // Send notification to patient about completed meeting and e-prescription
                              await FirebaseFirestore.instance
                                  .collection('patient_notifications')
                                  .add({
                                'patientUid': appointment['patientUid'] ??
                                    appointment['patientId'],
                                'appointmentId': appointment['appointmentId'],
                                'type': 'meeting_completed',
                                'title': 'Meeting Completed',
                                'message':
                                    'Your appointment with the doctor has been completed. E-prescription is now available for viewing and download.',
                                'prescriptionData': prescriptionData,
                                'createdAt': FieldValue.serverTimestamp(),
                                'isRead': false,
                                'doctorName':
                                    appointment['doctorName'] ?? 'Your Doctor',
                              });

                              // Remove the appointment from approved_appointments
                              await FirebaseFirestore.instance
                                  .collection('approved_appointments')
                                  .doc(appointment['appointmentId'])
                                  .delete();

                              if (context.mounted) {
                                // Show success message
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        "Treatment completed successfully! Appointment removed from active appointments. Patient notified about completion."),
                                    backgroundColor: Colors.green,
                                  ),
                                );

                                // Navigate back to doctor dashboard
                                Navigator.of(context).pop();
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("Error completing treatment: $e"),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          } : null,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle_rounded,
                                  size: 18, color: Colors.white),
                              const SizedBox(width: 8),
                              Text(
                                hasCertificate 
                                    ? "Treatment Completed"
                                    : "Create Certificate First",
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
                ],
              ),
            );
          },
        );
      },
    );
  }



  Widget ModernInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }





  // Static method to view prescription PDF
  static void _viewPrescriptionPdf(
      BuildContext context, Map<String, dynamic> appointmentData) async {
    try {
      // First check the prescriptions collection for PDF data
      final prescriptionSnapshot = await FirebaseFirestore.instance
          .collection('prescriptions')
          .where('appointmentId', isEqualTo: appointmentData['appointmentId'])
          .get();

      if (prescriptionSnapshot.docs.isNotEmpty) {
        final prescriptionData = prescriptionSnapshot.docs.first.data();

        // Check for Cloudinary URL first
        if (prescriptionData['pdfUrl'] != null &&
            prescriptionData['pdfUrl'].toString().isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Opening cloud PDF - implement web view or download'),
              backgroundColor: Colors.orange,
            ),
          );
          // TODO: Implement cloud PDF viewing
          return;
        }

        // Check for local PDF path
        if (prescriptionData['pdfPath'] != null) {
          final file = File(prescriptionData['pdfPath']);
          if (await file.exists()) {
            final pdfBytes = await file.readAsBytes();
            // Show in-app PDF viewer
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => _PdfViewerScreen(
                  pdfBytes: pdfBytes,
                  title: 'Prescription PDF',
                  filename: 'Prescription.pdf',
                ),
              ),
            );
            return;
          }
        }
      }

      // Fallback to old prescription data structure
      final prescriptionData = appointmentData["prescriptionData"];
      if (prescriptionData != null && prescriptionData['pdfPath'] != null) {
        final file = File(prescriptionData['pdfPath']);
        if (await file.exists()) {
          final pdfBytes = await file.readAsBytes();
          // Show in-app PDF viewer
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => _PdfViewerScreen(
                pdfBytes: pdfBytes,
                title: 'Prescription PDF',
                filename: 'Prescription.pdf',
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'PDF file not found. It may have been moved or deleted.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF version not available.'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error viewing prescription: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Static method to view certificate PDF
  static void _viewCertificatePdf(
      BuildContext context, Map<String, dynamic> appointmentData) async {
    try {
      // Query the certificates collection for this appointment
      final certificateSnapshot = await FirebaseFirestore.instance
          .collection('certificates')
          .where('appointmentId',
              isEqualTo:
                  appointmentData['appointmentId'] ?? appointmentData['id'])
          .get();

      if (certificateSnapshot.docs.isNotEmpty) {
        final certificateData = certificateSnapshot.docs.first.data();

        // Check for local PDF path first (most likely to exist)
        if (certificateData['pdfPath'] != null) {
          final file = File(certificateData['pdfPath']);
          if (await file.exists()) {
            final pdfBytes = await file.readAsBytes();
            // Show in-app PDF viewer
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => _PdfViewerScreen(
                  pdfBytes: pdfBytes,
                  title: 'TB Treatment Certificate',
                  filename: 'TB_Certificate.pdf',
                ),
              ),
            );
            return;
          }
        }

        // Check for Cloudinary URL
        if (certificateData['pdfUrl'] != null &&
            certificateData['pdfUrl'].toString().isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Cloud certificate viewing - implement web view or download'),
              backgroundColor: Colors.orange,
            ),
          );
          // TODO: Implement cloud PDF viewing for certificates
          return;
        }
      }

      // No certificate found
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Certificate PDF not found. It may have been moved or deleted.'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error viewing certificate: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// 🔹 Modern Section Title Widget
class SectionTitle extends StatelessWidget {
  final String title;
  const SectionTitle({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.teal.shade100,
            Colors.teal.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.teal.shade600,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.label,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.teal.shade800,
            ),
          ),
        ],
      ),
    );
  }
}

// 🔹 Modern Info Field Widget
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Colors.grey.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.teal.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon, 
              color: Colors.teal.shade700,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PdfViewerScreen extends StatelessWidget {
  final Uint8List pdfBytes;
  final String title;
  final String filename;

  const _PdfViewerScreen({
    required this.pdfBytes,
    required this.title,
    required this.filename,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () async {
              await Printing.sharePdf(
                bytes: pdfBytes,
                filename: filename,
              );
            },
          ),
        ],
      ),
      body: PdfPreview(
        build: (format) => pdfBytes,
        allowPrinting: true,
        allowSharing: true,
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        actions: const [],
      ),
    );
  }
}
