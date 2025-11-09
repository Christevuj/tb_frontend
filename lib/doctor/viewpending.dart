import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tb_frontend/chat_screens/chat_screen.dart';
import 'package:tb_frontend/services/chat_service.dart';
import 'package:tb_frontend/screens/video_call_screen.dart';
import 'package:tb_frontend/services/webrtc_service.dart';
import 'package:tb_frontend/doctor/dmenu.dart';

class Viewpending extends StatefulWidget {
  final Map<String, dynamic> appointment;

  const Viewpending({super.key, required this.appointment});

  @override
  State<Viewpending> createState() => _ViewpendingState();
}

class _ViewpendingState extends State<Viewpending> {
  // State variables for collapsible sections
  bool _isPatientInfoExpanded = true;
  bool _isUploadedIdExpanded = false;
  bool _isScheduleExpanded = false;

  Future<void> _showRejectDialog() async {
    final TextEditingController reasonController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return _ModernRejectDialog(reasonController: reasonController);
      },
    );

    if (result != null && result.isNotEmpty) {
      await _rejectAppointment(result);
    }
  }

  Future<void> _rejectAppointment(String reason) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final appointmentId =
          widget.appointment['id'] ?? widget.appointment['appointmentId'];

      // Prepare the appointment data with rejection details
      final rejectedAppointmentData = {
        ...widget.appointment,
        'rejectionReason': reason,
        'rejectedAt': FieldValue.serverTimestamp(),
        'status': 'rejected',
      };

      // Add to rejected collection with reason
      await firestore
          .collection('rejected_appointments')
          .add(rejectedAppointmentData);

      // ADD TO APPOINTMENT HISTORY - So it shows up in dhistory.dart with rejection reason
      await firestore
          .collection('appointment_history')
          .add(rejectedAppointmentData);

      // Also update the patient's profile with this rejected appointment
      if (widget.appointment['patientUid'] != null) {
        await firestore
            .collection('users')
            .doc(widget.appointment['patientUid'])
            .collection('appointments')
            .add(rejectedAppointmentData);
      }

      // Delete from pending collection
      if (appointmentId != null) {
        await firestore
            .collection('pending_patient_data')
            .doc(appointmentId)
            .delete();
      }

      Navigator.pop(context, 'rejected');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Appointment rejected and moved to history'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error rejecting appointment: $e'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _showScheduleEditDialog() async {
    final appointment = widget.appointment;
    DateTime currentDate = DateTime.now();
    String currentTime = appointment["appointmentTime"] ?? "09:00 AM";

    try {
      final dynamic appointmentDate = appointment["appointmentDate"];
      if (appointmentDate is Timestamp) {
        currentDate = appointmentDate.toDate();
      }
    } catch (e) {
      debugPrint('Error converting appointmentDate: $e');
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return _ScheduleEditDialog(
          initialDate: currentDate,
          initialTime: currentTime,
        );
      },
    );

    if (result != null) {
      await _updateSchedule(result['date'], result['time']);
    }
  }

  Future<void> _updateSchedule(DateTime newDate, String newTime) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final docId = widget.appointment['id'];
      if (docId != null) {
        await firestore.collection('pending_patient_data').doc(docId).update({
          'appointmentDate': Timestamp.fromDate(newDate),
          'appointmentTime': newTime,
          'lastScheduleUpdatedAt': FieldValue.serverTimestamp(),
        });

        setState(() {
          widget.appointment['appointmentDate'] = Timestamp.fromDate(newDate);
          widget.appointment['appointmentTime'] = newTime;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Schedule updated successfully'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating schedule: $e'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _generateWebRTCRoom(Map<String, dynamic> appointment) async {
    try {
      // Generate a unique room ID for WebRTC
      final String roomId =
          'room_${appointment['patientUid']}_${DateTime.now().millisecondsSinceEpoch}';

      // Update appointment with room ID
      final firestore = FirebaseFirestore.instance;
      final appointmentId = appointment['id'] ?? appointment['appointmentId'];

      if (appointmentId != null) {
        await firestore
            .collection('pending_patient_data')
            .doc(appointmentId)
            .update({
          'roomId': roomId,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        setState(() {
          appointment['roomId'] = roomId;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Video call room generated successfully'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating meeting link: $e'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
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

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
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
                  color: Colors.red.shade600,
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
                        Icons.pending_actions,
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
                            "Pending Appointment Details",
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
                            "Review and manage appointment request",
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
                      icon: const Icon(Icons.close,
                          color: Colors.white, size: 28),
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
                        'Full Name: ${appointment["patientName"] ?? "Unknown Patient"}',
                        'Address: ${appointment["patientAddress"] ?? "No address provided"}',
                        'Email: ${appointment["patientEmail"] ?? "No email provided"}',
                        'Phone: ${appointment["patientPhone"] ?? "No phone provided"}',
                        'Gender: ${appointment["patientGender"] ?? "Not specified"} | Age: ${appointment["patientAge"]?.toString() ?? "Not specified"}',
                      ],
                      buttonText: 'MESSAGE PATIENT',
                      onPressed: _openChat,
                    ),

                    const SizedBox(height: 12),

                    // Uploaded ID Section - Collapsible Card
                    _buildUploadedIdCard(
                      title: "Uploaded ID",
                      subtitle: "Patient identification document",
                      isExpanded: _isUploadedIdExpanded,
                      onToggle: () {
                        setState(() {
                          _isUploadedIdExpanded = !_isUploadedIdExpanded;
                        });
                      },
                      appointment: appointment,
                    ),

                    const SizedBox(height: 12),

                    // Schedule Section with Edit Button - Collapsible Card
                    _buildScheduleCard(
                      title: "Appointment Schedule",
                      subtitle: "Scheduled appointment details (editable)",
                      isExpanded: _isScheduleExpanded,
                      onToggle: () {
                        setState(() {
                          _isScheduleExpanded = !_isScheduleExpanded;
                        });
                      },
                      date: date,
                      appointment: appointment,
                    ),

                    const SizedBox(height: 12),

                    // Meeting Link Section - Non-collapsible Card
                    _buildVideoCallCard(
                      title: "Meeting Link",
                      subtitle: "Generate or view meeting link",
                      appointment: appointment,
                    ),

                    const SizedBox(height: 16),

                    // Patient Journey Timeline Section - Card Design
                    Card(
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
                                      color: const Color(0xFF0A84FF)
                                          .withOpacity(0.1),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                    border:
                                        Border.all(color: Colors.blue.shade200),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildStepInstruction(
                                        stepNumber: '1',
                                        instruction:
                                            'Patient requested appointment with a Doctor',
                                        isCompleted: true,
                                      ),
                                      const SizedBox(height: 8),
                                      _buildStepInstruction(
                                        stepNumber: '2',
                                        instruction:
                                            'Doctor confirmed and approved the appointment schedule',
                                        isCompleted:
                                            false, // This should be false for pending appointments
                                      ),
                                      const SizedBox(height: 8),
                                      _buildStepInstruction(
                                        stepNumber: '3',
                                        instruction:
                                            'Consultation completed with prescription issued',
                                        isCompleted: false,
                                      ),
                                      const SizedBox(height: 8),
                                      _buildStepInstruction(
                                        stepNumber: '4',
                                        instruction:
                                            'Treatment completion certificate delivered',
                                        isCompleted: false,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Bottom Action Buttons Section
                    _buildActionButtons(appointment),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build action buttons for Accept/Reject
  Widget _buildActionButtons(Map<String, dynamic> appointment) {
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
          // Helpful message when no room ID exists
          if (appointment['roomId'] == null ||
              appointment['roomId'].toString().isEmpty)
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
          // Message Patient Button

          Row(
            children: [
              Expanded(
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: (appointment['roomId'] != null &&
                              appointment['roomId'].toString().isNotEmpty)
                          ? [Colors.green.shade400, Colors.green.shade600]
                          : [Colors.grey.shade400, Colors.grey.shade500],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: (appointment['roomId'] != null &&
                                appointment['roomId'].toString().isNotEmpty)
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
                        // Check if room ID exists before allowing approval
                        if (appointment['roomId'] == null ||
                            appointment['roomId'].toString().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                  'Please generate a video call room before accepting the appointment'),
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

                          // Note: Appointment will be moved to history only after treatment completion

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

                          // Navigate back to landing page (home tab)
                          if (context.mounted) {
                            Navigator.of(context)
                                .popUntil((route) => route.isFirst);
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) =>
                                    const DoctorMainWrapper(initialIndex: 0),
                              ),
                            );

                            // Show success message
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                    'Appointment approved successfully'),
                                backgroundColor: Colors.green.shade600,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error approving appointment: $e'),
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
                          if (appointment['roomId'] == null ||
                              appointment['roomId'].toString().isEmpty)
                            const Icon(Icons.warning_rounded,
                                size: 18, color: Colors.white),
                          if (appointment['roomId'] == null ||
                              appointment['roomId'].toString().isEmpty)
                            const SizedBox(width: 8),
                          if (appointment['roomId'] != null &&
                              appointment['roomId'].toString().isNotEmpty)
                            const Icon(Icons.check_circle_rounded,
                                size: 18, color: Colors.white),
                          if (appointment['roomId'] != null &&
                              appointment['roomId'].toString().isNotEmpty)
                            const SizedBox(width: 8),
                          Text(
                            (appointment['roomId'] != null &&
                                    appointment['roomId'].toString().isNotEmpty)
                                ? "Accept"
                                : "Accept",
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
    if (text.toLowerCase().contains('id type')) return Icons.badge;
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
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
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
                              padding:
                                  const EdgeInsets.symmetric(vertical: 6.0),
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
                          ? const Icon(Icons.message,
                              color: Color(0xFF0A84FF), size: 16)
                          : const SizedBox.shrink(),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12.0, vertical: 10),
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

  // Helper method to build schedule card with edit functionality
  Widget _buildScheduleCard({
    required String title,
    required String subtitle,
    required bool isExpanded,
    required VoidCallback onToggle,
    required DateTime? date,
    required Map<String, dynamic> appointment,
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
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                      ],
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
                        _showScheduleEditDialog();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
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

  // Helper method to build meeting link card
  Widget _buildVideoCallCard({
    required String title,
    required String subtitle,
    required Map<String, dynamic> appointment,
  }) {
    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
        ),
        child: Column(
          children: [
            // Header section
            Row(
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
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Content section (always visible now)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: appointment["roomId"] != null &&
                        appointment["roomId"].toString().isNotEmpty
                    ? Colors.green.shade50
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: appointment["roomId"] != null &&
                          appointment["roomId"].toString().isNotEmpty
                      ? Colors.green.shade200
                      : Colors.grey.shade200,
                  width: 1,
                ),
              ),
              child: GestureDetector(
                onTap: appointment["roomId"] != null &&
                        appointment["roomId"].toString().isNotEmpty
                    ? () async {
                        try {
                          // Show loading indicator
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => AlertDialog(
                              content: Row(
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(width: 16),
                                  Text('Preparing video call...'),
                                ],
                              ),
                            ),
                          );

                          // Check permissions before starting video call
                          final webrtcService = WebRTCService();
                          bool hasPermissions =
                              await webrtcService.requestPermissions();

                          // Close loading dialog
                          Navigator.pop(context);

                          if (!hasPermissions) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Camera and microphone permissions are required for video calls. Please enable them in your device settings.',
                                  style: TextStyle(color: Colors.white),
                                ),
                                backgroundColor: Colors.orange.shade700,
                                behavior: SnackBarBehavior.floating,
                                duration: Duration(seconds: 5),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                action: SnackBarAction(
                                  label: 'Settings',
                                  textColor: Colors.white,
                                  onPressed: () {
                                    openAppSettings();
                                  },
                                ),
                              ),
                            );
                            return;
                          }

                          // Navigate to WebRTC video call screen with fullscreen modal
                          await Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute(
                              fullscreenDialog: true,
                              builder: (context) => VideoCallScreen(
                                appointmentId: appointment['id'] ??
                                    appointment['appointmentId'] ??
                                    '',
                                patientName:
                                    appointment['patientName'] ?? 'Patient',
                                roomId: appointment['roomId'],
                                isDoctorCalling: true,
                                onCallEnded: () {
                                  print('Returned from video call screen');
                                  // Refresh the pending appointments after call
                                  setState(() {
                                    print(
                                        'Refreshing pending appointments after return');
                                  });
                                },
                              ),
                            ),
                          );
                        } catch (e) {
                          // Close loading dialog if still open
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          }

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error starting video call: $e'),
                              backgroundColor: Colors.red.shade600,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        }
                      }
                    : null,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: appointment["roomId"] != null &&
                                appointment["roomId"].toString().isNotEmpty
                            ? Colors.green.shade100
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        appointment["roomId"] != null &&
                                appointment["roomId"].toString().isNotEmpty
                            ? Icons.video_call
                            : Icons.link_off,
                        color: appointment["roomId"] != null &&
                                appointment["roomId"].toString().isNotEmpty
                            ? Colors.green.shade600
                            : Colors.grey.shade600,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        appointment["roomId"] != null &&
                                appointment["roomId"].toString().isNotEmpty
                            ? "Video Call Room: ${appointment["roomId"]}"
                            : "No video call room generated yet",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: appointment["roomId"] != null &&
                                  appointment["roomId"].toString().isNotEmpty
                              ? Colors.green.shade700
                              : Colors.grey.shade600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (appointment["roomId"] != null &&
                        appointment["roomId"].toString().isNotEmpty)
                      IconButton(
                        onPressed: () {
                          Clipboard.setData(
                              ClipboardData(text: appointment["roomId"]));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                                  const Text('Room ID copied to clipboard'),
                              backgroundColor: Colors.green.shade600,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        icon: Icon(Icons.copy,
                            color: Colors.green.shade600, size: 20),
                        tooltip: 'Copy room ID',
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await _generateWebRTCRoom(appointment);
                },
                icon: const Icon(Icons.video_call, size: 20),
                label: Text(
                  appointment["roomId"] != null &&
                          appointment["roomId"].toString().isNotEmpty
                      ? "Regenerate Room"
                      : "Generate Room",
                  style: const TextStyle(
                    fontSize: 16,
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
    );
  }

  // Helper method to build uploaded ID card
  Widget _buildUploadedIdCard({
    required String title,
    required String subtitle,
    required bool isExpanded,
    required VoidCallback onToggle,
    required Map<String, dynamic> appointment,
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
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
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
                  // ID Type information
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Row(
                      children: [
                        Icon(
                          Icons.badge,
                          size: 18,
                          color: const Color(0xFF0A84FF),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildStyledBulletText(
                            'ID Type: ${appointment["idType"] ?? "Not specified"}',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // ID Image container
                  Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: appointment["idImageUrl"] != null &&
                            appointment["idImageUrl"].toString().isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              appointment["idImageUrl"],
                              fit: BoxFit.contain,
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
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.error_outline,
                                        color: Colors.red.shade400,
                                        size: 48,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Failed to load ID image',
                                        style: TextStyle(
                                          color: Colors.red.shade600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          )
                        : Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.image_not_supported_outlined,
                                  color: Colors.grey.shade400,
                                  size: 48,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No ID image provided',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                  if (appointment["idImageUrl"] != null &&
                      appointment["idImageUrl"].toString().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // Open image in full screen or show in dialog
                          showDialog(
                            context: context,
                            builder: (context) => Dialog(
                              backgroundColor: Colors.black,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AppBar(
                                    backgroundColor: Colors.black,
                                    foregroundColor: Colors.white,
                                    title: const Text('ID Document'),
                                    leading: IconButton(
                                      icon: const Icon(Icons.close),
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                    ),
                                  ),
                                  Expanded(
                                    child: InteractiveViewer(
                                      child: Image.network(
                                        appointment["idImageUrl"],
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF0A84FF)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        icon: const Icon(Icons.zoom_in,
                            color: Color(0xFF0A84FF), size: 16),
                        label: const Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 12.0, vertical: 10),
                          child: Text(
                            'VIEW FULL SIZE',
                            style: TextStyle(color: Color(0xFF0A84FF)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Dialog for rejecting appointments
class _ModernRejectDialog extends StatelessWidget {
  final TextEditingController reasonController;

  const _ModernRejectDialog({required this.reasonController});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.warning_rounded,
                color: Colors.red.shade600,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Reject Appointment',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please provide a reason for rejecting this appointment',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Enter rejection reason...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.red.shade400, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: Colors.grey.shade400),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if (reasonController.text.trim().isNotEmpty) {
                        Navigator.of(context).pop(reasonController.text.trim());
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Reject',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Dialog for editing schedule
class _ScheduleEditDialog extends StatefulWidget {
  final DateTime initialDate;
  final String initialTime;

  const _ScheduleEditDialog({
    required this.initialDate,
    required this.initialTime,
  });

  @override
  State<_ScheduleEditDialog> createState() => _ScheduleEditDialogState();
}

class _ScheduleEditDialogState extends State<_ScheduleEditDialog>
    with TickerProviderStateMixin {
  late DateTime selectedDate;
  late String selectedTime;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  // Start time picker variables
  late int startHour;
  late int startMinute;
  late String startPeriod;

  // End time picker variables
  late int endHour;
  late int endMinute;
  late String endPeriod;

  final FixedExtentScrollController _startHourController =
      FixedExtentScrollController();
  final FixedExtentScrollController _startMinuteController =
      FixedExtentScrollController();
  final FixedExtentScrollController _startPeriodController =
      FixedExtentScrollController();

  final FixedExtentScrollController _endHourController =
      FixedExtentScrollController();
  final FixedExtentScrollController _endMinuteController =
      FixedExtentScrollController();
  final FixedExtentScrollController _endPeriodController =
      FixedExtentScrollController();

  @override
  void initState() {
    super.initState();
    selectedDate = widget.initialDate;
    selectedTime = widget.initialTime;

    // Parse initial time
    _parseInitialTime();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.7,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));

    _animationController.forward();

    // Set initial scroll positions after a delay to ensure widgets are built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startHourController.jumpToItem(startHour - 1);
      _startMinuteController.jumpToItem(startMinute);
      _startPeriodController.jumpToItem(startPeriod == 'AM' ? 0 : 1);
      // Set end time to start time + 30 minutes initially
      _endHourController.jumpToItem(endHour - 1);
      _endMinuteController.jumpToItem(endMinute);
      _endPeriodController.jumpToItem(endPeriod == 'AM' ? 0 : 1);
    });
  }

  void _parseInitialTime() {
    try {
      // Parse time like "09:30 AM"
      final parts = selectedTime.split(' ');
      final timePart = parts[0];
      startPeriod = parts[1];

      final timeComponents = timePart.split(':');
      startHour = int.parse(timeComponents[0]);
      startMinute = int.parse(timeComponents[1]);

      // Calculate end time (add 30 minutes as default)
      endHour = startHour;
      endMinute = startMinute + 30;
      endPeriod = startPeriod;

      // Handle minute overflow
      if (endMinute >= 60) {
        endMinute -= 60;
        endHour += 1;
        // Handle hour overflow and AM/PM change
        if (endPeriod == 'AM' && endHour > 12) {
          endHour = 1;
          endPeriod = 'PM';
        } else if (endPeriod == 'PM' && endHour > 12) {
          endHour = 1;
          endPeriod = 'AM'; // Next day
        }
      }
    } catch (e) {
      // Default values if parsing fails
      startHour = 9;
      startMinute = 0;
      startPeriod = 'AM';
      endHour = 9;
      endMinute = 30;
      endPeriod = 'AM';
    }
  }

  String _formatSelectedTime() {
    final startHourStr = startHour.toString().padLeft(2, '0');
    final startMinuteStr = startMinute.toString().padLeft(2, '0');
    final endHourStr = endHour.toString().padLeft(2, '0');
    final endMinuteStr = endMinute.toString().padLeft(2, '0');
    return '$startHourStr:$startMinuteStr $startPeriod - $endHourStr:$endMinuteStr $endPeriod';
  }

  @override
  void dispose() {
    _animationController.dispose();
    _startHourController.dispose();
    _startMinuteController.dispose();
    _startPeriodController.dispose();
    _endHourController.dispose();
    _endMinuteController.dispose();
    _endPeriodController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: BoxConstraints(
              maxWidth: 400,
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.blue.shade600,
                        Colors.blue.shade700,
                      ],
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
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
                          Icons.schedule_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Edit Schedule',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),

                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Date Selection
                        Text(
                          'Select Date',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: () async {
                            print('Date container tapped!'); // Debug print
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime.now(),
                              lastDate:
                                  DateTime.now().add(const Duration(days: 365)),
                              initialEntryMode: DatePickerEntryMode.calendarOnly,
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: ColorScheme.light(
                                      primary: Colors.blue.shade600,
                                      onPrimary: Colors.white,
                                      surface: Colors.white,
                                      onSurface: Colors.grey.shade800,
                                    ),
                                    dialogTheme: const DialogThemeData(
                                        backgroundColor: Colors.white),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null && picked != selectedDate) {
                              setState(() {
                                selectedDate = picked;
                              });
                              print('Date updated to: $picked'); // Debug print
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.blue.shade50,
                                  Colors.blue.shade100
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.blue.shade200, width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.08),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.blue.shade400,
                                        Colors.blue.shade600
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.blue.withOpacity(0.25),
                                        blurRadius: 3,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.calendar_today_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _formatDate(selectedDate),
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.blue.shade800,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Tap to change date',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.blue.shade600,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  color: Colors.blue.shade400,
                                  size: 14,
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Time Selection
                        Text(
                          'Select Time Range',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 10),

                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            children: [
                              // Start Time Section
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Start Time',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      height: 120,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: Colors.grey.shade300),
                                      ),
                                      child: Row(
                                        children: [
                                          // Start Hour picker
                                          Expanded(
                                            child: Column(
                                              children: [
                                                Container(
                                                  padding:
                                                      const EdgeInsets.all(6),
                                                  child: Text(
                                                    'Hour',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color:
                                                          Colors.grey.shade600,
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  child: CupertinoPicker(
                                                    scrollController:
                                                        _startHourController,
                                                    itemExtent: 28,
                                                    onSelectedItemChanged:
                                                        (index) {
                                                      setState(() {
                                                        startHour = index + 1;
                                                      });
                                                    },
                                                    children: List.generate(12,
                                                        (index) {
                                                      return Center(
                                                        child: Text(
                                                          '${index + 1}',
                                                          style: TextStyle(
                                                            fontSize: 16,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: Colors
                                                                .grey.shade800,
                                                          ),
                                                        ),
                                                      );
                                                    }),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Start Minute picker
                                          Expanded(
                                            child: Column(
                                              children: [
                                                Container(
                                                  padding:
                                                      const EdgeInsets.all(6),
                                                  child: Text(
                                                    'Min',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color:
                                                          Colors.grey.shade600,
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  child: CupertinoPicker(
                                                    scrollController:
                                                        _startMinuteController,
                                                    itemExtent: 28,
                                                    onSelectedItemChanged:
                                                        (index) {
                                                      setState(() {
                                                        startMinute = index;
                                                      });
                                                    },
                                                    children: List.generate(60,
                                                        (index) {
                                                      return Center(
                                                        child: Text(
                                                          index
                                                              .toString()
                                                              .padLeft(2, '0'),
                                                          style: TextStyle(
                                                            fontSize: 16,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: Colors
                                                                .grey.shade800,
                                                          ),
                                                        ),
                                                      );
                                                    }),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Start AM/PM picker
                                          Expanded(
                                            child: Column(
                                              children: [
                                                Container(
                                                  padding:
                                                      const EdgeInsets.all(6),
                                                  child: Text(
                                                    'Period',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color:
                                                          Colors.grey.shade600,
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  child: CupertinoPicker(
                                                    scrollController:
                                                        _startPeriodController,
                                                    itemExtent: 28,
                                                    onSelectedItemChanged:
                                                        (index) {
                                                      setState(() {
                                                        startPeriod = index == 0
                                                            ? 'AM'
                                                            : 'PM';
                                                      });
                                                    },
                                                    children: ['AM', 'PM']
                                                        .map((period) {
                                                      return Center(
                                                        child: Text(
                                                          period,
                                                          style: TextStyle(
                                                            fontSize: 16,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: Colors
                                                                .grey.shade800,
                                                          ),
                                                        ),
                                                      );
                                                    }).toList(),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Divider
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: Divider(
                                  height: 1,
                                  color: Colors.grey.shade300,
                                ),
                              ),

                              // End Time Section
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'End Time',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      height: 120,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: Colors.grey.shade300),
                                      ),
                                      child: Row(
                                        children: [
                                          // End Hour picker
                                          Expanded(
                                            child: Column(
                                              children: [
                                                Container(
                                                  padding:
                                                      const EdgeInsets.all(6),
                                                  child: Text(
                                                    'Hour',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color:
                                                          Colors.grey.shade600,
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  child: CupertinoPicker(
                                                    scrollController:
                                                        _endHourController,
                                                    itemExtent: 28,
                                                    onSelectedItemChanged:
                                                        (index) {
                                                      setState(() {
                                                        endHour = index + 1;
                                                      });
                                                    },
                                                    children: List.generate(12,
                                                        (index) {
                                                      return Center(
                                                        child: Text(
                                                          '${index + 1}',
                                                          style: TextStyle(
                                                            fontSize: 16,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: Colors
                                                                .grey.shade800,
                                                          ),
                                                        ),
                                                      );
                                                    }),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          // End Minute picker
                                          Expanded(
                                            child: Column(
                                              children: [
                                                Container(
                                                  padding:
                                                      const EdgeInsets.all(6),
                                                  child: Text(
                                                    'Min',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color:
                                                          Colors.grey.shade600,
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  child: CupertinoPicker(
                                                    scrollController:
                                                        _endMinuteController,
                                                    itemExtent: 28,
                                                    onSelectedItemChanged:
                                                        (index) {
                                                      setState(() {
                                                        endMinute = index;
                                                      });
                                                    },
                                                    children: List.generate(60,
                                                        (index) {
                                                      return Center(
                                                        child: Text(
                                                          index
                                                              .toString()
                                                              .padLeft(2, '0'),
                                                          style: TextStyle(
                                                            fontSize: 16,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: Colors
                                                                .grey.shade800,
                                                          ),
                                                        ),
                                                      );
                                                    }),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          // End AM/PM picker
                                          Expanded(
                                            child: Column(
                                              children: [
                                                Container(
                                                  padding:
                                                      const EdgeInsets.all(6),
                                                  child: Text(
                                                    'Period',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color:
                                                          Colors.grey.shade600,
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  child: CupertinoPicker(
                                                    scrollController:
                                                        _endPeriodController,
                                                    itemExtent: 28,
                                                    onSelectedItemChanged:
                                                        (index) {
                                                      setState(() {
                                                        endPeriod = index == 0
                                                            ? 'AM'
                                                            : 'PM';
                                                      });
                                                    },
                                                    children: ['AM', 'PM']
                                                        .map((period) {
                                                      return Center(
                                                        child: Text(
                                                          period,
                                                          style: TextStyle(
                                                            fontSize: 16,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: Colors
                                                                .grey.shade800,
                                                          ),
                                                        ),
                                                      );
                                                    }).toList(),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Actions
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(24),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => Navigator.of(context).pop(),
                              child: Center(
                                child: Text(
                                  'Cancel',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: Container(
                          height: 42,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.blue.shade500,
                                Colors.blue.shade600
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.3),
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
                                Navigator.of(context).pop({
                                  'date': selectedDate,
                                  'time': _formatSelectedTime(),
                                });
                              },
                              child: const Center(
                                child: Text(
                                  'Update Schedule',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
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
        ),
      ),
    );
  }
}
