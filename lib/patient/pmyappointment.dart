import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:printing/printing.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import '../services/chat_service.dart';
import '../services/webrtc_service.dart';
import '../chat_screens/chat_screen.dart';
import '../screens/video_call_screen.dart';

class PMyAppointmentScreen extends StatefulWidget {
  const PMyAppointmentScreen({super.key});

  @override
  State<PMyAppointmentScreen> createState() => _PMyAppointmentScreenState();
}

class _PMyAppointmentScreenState extends State<PMyAppointmentScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;

  String? _currentPatientId;

  String _selectedMonth = '';
  int _selectedYear = DateTime.now().year;

  final List<String> _months = [
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

  final List<int> _years =
      List.generate(10, (index) => DateTime.now().year - 5 + index);

  List<DateTime> _appointmentDates = [];

  // Filter for appointments
  String _selectedFilter = 'All'; // Updated filter options

  // Map to track expansion state of schedule cards by appointment ID
  Map<String, bool> _scheduleCardExpansionState = {};

  // Available filter options
  final List<Map<String, dynamic>> _filterOptions = [
    {
      'key': 'All',
      'label': 'All',
      'icon': Icons.list,
      'color': Colors.blue,
    },
    {
      'key': 'Treatment Completed',
      'label': 'Treatment\nCompleted',
      'icon': Icons.verified,
      'color': Colors.purple,
    },
    {
      'key': 'History',
      'label': 'History',
      'icon': Icons.history,
      'color': Colors.grey,
    },
  ];

  @override
  void initState() {
    super.initState();
    _selectedMonth = _months[DateTime.now().month - 1];
    _getCurrentPatientId();
  }

  // Helper method to get status color based on appointment status
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.redAccent;
      case 'completed':
        return Colors.green;
      case 'consultation_finished':
        return Colors.blue;
      case 'treatment_completed':
        return Colors.purple;
      case 'with_prescription':
        return Colors.red.shade600;
      case 'with_certificate':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  // Helper method to get status display text (Simplified for 30-50 year olds)
  String _getStatusDisplayText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Waiting';
      case 'approved':
        return 'Ready';
      case 'rejected':
        return 'Not Approved';
      case 'completed':
        return 'Done';
      case 'consultation_finished':
        return 'Consultation Done';
      case 'treatment_completed':
        return 'Treatment Done';
      case 'with_prescription':
        return 'Medicine Ready';
      case 'with_certificate':
        return 'Certificate Ready';
      default:
        return status.toUpperCase();
    }
  }

  // Helper method to format appointment date/time
  String _formatAppointmentDateTime(Map<String, dynamic> appointment) {
    String status =
        appointment['status']?.toString().toLowerCase() ?? 'unknown';
    DateTime? displayDate;
    String? displayTime;

    // For approved appointments, use the appointment schedule
    if (status == 'approved') {
      try {
        final dynamic appointmentDate = appointment["date"] ??
            appointment["appointmentDate"] ??
            appointment["appointment_date"];
        if (appointmentDate is Timestamp) {
          displayDate = appointmentDate.toDate();
        } else if (appointmentDate is DateTime) {
          displayDate = appointmentDate;
        } else if (appointmentDate is String) {
          displayDate = DateTime.parse(appointmentDate);
        }
        displayTime = appointment["appointmentTime"] ??
            appointment["appointment_time"] ??
            appointment["time"];
      } catch (e) {
        debugPrint('Error parsing appointment date: $e');
      }
    } else {
      // For other statuses, use the timestamp when the status was updated
      var approvedAt = appointment['approvedAt'];
      var rejectedAt = appointment['rejectedAt'];
      var updatedAt = appointment['updatedAt'];
      var completedAt = appointment['completedAt'];
      var timestamp = approvedAt ?? rejectedAt ?? updatedAt ?? completedAt;

      if (timestamp is Timestamp) {
        displayDate = timestamp.toDate();
        // Format time in AM/PM format
        int hour = displayDate.hour;
        int minute = displayDate.minute;
        String period = hour >= 12 ? 'PM' : 'AM';
        if (hour > 12) hour -= 12;
        if (hour == 0) hour = 12;
        displayTime =
            "${hour.toString()}:${minute.toString().padLeft(2, '0')} $period";
      } else if (timestamp is String) {
        try {
          displayDate = DateTime.parse(timestamp);
          int hour = displayDate.hour;
          int minute = displayDate.minute;
          String period = hour >= 12 ? 'PM' : 'AM';
          if (hour > 12) hour -= 12;
          if (hour == 0) hour = 12;
          displayTime =
              "${hour.toString()}:${minute.toString().padLeft(2, '0')} $period";
        } catch (e) {
          displayDate = null;
          displayTime = null;
        }
      }
    }

    return displayDate != null
        ? "${displayDate.day}/${displayDate.month}/${displayDate.year}${displayTime != null ? " at $displayTime" : ""}"
        : "Date not set";
  }

  Future<void> _getCurrentPatientId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      debugPrint('Current user UID: ${user.uid}');
      setState(() {
        _currentPatientId = user.uid;
      });
      await _loadAppointmentDates();
    } else {
      debugPrint('No user logged in');
    }
  }

  Future<void> _openChatWithDoctor(Map<String, dynamic> appointment) async {
    try {
      final ChatService chatService = ChatService();
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('No authenticated user found');
      }

      final doctorId = appointment['doctorId'] ?? appointment['doctor_id'];
      String doctorName = 'Doctor';

      if (doctorId == null) {
        throw Exception('Doctor ID not found');
      }

      // Get doctor's information
      try {
        final doctorDoc = await FirebaseFirestore.instance
            .collection('doctors')
            .doc(doctorId)
            .get();

        if (doctorDoc.exists) {
          final doctorData = doctorDoc.data() as Map<String, dynamic>;
          doctorName =
              "Dr. ${doctorData["fullName"] ?? appointment["doctorName"] ?? "Doctor"}";
        } else if (appointment["doctorName"] != null) {
          doctorName = "Dr. ${appointment["doctorName"]}";
        }
      } catch (e) {
        debugPrint('Error fetching doctor details: $e');
        // Use fallback name if doctor details can't be fetched
        if (appointment["doctorName"] != null) {
          doctorName = "Dr. ${appointment["doctorName"]}";
        }
      }

      // Create or update user docs for chat - ensure both users exist in users collection
      await chatService.createUserDoc(
        userId: currentUser.uid,
        name: currentUser.displayName ?? 'Patient',
        role: 'patient',
      );

      await chatService.createUserDoc(
        userId: doctorId,
        name: doctorName,
        role: 'doctor',
      );

      // Navigate to chat screen
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              currentUserId: currentUser.uid,
              otherUserId: doctorId,
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

  Future<void> _loadAppointmentDates() async {
    if (_currentPatientId == null) return;

    debugPrint('Loading appointment dates for patient: $_currentPatientId');

    try {
      // Query pending appointments by patientUid
      final pendingQuery = await FirebaseFirestore.instance
          .collection('pending_patient_data')
          .where('patientUid', isEqualTo: _currentPatientId)
          .get();

      debugPrint('Found ${pendingQuery.docs.length} pending appointments');

      // Query approved appointments by patientUid
      final approvedQuery = await FirebaseFirestore.instance
          .collection('approved_appointments')
          .where('patientUid', isEqualTo: _currentPatientId)
          .get();

      debugPrint('Found ${approvedQuery.docs.length} approved appointments');

      final Set<DateTime> dates = {};

      // Process pending appointments
      for (var doc in pendingQuery.docs) {
        final data = doc.data();
        debugPrint(
            'Processing pending appointment: ${data['appointment_date']}');

        if (data['appointment_date'] != null) {
          try {
            DateTime date;
            if (data['appointment_date'] is Timestamp) {
              date = (data['appointment_date'] as Timestamp).toDate();
            } else {
              date = DateTime.parse(data['appointment_date'].toString());
            }
            dates.add(DateTime(date.year, date.month, date.day));
            debugPrint('Added pending date: $date');
          } catch (e) {
            debugPrint('Error parsing pending date: $e');
          }
        }
      }

      // Process approved appointments
      for (var doc in approvedQuery.docs) {
        final data = doc.data();
        debugPrint(
            'Processing approved appointment: ${data['appointment_date']}');

        if (data['appointment_date'] != null) {
          try {
            DateTime date;
            if (data['appointment_date'] is Timestamp) {
              date = (data['appointment_date'] as Timestamp).toDate();
            } else {
              date = DateTime.parse(data['appointment_date'].toString());
            }
            dates.add(DateTime(date.year, date.month, date.day));
            debugPrint('Added approved date: $date');
          } catch (e) {
            debugPrint('Error parsing approved date: $e');
          }
        }
      }

      setState(() {
        _appointmentDates = dates.toList();
      });

      debugPrint('Total appointment dates loaded: ${_appointmentDates.length}');
    } catch (e) {
      debugPrint('Error loading appointment dates: $e');
    }
  }

  List<DateTime> _getEventsForDay(DateTime day) {
    return _appointmentDates.where((date) => isSameDay(date, day)).toList();
  }

  Stream<List<Map<String, dynamic>>> _getCombinedAppointmentsStream() {
    if (_currentPatientId == null) {
      return Stream.value([]);
    }

    return FirebaseFirestore.instance
        .collection('pending_patient_data')
        .where('patientUid', isEqualTo: _currentPatientId)
        .snapshots()
        .asyncMap((pendingSnapshot) async {
      List<Map<String, dynamic>> allAppointments = [];

      // Add pending appointments
      for (var doc in pendingSnapshot.docs) {
        final data = doc.data();
        data['status'] = 'pending';
        data['appointmentId'] = doc.id; // Use appointmentId for consistency
        data['appointmentSource'] = 'pending';
        allAppointments.add(data);
      }

      // Get approved appointments
      final approvedSnapshot = await FirebaseFirestore.instance
          .collection('approved_appointments')
          .where('patientUid', isEqualTo: _currentPatientId)
          .get();

      for (var doc in approvedSnapshot.docs) {
        final data = doc.data();
        data['status'] = 'approved';
        data['appointmentId'] = doc.id; // Use appointmentId for consistency
        data['appointmentSource'] = 'approved';
        allAppointments.add(data);
      }

      // Get completed appointments (post-consultation)
      final completedSnapshot = await FirebaseFirestore.instance
          .collection('completed_appointments')
          .where('patientUid', isEqualTo: _currentPatientId)
          .get();

      for (var doc in completedSnapshot.docs) {
        var data = doc.data();

        // Check if certificate has been sent to determine status
        bool certificateSent = false;
        try {
          final notificationSnapshot = await FirebaseFirestore.instance
              .collection('patient_notifications')
              .where('patientUid', isEqualTo: _currentPatientId)
              .where('appointmentId', isEqualTo: data['appointmentId'])
              .where('type', isEqualTo: 'certificate_available')
              .get();

          certificateSent = notificationSnapshot.docs.isNotEmpty;
        } catch (e) {
          debugPrint('Error checking certificate status: $e');
        }

        data['status'] =
            certificateSent ? 'treatment_completed' : 'consultation_finished';
        data['appointmentId'] = data['appointmentId'] ??
            doc.id; // Preserve existing appointmentId or use doc ID
        data['appointmentSource'] = 'completed';
        data['certificateSent'] = certificateSent;

        // Add data enrichment for completed appointments
        data = await _enrichAppointmentData(data);
        allAppointments.add(data);
      }

      // Get appointments from appointment_history collection (fully completed treatments)
      final historySnapshot = await FirebaseFirestore.instance
          .collection('appointment_history')
          .where('patientUid', isEqualTo: _currentPatientId)
          .get();

      for (var doc in historySnapshot.docs) {
        var data = doc.data();
        data['appointmentId'] = doc.id;
        data['appointmentSource'] = 'appointment_history';
        data['status'] =
            'treatment_completed'; // History appointments are fully completed

        // Add data enrichment for history appointments
        data = await _enrichAppointmentData(data);
        allAppointments.add(data);
      }

      // Get rejected appointments
      final rejectedSnapshot = await FirebaseFirestore.instance
          .collection('rejected_appointments')
          .where('patientUid', isEqualTo: _currentPatientId)
          .get();

      for (var doc in rejectedSnapshot.docs) {
        final data = doc.data();
        data['status'] = 'rejected';
        data['appointmentId'] = doc.id; // Use appointmentId for consistency
        data['appointmentSource'] = 'rejected';
        allAppointments.add(data);
      }

      // Sort by most relevant timestamp (prioritize treatment completed appointments)
      allAppointments.sort((a, b) {
        final timestampA = a['treatmentCompletedAt'] ??
            a['movedToHistoryAt'] ??
            a['completedAt'] ??
            a['approvedAt'] ??
            a['rejectedAt'] ??
            a['createdAt'];
        final timestampB = b['treatmentCompletedAt'] ??
            b['movedToHistoryAt'] ??
            b['completedAt'] ??
            b['approvedAt'] ??
            b['rejectedAt'] ??
            b['createdAt'];

        if (timestampA == null && timestampB == null) return 0;
        if (timestampA == null) return 1;
        if (timestampB == null) return -1;

        // Sort descending (newest first)
        return timestampB.compareTo(timestampA);
      });

      return allAppointments;
    });
  }

  // Data enrichment method to fetch prescription and certificate data
  Future<Map<String, dynamic>> _enrichAppointmentData(
      Map<String, dynamic> appointment) async {
    // Get prescription data if available
    Map<String, dynamic>? prescriptionData;
    if (appointment['prescriptionData'] != null) {
      // Data already available
      prescriptionData = appointment['prescriptionData'];
    } else if (appointment['appointmentId'] != null) {
      // Fetch prescription data from prescriptions collection
      try {
        final prescriptionSnapshot = await FirebaseFirestore.instance
            .collection('prescriptions')
            .where('appointmentId', isEqualTo: appointment['appointmentId'])
            .limit(1)
            .get();

        if (prescriptionSnapshot.docs.isNotEmpty) {
          prescriptionData = prescriptionSnapshot.docs.first.data();
        }
      } catch (e) {
        debugPrint('Error fetching prescription data: $e');
      }
    }

    // Get certificate data if available
    Map<String, dynamic>? certificateData;
    if (appointment['certificateData'] != null) {
      // Data already available
      certificateData = appointment['certificateData'];
    } else if (appointment['appointmentId'] != null) {
      // Fetch certificate data from certificates collection
      try {
        final certificateSnapshot = await FirebaseFirestore.instance
            .collection('certificates')
            .where('appointmentId', isEqualTo: appointment['appointmentId'])
            .limit(1)
            .get();

        if (certificateSnapshot.docs.isNotEmpty) {
          certificateData = certificateSnapshot.docs.first.data();
        }
      } catch (e) {
        debugPrint('Error fetching certificate data: $e');
      }
    }

    // Return enriched appointment data
    debugPrint(
        'Enrichment complete for appointment ${appointment['appointmentId']}:');
    debugPrint('  - Has prescription data: ${prescriptionData != null}');
    debugPrint('  - Has certificate data: ${certificateData != null}');
    if (certificateData != null) {
      debugPrint('  - Certificate pdfUrl: ${certificateData['pdfUrl']}');
      debugPrint('  - Certificate pdfPath: ${certificateData['pdfPath']}');
    }

    return {
      ...appointment,
      'prescriptionData': prescriptionData,
      'certificateData': certificateData,
    };
  }

  String _formatDate(dynamic dateValue) {
    try {
      DateTime date;
      if (dateValue is Timestamp) {
        date = dateValue.toDate();
      } else if (dateValue is String) {
        date = DateTime.parse(dateValue);
      } else if (dateValue is DateTime) {
        date = dateValue;
      } else {
        return 'Invalid date';
      }
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      debugPrint('Error formatting date: $e');
      return 'Invalid date';
    }
  }

  Future<void> _deleteRejectedAppointment(
      Map<String, dynamic> appointment) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Rejected Appointment'),
          content: const Text(
              'Are you sure you want to delete this rejected appointment? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        // Delete from rejected_appointments collection
        await FirebaseFirestore.instance
            .collection('rejected_appointments')
            .doc(appointment['appointmentId'])
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Rejected appointment deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        debugPrint('Error deleting rejected appointment: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting appointment: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showAppointmentDetails(Map<String, dynamic> appointment) async {
    // Use enriched data from appointment if available, otherwise fetch manually
    Map<String, dynamic>? prescriptionData = appointment['prescriptionData'];
    Map<String, dynamic>? certificateData = appointment['certificateData'];
    Map<String, dynamic>? doctorData;

    // If data is not available in the appointment object, fetch it manually
    if (prescriptionData == null &&
        appointment['appointmentSource'] == 'completed') {
      // Fetch prescription data
      try {
        final appointmentId = appointment['appointmentId'];
        debugPrint('Fetching prescription for appointmentId: $appointmentId');

        final prescriptionSnapshot = await FirebaseFirestore.instance
            .collection('prescriptions')
            .where('appointmentId', isEqualTo: appointmentId)
            .get();

        debugPrint(
            'Prescription query results: ${prescriptionSnapshot.docs.length} documents found');

        if (prescriptionSnapshot.docs.isNotEmpty) {
          prescriptionData = prescriptionSnapshot.docs.first.data();
          debugPrint(
              'Prescription data found: ${prescriptionData['prescriptionDetails'] != null ? 'Has prescriptionDetails' : 'No prescriptionDetails'}');
          debugPrint('PDF Path: ${prescriptionData['pdfPath']}');
          debugPrint('PDF URL: ${prescriptionData['pdfUrl']}');
        } else {
          debugPrint(
              'No prescription documents found for appointmentId: $appointmentId');
        }
      } catch (e) {
        debugPrint('Error fetching prescription: $e');
      }

      // Fetch certificate data if not available
      if (certificateData == null) {
        try {
          final appointmentId = appointment['appointmentId'];
          debugPrint('Fetching certificate for appointmentId: $appointmentId');

          final certificateSnapshot = await FirebaseFirestore.instance
              .collection('certificates')
              .where('appointmentId', isEqualTo: appointmentId)
              .get();

          if (certificateSnapshot.docs.isNotEmpty) {
            certificateData = certificateSnapshot.docs.first.data();
            debugPrint('Certificate data found');
          } else {
            debugPrint(
                'No certificate documents found for appointmentId: $appointmentId');
          }
        } catch (e) {
          debugPrint('Error fetching certificate: $e');
        }
      }

      // Fetch doctor data
      try {
        if (appointment['doctorId'] != null) {
          final doctorDoc = await FirebaseFirestore.instance
              .collection('doctors')
              .doc(appointment['doctorId'])
              .get();

          if (doctorDoc.exists) {
            doctorData = doctorDoc.data();
            debugPrint(
                'Doctor data fields: ${doctorData != null ? doctorData.keys.toList() : 'null'}');
            debugPrint(
                'Doctor fullName: ${doctorData != null ? doctorData['fullName'] : 'null'}');
            debugPrint(
                'Doctor firstName: ${doctorData != null ? doctorData['firstName'] : 'null'}');
            debugPrint(
                'Doctor lastName: ${doctorData != null ? doctorData['lastName'] : 'null'}');
            debugPrint(
                'Doctor doctorName: ${doctorData != null ? doctorData['doctorName'] : 'null'}');
          }
        }
      } catch (e) {
        debugPrint('Error fetching doctor data: $e');
      }
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                height: 5,
                width: 50,
                margin: const EdgeInsets.only(top: 12, bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(12),
                ),
              ),

              // Expandable Content with Header
              Flexible(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Appointment Details Section Header (No space above)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade600,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(24)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.medical_information,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                "Appointment Details",
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            IconButton(
                              icon:
                                  const Icon(Icons.close, color: Colors.white),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ),

                      // Scrollable Content
                      Expanded(
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(24),
                              bottomRight: Radius.circular(24),
                            ),
                          ),
                          child: SingleChildScrollView(
                            controller: controller,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Status-based content rendering
                                  _buildStatusBasedContent(
                                      appointment,
                                      prescriptionData,
                                      certificateData,
                                      doctorData),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Status Card - shows above doctor information (Simplified for 30-50 year olds)
  Widget _buildStatusCard(Map<String, dynamic> appointment) {
    String status =
        appointment['status']?.toString().toLowerCase() ?? 'unknown';
    Color statusColor;
    String statusTitle;
    String statusDescription;
    IconData statusIcon;

    switch (status) {
      case 'pending':
        statusColor = Colors.amber.shade600;
        statusTitle = 'Waiting for Doctor';
        statusDescription = 'Your appointment is being reviewed';
        statusIcon = Icons.schedule;
        break;
      case 'approved':
        statusColor = Colors.green.shade600;
        statusTitle = 'Ready for Consultation';
        statusDescription = 'You can now join your video call';
        statusIcon = Icons.videocam;
        break;
      case 'consultation_finished':
        statusColor = Colors.blue.shade600;
        statusTitle = 'Consultation Done';
        statusDescription = 'Your medicine prescription is ready';
        statusIcon = Icons.medical_services;
        break;
      case 'treatment_completed':
        statusColor = Colors.purple.shade600;
        statusTitle = 'Treatment Finished';
        statusDescription = 'All done! Your treatment is complete';
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = Colors.red.shade600;
        statusTitle = 'Appointment Not Approved';
        statusDescription = 'Please book another appointment';
        statusIcon = Icons.info;
        break;
      default:
        statusColor = Colors.grey.shade600;
        statusTitle = 'Status Unknown';
        statusDescription = 'Please check back later';
        statusIcon = Icons.help_outline;
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              statusIcon,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusTitle,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  statusDescription,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to build status-based content
  Widget _buildStatusBasedContent(
      Map<String, dynamic> appointment,
      Map<String, dynamic>? prescriptionData,
      Map<String, dynamic>? certificateData,
      Map<String, dynamic>? doctorData) {
    String status =
        appointment['status']?.toString().toLowerCase() ?? 'unknown';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status card appears above doctor information for all statuses
        _buildStatusCard(appointment),
        const SizedBox(height: 12),

        if (status == 'pending') ...[
          // For pending: Show Doctor Info and Schedule only
          _buildPatientInfoCard(appointment), // Now shows doctor info
          const SizedBox(height: 12),
          _buildScheduleCard(appointment),
          const SizedBox(height: 12),
          _buildPendingStatusCard(),
        ] else if (status == 'approved') ...[
          // For approved: Show basic info and meeting link
          _buildPatientInfoCard(appointment), // Now shows doctor info
          const SizedBox(height: 12),
          _buildScheduleCard(appointment),
          const SizedBox(height: 12),
          _buildVideoCallCard(appointment),
        ] else if (status == 'with_prescription' ||
            status == 'consultation_finished') ...[
          // For with prescription: Show prescription info
          _buildPatientInfoCard(appointment), // Now shows doctor info
          const SizedBox(height: 12),
          _buildScheduleCard(appointment),
          const SizedBox(height: 12),
          _buildPrescriptionCard(appointment, prescriptionData),
        ] else if (status == 'with_certificate' ||
            status == 'treatment_completed' ||
            status == 'completed') ...[
          // For with certificate: Show full timeline
          _buildPatientInfoCard(appointment), // Now shows doctor info
          const SizedBox(height: 12),
          _buildScheduleCard(appointment),
          const SizedBox(height: 12),
          _buildPrescriptionCard(appointment, prescriptionData),
          const SizedBox(height: 12),
          _buildCertificateCard(appointment, certificateData),
        ] else if (status == 'rejected') ...[
          // For rejected: Show rejection information
          _buildPatientInfoCard(appointment), // Now shows doctor info
          const SizedBox(height: 12),
          _buildScheduleCard(appointment),
          const SizedBox(height: 12),
          _buildRejectionCard(appointment),
        ] else ...[
          // Default: Show basic info
          _buildPatientInfoCard(appointment), // Now shows doctor info
          const SizedBox(height: 12),
          _buildScheduleCard(appointment),
        ],

        // Timeline card appears for all statuses except rejected
        if (status != 'rejected') ...[
          const SizedBox(height: 16),
          _buildTimelineCard(appointment),
        ],
      ],
    );
  }

  // Doctor Information Card (replacing Patient Information)
  Widget _buildPatientInfoCard(Map<String, dynamic> appointment) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('doctors')
          .doc(appointment["doctorId"] ?? appointment["doctor_id"])
          .get(),
      builder: (context, snapshot) {
        String doctorName = "Dr. Not assigned";
        String clinicAddress = "No clinic address available";
        String doctorId =
            appointment["doctorId"] ?? appointment["doctor_id"] ?? "";

        if (snapshot.hasData && snapshot.data!.exists) {
          final doctorData = snapshot.data!.data() as Map<String, dynamic>;
          doctorName =
              "Dr. ${doctorData["fullName"] ?? appointment["doctorName"] ?? "Not assigned"}";

          if (doctorData["affiliations"] != null &&
              (doctorData["affiliations"] as List).isNotEmpty) {
            clinicAddress =
                (doctorData["affiliations"][0]["address"] ?? "No address")
                    .toString();
          }
        } else if (appointment["doctorName"] != null) {
          doctorName = "Dr. ${appointment["doctorName"]}";
        }

        return Card(
          elevation: 2,
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Container(
            padding: const EdgeInsets.all(16),
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
                      const Text(
                        "Doctor Information",
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Your assigned healthcare provider",
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      _buildBoldInfoRow(
                          Icons.person, 'Doctor Name:', doctorName),
                      _buildBoldInfoRow(
                          Icons.location_on, 'Clinic:', clinicAddress),
                      const SizedBox(height: 12),
                      // Message Doctor Button - Only show if not pending and doctor ID exists
                      if (doctorId.isNotEmpty &&
                          appointment['status']?.toString().toLowerCase() !=
                              'pending')
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _openChatWithDoctor(appointment),
                            icon: const Icon(Icons.message,
                                color: Color(0xFF0A84FF), size: 16),
                            label: const Text(
                              'MESSAGE DOCTOR',
                              style: TextStyle(
                                color: Color(0xFF0A84FF),
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              side: const BorderSide(
                                  color: Color(0xFF0A84FF), width: 1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
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

  // Schedule Card
  Widget _buildScheduleCard(Map<String, dynamic> appointment) {
    String status =
        appointment['status']?.toString().toLowerCase() ?? 'unknown';
    String appointmentId = appointment['appointmentId'] ??
        appointment['appointmentId'] ??
        DateTime.now().millisecondsSinceEpoch.toString();

    // Check if this appointment should have a collapsible schedule card
    bool shouldBeCollapsible = status == 'consultation_finished' ||
        status == 'treatment_completed' ||
        status == 'completed';

    // Initialize expansion state if not exists
    if (!_scheduleCardExpansionState.containsKey(appointmentId)) {
      _scheduleCardExpansionState[appointmentId] =
          false; // Start collapsed for completed statuses
    }

    if (shouldBeCollapsible) {
      return Card(
        elevation: 2,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: ExpansionTile(
          leading: Container(
            width: 6,
            height: 40,
            decoration: const BoxDecoration(
              color: Color(0xFF0A84FF),
              borderRadius: BorderRadius.all(Radius.circular(3)),
            ),
          ),
          title: const Text(
            "Appointment Schedule",
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          subtitle: Text(
            "Scheduled appointment details",
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          initiallyExpanded:
              _scheduleCardExpansionState[appointmentId] ?? false,
          onExpansionChanged: (expanded) {
            setState(() {
              _scheduleCardExpansionState[appointmentId] = expanded;
            });
          },
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  _buildBoldInfoRow(
                      Icons.calendar_today,
                      'Date:',
                      _formatDate(appointment['date'] ??
                          appointment['appointmentDate'] ??
                          appointment['appointment_date'])),
                  _buildBoldInfoRow(
                      Icons.access_time,
                      'Time:',
                      appointment["appointmentTime"] ??
                          appointment["appointment_time"] ??
                          appointment["time"] ??
                          "No time set"),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      // Return regular card for non-completed appointments
      return Card(
        elevation: 2,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Container(
          padding: const EdgeInsets.all(16),
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
                    const Text(
                      "Appointment Schedule",
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Scheduled appointment details",
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    _buildBoldInfoRow(
                        Icons.calendar_today,
                        'Date:',
                        _formatDate(appointment['date'] ??
                            appointment['appointmentDate'] ??
                            appointment['appointment_date'])),
                    _buildBoldInfoRow(
                        Icons.access_time,
                        'Time:',
                        appointment["appointmentTime"] ??
                            appointment["appointment_time"] ??
                            appointment["time"] ??
                            "No time set"),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  // Pending Status Card
  Widget _buildPendingStatusCard() {
    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 40,
              decoration: const BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.all(Radius.circular(3)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Status",
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Meeting availability information",
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(Icons.schedule,
                      'Meeting will be available once approved'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Video Call Card for WebRTC
  Widget _buildVideoCallCard(Map<String, dynamic> appointment) {
    final roomId = appointment['roomId'];

    if (roomId == null || roomId.toString().isEmpty) {
      return Card(
        elevation: 2,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 40,
                decoration: const BoxDecoration(
                  color: Colors.grey,
                  borderRadius: BorderRadius.all(Radius.circular(3)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Video Call",
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Video call room not available yet",
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 40,
              decoration: const BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.all(Radius.circular(3)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Video Call",
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Join your online consultation",
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          print('🎥 Join Video Call button pressed (Patient)');

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

                          // Small delay for patient to prevent race condition with doctor
                          await Future.delayed(Duration(milliseconds: 500));

                          // Check permissions before joining video call
                          print(
                              '🔒 Requesting camera and microphone permissions (Patient)...');
                          final webrtcService = WebRTCService();
                          bool hasPermissions =
                              await webrtcService.requestPermissions();
                          print(
                              '🔒 Permission result (Patient): $hasPermissions');

                          // Close loading dialog
                          Navigator.pop(context);

                          if (!hasPermissions) {
                            print(
                                '❌ Permissions not granted (Patient), showing error message');
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
                                  onPressed: () async {
                                    await openAppSettings();
                                  },
                                ),
                              ),
                            );
                            return;
                          }

                          // Navigate to video call screen with fullscreen modal
                          Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute(
                              fullscreenDialog: true,
                              builder: (context) => VideoCallScreen(
                                appointmentId:
                                    appointment['appointmentId'] ?? '',
                                patientName:
                                    appointment['patientName'] ?? 'Patient',
                                roomId: appointment['roomId'],
                                isDoctorCalling: false,
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
                      },
                      icon: const Icon(Icons.video_call),
                      label: const Text('Join Video Call'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
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
  }

  // Prescription Card
  Widget _buildPrescriptionCard(Map<String, dynamic> appointment,
      Map<String, dynamic>? prescriptionData) {
    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.red.shade600,
                borderRadius: BorderRadius.all(Radius.circular(3)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Electronic Prescription",
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    prescriptionData != null
                        ? "Prescription available"
                        : "No prescription data",
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  if (prescriptionData != null) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _viewPrescriptionPdf(prescriptionData),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.red.shade600),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: Icon(Icons.visibility,
                            color: Colors.red.shade600, size: 16),
                        label: Text(
                          'View Prescription PDF',
                          style: TextStyle(color: Colors.red.shade600),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Certificate Card
  Widget _buildCertificateCard(Map<String, dynamic> appointment,
      [Map<String, dynamic>? certificateData]) {
    // Use provided certificate data if available, otherwise fall back to StreamBuilder
    if (certificateData != null) {
      // Debug logging
      debugPrint('Certificate data provided: ${certificateData.toString()}');
      debugPrint('Certificate pdfUrl: ${certificateData['pdfUrl']}');
      debugPrint('Certificate pdfPath: ${certificateData['pdfPath']}');

      // Check if certificate data actually contains valid certificate information
      bool hasCertificate = certificateData.isNotEmpty;

      debugPrint('Certificate available: $hasCertificate');
      return _buildCertificateCardContent(
          appointment, hasCertificate, certificateData);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('certificates')
          .where('appointmentId', isEqualTo: appointment['appointmentId'])
          .snapshots(),
      builder: (context, snapshot) {
        bool hasCertificate =
            snapshot.hasData && snapshot.data!.docs.isNotEmpty;
        Map<String, dynamic>? streamCertificateData;

        if (hasCertificate) {
          streamCertificateData =
              snapshot.data!.docs.first.data() as Map<String, dynamic>?;
        }

        return _buildCertificateCardContent(
            appointment, hasCertificate, streamCertificateData);
      },
    );
  }

  Widget _buildCertificateCardContent(Map<String, dynamic> appointment,
      bool hasCertificate, Map<String, dynamic>? certificateData) {
    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 40,
              decoration: BoxDecoration(
                color: hasCertificate ? Colors.purple : Colors.grey,
                borderRadius: const BorderRadius.all(Radius.circular(3)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Certificate of Completion",
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasCertificate
                        ? "Certificate available for viewing"
                        : "Certificate not available yet",
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  if (hasCertificate) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _viewCertificatePdf(appointment),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.purple),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.verified,
                            color: Colors.purple, size: 16),
                        label: const Text(
                          'View Certificate PDF',
                          style: TextStyle(color: Colors.purple),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Rejection Card
  Widget _buildRejectionCard(Map<String, dynamic> appointment) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      color: Colors.white,
      child: Column(
        children: [
          // Card Header with Red Accent Strip and Delete Button
          Container(
            decoration: const BoxDecoration(
              color: Colors.red,
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
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.cancel,
                      color: Colors.red,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Appointment Rejected',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Reason for rejection',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Delete Button
                  GestureDetector(
                    onTap: () {
                      _deleteRejectedAppointment(appointment['appointmentId']);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.delete_outline,
                        color: Colors.red,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Rejection Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.red.shade600, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        "Rejection Reason:",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.red.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    appointment["rejectionReason"] ??
                        "No specific reason provided",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.red.shade700,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Timeline Card - Dynamic progress based on appointment status
  Widget _buildTimelineCard(Map<String, dynamic> appointment) {
    String status =
        appointment['status']?.toString().toLowerCase() ?? 'unknown';

    // Determine which steps should be completed based on status
    bool step1Completed = false; // Patient requested appointment
    bool step2Completed = false; // Doctor approved appointment
    bool step3Completed = false; // Consultation completed with prescription
    bool step4Completed = false; // Treatment completion certificate delivered

    switch (status) {
      case 'pending':
        step1Completed = true; // Only step 1 is green
        break;
      case 'approved':
        step1Completed = true;
        step2Completed = true; // Steps 1 and 2 are green
        break;
      case 'consultation_finished':
      case 'with_prescription':
        step1Completed = true;
        step2Completed = true;
        step3Completed = true; // Steps 1, 2, and 3 are green
        break;
      case 'treatment_completed':
      case 'with_certificate':
        step1Completed = true;
        step2Completed = true;
        step3Completed = true;
        step4Completed = true; // All steps are green
        break;
      case 'rejected':
        // For rejected, only show step 1 as completed since they did request
        step1Completed = true;
        break;
      default:
        // For unknown status, show step 1 only
        step1Completed = true;
        break;
    }

    return Card(
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
                        'Your treatment progress',
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
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStepInstruction(
                      '1',
                      'Patient requested appointment with a Doctor',
                      step1Completed),
                  const SizedBox(height: 8),
                  _buildStepInstruction(
                      '2',
                      'Doctor confirmed and approved the appointment schedule',
                      step2Completed),
                  const SizedBox(height: 8),
                  _buildStepInstruction(
                      '3',
                      'Consultation completed with prescription issued',
                      step3Completed),
                  const SizedBox(height: 8),
                  _buildStepInstruction(
                      '4',
                      'Treatment completion certificate delivered',
                      step4Completed),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to build step instruction
  Widget _buildStepInstruction(
      String stepNumber, String instruction, bool isCompleted) {
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

  // Helper method to build info row
  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF0A84FF)),
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

  // Helper method to build info row with bold values
  Widget _buildBoldInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF0A84FF)),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 14, color: Colors.black87),
                children: [
                  TextSpan(
                      text: label,
                      style: const TextStyle(fontWeight: FontWeight.normal)),
                  const TextSpan(text: ' '),
                  TextSpan(
                      text: value,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
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

              // Month & Year pickers
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      DropdownButton<String>(
                        value: _selectedMonth,
                        items: _months
                            .map((month) => DropdownMenuItem(
                                  value: month,
                                  child: Text(month,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                ))
                            .toList(),
                        onChanged: (month) {
                          if (month != null) {
                            setState(() {
                              _selectedMonth = month;
                              final monthIndex = _months.indexOf(month) + 1;
                              _focusedDay =
                                  DateTime(_selectedYear, monthIndex, 1);
                            });
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<int>(
                        value: _selectedYear,
                        items: _years
                            .map((year) => DropdownMenuItem(
                                  value: year,
                                  child: Text(year.toString(),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                ))
                            .toList(),
                        onChanged: (year) {
                          if (year != null) {
                            setState(() {
                              _selectedYear = year;
                              final monthIndex =
                                  _months.indexOf(_selectedMonth) + 1;
                              _focusedDay =
                                  DateTime(_selectedYear, monthIndex, 1);
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.today, color: Colors.redAccent),
                    onPressed: () {
                      setState(() {
                        _focusedDay = DateTime.now();
                        _selectedDay = DateTime.now();
                        _selectedMonth = _months[_focusedDay.month - 1];
                        _selectedYear = _focusedDay.year;
                      });
                    },
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Modern Calendar with Enhanced UI
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: TableCalendar(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  calendarFormat: _calendarFormat,
                  eventLoader: _getEventsForDay,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  },
                  onFormatChanged: (format) {
                    setState(() => _calendarFormat = format);
                  },
                  onPageChanged: (focusedDay) {
                    setState(() {
                      _focusedDay = focusedDay;
                      _selectedMonth = _months[focusedDay.month - 1];
                      _selectedYear = focusedDay.year;
                    });
                  },
                  headerVisible: false,
                  calendarStyle: CalendarStyle(
                    // Today's date styling
                    todayDecoration: BoxDecoration(
                      color: Colors.red.shade600,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.shade600.withOpacity(0.3),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    todayTextStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    // Selected date styling
                    selectedDecoration: BoxDecoration(
                      color: Colors.blue.shade500,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    selectedTextStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    // Default text styling
                    defaultTextStyle: const TextStyle(
                      color: Colors.black87,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    // Weekend styling
                    weekendTextStyle: TextStyle(
                      color: Colors.red.shade400,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    // Outside month styling
                    outsideTextStyle: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 14,
                    ),
                    // Disable default markers
                    markersMaxCount: 0,
                    canMarkersOverflow: false,
                    // Cell styling
                    cellMargin: const EdgeInsets.all(4),
                    cellPadding: const EdgeInsets.all(0),
                  ),
                  calendarBuilders: CalendarBuilders(
                    // Custom builder for days with appointments
                    defaultBuilder: (context, day, focusedDay) {
                      if (_getEventsForDay(day).isNotEmpty) {
                        return Container(
                          margin: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.red.shade400,
                                Colors.red.shade600,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.3),
                                spreadRadius: 1,
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${day.day}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Container(
                                  width: 4,
                                  height: 4,
                                  margin: const EdgeInsets.only(top: 1),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      return null;
                    },
                  ),
                  daysOfWeekStyle: DaysOfWeekStyle(
                    weekendStyle: TextStyle(
                      color: Colors.red.shade500,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    weekdayStyle: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Filter carousel
              SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: _filterOptions.length,
                  itemBuilder: (context, index) {
                    final filter = _filterOptions[index];
                    final isSelected = _selectedFilter == filter['key'];

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _selectedFilter = filter['key'];
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isSelected
                              ? Colors.redAccent
                              : Colors.grey.shade200,
                          foregroundColor:
                              isSelected ? Colors.white : Colors.black54,
                          elevation: isSelected ? 3 : 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                        ),
                        icon: Icon(
                          filter['icon'],
                          size: 18,
                          color: isSelected ? Colors.white : Colors.black54,
                        ),
                        label: Text(
                          filter['label'].replaceAll('\n', ' '),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Appointments list
              if (_currentPatientId != null)
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _getCombinedAppointmentsStream(),
                  builder: (context, snapshot) {
                    debugPrint(
                        'StreamBuilder state: ${snapshot.connectionState}');
                    debugPrint('StreamBuilder has error: ${snapshot.hasError}');
                    debugPrint('StreamBuilder error: ${snapshot.error}');

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      debugPrint('StreamBuilder error: ${snapshot.error}');
                      return Center(
                        child: Text(
                            'Error loading appointments: ${snapshot.error}'),
                      );
                    }

                    final allAppointments = snapshot.data ?? [];
                    debugPrint(
                        'Total appointments found: ${allAppointments.length}');

                    // Filter appointments based on selected filter
                    List<Map<String, dynamic>> filteredAppointments;
                    switch (_selectedFilter) {
                      case 'All':
                        // All: pending, approved, consultation_finished
                        filteredAppointments = allAppointments
                            .where((appointment) =>
                                appointment['status'] == 'pending' ||
                                appointment['status'] == 'approved' ||
                                appointment['status'] ==
                                    'consultation_finished')
                            .toList();
                        break;
                      case 'Treatment Completed':
                        // Only treatment completed appointments
                        filteredAppointments = allAppointments
                            .where((appointment) =>
                                appointment['status'] == 'treatment_completed')
                            .toList();
                        break;
                      case 'History':
                        // Pending, approved, consultation_finished, rejected (excludes treatment_completed)
                        filteredAppointments = allAppointments
                            .where((appointment) =>
                                appointment['status'] == 'pending' ||
                                appointment['status'] == 'approved' ||
                                appointment['status'] ==
                                    'consultation_finished' ||
                                appointment['status'] == 'rejected')
                            .toList();
                        break;
                      default:
                        filteredAppointments = allAppointments;
                        break;
                    }

                    if (filteredAppointments.isEmpty) {
                      String emptyMessage;
                      switch (_selectedFilter) {
                        case 'All':
                          emptyMessage = 'No current appointments found';
                          break;
                        case 'Treatment Completed':
                          emptyMessage = 'No completed treatments found';
                          break;
                        case 'History':
                          emptyMessage = 'No appointment history found';
                          break;
                        default:
                          emptyMessage = 'No appointments found';
                          break;
                      }

                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            emptyMessage,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredAppointments.length,
                      itemBuilder: (context, index) {
                        final appointment = filteredAppointments[index];
                        String status =
                            appointment['status']?.toString().toLowerCase() ??
                                'unknown';

                        return Card(
                          color: Colors.white,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _getStatusColor(status),
                              child: Text(
                                appointment["patientName"]
                                        ?.substring(0, 1)
                                        .toUpperCase() ??
                                    "P",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              appointment['doctorName'] ??
                                  appointment['doctor_name'] ??
                                  'Doctor Not Available',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  _formatAppointmentDateTime(appointment),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(status)
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: _getStatusColor(status)
                                              .withOpacity(0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        _getStatusDisplayText(status),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: _getStatusColor(status),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    // Room ID indicator for approved appointments
                                    if (status == 'approved' &&
                                        appointment['roomId'] != null &&
                                        appointment['roomId']
                                            .toString()
                                            .isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade50,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: Colors.green.shade200,
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.videocam,
                                              size: 12,
                                              color: Colors.green.shade600,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Video Call',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.green.shade600,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                            trailing: appointment['status'] == 'rejected'
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                      size: 24,
                                    ),
                                    onPressed: () =>
                                        _deleteRejectedAppointment(appointment),
                                  )
                                : const Icon(Icons.chevron_right,
                                    color: Colors.grey),
                            onTap: () => _showAppointmentDetails(appointment),
                          ),
                        );
                      },
                    );
                  },
                )
              else
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                ),

              // Bottom padding to ensure content isn't cut off
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // Method to view prescription PDF in-app
  Future<void> _viewPrescriptionPdf(
      Map<String, dynamic> prescriptionData) async {
    try {
      String filename = 'Prescription.pdf';

      // Check for Cloudinary URL first
      if (prescriptionData['pdfUrl'] != null &&
          prescriptionData['pdfUrl'].toString().isNotEmpty) {
        String pdfUrl = prescriptionData['pdfUrl'].toString();
        debugPrint('Opening PDF from URL: $pdfUrl');

        // Navigate to URL-based PDF viewer
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => _PdfViewerFromUrlScreen(
              pdfUrl: pdfUrl,
              title: 'Prescription PDF',
              filename: filename,
              backgroundColor: Colors.blue,
            ),
          ),
        );
        return;
      }

      // Check for local PDF path (fallback)
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
                filename: filename,
                backgroundColor: Colors.blue,
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
            content: Text('PDF not available. Please contact your doctor.'),
            backgroundColor: Colors.orange,
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

  // Method to view certificate PDF in-app
  Future<void> _viewCertificatePdf(Map<String, dynamic> appointment) async {
    try {
      Map<String, dynamic>? certificateData;

      // First try to use the enriched certificate data
      if (appointment['certificateData'] != null) {
        certificateData =
            appointment['certificateData'] as Map<String, dynamic>;
        debugPrint('Using enriched certificate data');
      } else {
        // Fallback: Query the certificates collection for this appointment
        final appointmentId = appointment['appointmentId'];
        final certificateSnapshot = await FirebaseFirestore.instance
            .collection('certificates')
            .where('appointmentId', isEqualTo: appointmentId)
            .get();

        if (certificateSnapshot.docs.isNotEmpty) {
          certificateData = certificateSnapshot.docs.first.data();
          debugPrint('Queried certificate data from Firestore');
        }
      }

      if (certificateData != null) {
        debugPrint('Certificate data found: ${certificateData.toString()}');

        // Check for Cloudinary URL first
        if (certificateData['pdfUrl'] != null &&
            certificateData['pdfUrl'].toString().isNotEmpty) {
          String pdfUrl = certificateData['pdfUrl'].toString();
          debugPrint('Opening certificate PDF from URL: $pdfUrl');

          // Navigate to URL-based PDF viewer
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => _PdfViewerFromUrlScreen(
                pdfUrl: pdfUrl,
                title: 'TB Treatment Certificate',
                filename: 'TB_Certificate.pdf',
                backgroundColor: Colors.purple,
              ),
            ),
          );
          return;
        }

        // Check for local PDF path (fallback)
        if (certificateData['pdfPath'] != null &&
            certificateData['pdfPath'].toString().isNotEmpty) {
          final pdfPath = certificateData['pdfPath'].toString();
          debugPrint('Attempting to open PDF from path: $pdfPath');

          final file = File(pdfPath);
          if (await file.exists()) {
            debugPrint('PDF file exists, reading bytes...');
            final pdfBytes = await file.readAsBytes();
            // Show in-app PDF viewer
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => _PdfViewerScreen(
                  pdfBytes: pdfBytes,
                  title: 'TB Treatment Certificate',
                  filename: 'TB_Certificate.pdf',
                  backgroundColor: Colors.purple,
                ),
              ),
            );
            return;
          } else {
            debugPrint('PDF file does not exist at path: $pdfPath');
          }
        }
      }

      // No certificate found or no PDF available
      debugPrint('No certificate PDF available - showing error message');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Certificate PDF not available. Please contact your healthcare provider.'),
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

// In-app PDF Viewer Screen for URLs
class _PdfViewerFromUrlScreen extends StatefulWidget {
  final String pdfUrl;
  final String title;
  final String filename;
  final Color? backgroundColor;

  const _PdfViewerFromUrlScreen({
    required this.pdfUrl,
    required this.title,
    required this.filename,
    this.backgroundColor,
  });

  @override
  State<_PdfViewerFromUrlScreen> createState() =>
      _PdfViewerFromUrlScreenState();
}

class _PdfViewerFromUrlScreenState extends State<_PdfViewerFromUrlScreen> {
  pdfx.PdfController? _pdfController;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializePdf();
  }

  Future<void> _initializePdf() async {
    try {
      debugPrint('Initializing PDF from URL: ${widget.pdfUrl}');

      // Download PDF from URL
      final response = await http.get(Uri.parse(widget.pdfUrl));
      if (response.statusCode == 200) {
        final pdfBytes = response.bodyBytes;
        _pdfController = pdfx.PdfController(
          document: pdfx.PdfDocument.openData(pdfBytes),
        );
        setState(() {
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to download PDF: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error loading PDF: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load PDF: ${e.toString()}';
      });
    }
  }

  Future<void> _downloadAndSharePdf() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Download PDF bytes from URL
      final response = await http.get(Uri.parse(widget.pdfUrl));

      // Close loading dialog
      Navigator.of(context).pop();

      if (response.statusCode == 200) {
        final pdfBytes = response.bodyBytes;

        // Share the PDF
        await Printing.sharePdf(
          bytes: pdfBytes,
          filename: widget.filename,
        );
      } else {
        throw Exception('Failed to download PDF: ${response.statusCode}');
      }
    } catch (e) {
      // Close loading dialog if still open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error downloading PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _printPdf() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Download PDF bytes from URL
      final response = await http.get(Uri.parse(widget.pdfUrl));

      // Close loading dialog
      Navigator.of(context).pop();

      if (response.statusCode == 200) {
        final pdfBytes = response.bodyBytes;

        // Print the PDF
        await Printing.layoutPdf(
          onLayout: (format) => pdfBytes,
        );
      } else {
        throw Exception('Failed to download PDF: ${response.statusCode}');
      }
    } catch (e) {
      // Close loading dialog if still open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error printing PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F5),
      body: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Back Button
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade300,
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios,
                        color: Color.fromARGB(223, 107, 107, 107), size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const Text(
                  "E-Prescription",
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

          // PDF Content with Integrated Action Buttons
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              decoration: const BoxDecoration(
                color: Colors.transparent, // Remove white background
                borderRadius: BorderRadius.all(Radius.circular(20)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Column(
                  children: [
                    // PDF Content Area
                    Expanded(
                      child: _buildBody(),
                    ),

                    // Integrated Action Buttons Inside Container
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Colors.transparent, // Remove background color
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Compact Share Button
                          Expanded(
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    const Color(0xFF4A90E2),
                                    const Color(0xFF357ABD),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF4A90E2)
                                        .withOpacity(0.3),
                                    spreadRadius: 0,
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _downloadAndSharePdf,
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                    child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.share_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Share',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Compact Print Button
                          Expanded(
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    const Color(0xFF27AE60),
                                    const Color(0xFF219A52),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF27AE60)
                                        .withOpacity(0.3),
                                    spreadRadius: 0,
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _printPdf,
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                    child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.print_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Print',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ],
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
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Loading PDF...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please wait while we prepare your prescription',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.description_outlined,
                  size: 64,
                  color: Colors.red.shade400,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Unable to Load PDF',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade500, Colors.blue.shade600],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                      _errorMessage = null;
                    });
                    _initializePdf();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.refresh, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Try Again',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_pdfController == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 48,
              color: Colors.orange.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'PDF Controller Not Available',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      );
    }

    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        padding: const EdgeInsets.all(8), // Small margins around PDF pages
        child: pdfx.PdfView(
          controller: _pdfController!,
          scrollDirection: Axis.vertical,
          backgroundDecoration: const BoxDecoration(
            color: Colors.transparent, // Remove background
          ),
          // Enable smooth scrolling and zoom
          pageSnapping: false,
          physics: const BouncingScrollPhysics(),
        ),
      ),
    );
  }
}

// In-app PDF Viewer Screen for local files
class _PdfViewerScreen extends StatelessWidget {
  final Uint8List pdfBytes;
  final String title;
  final String filename;
  final Color? backgroundColor;

  const _PdfViewerScreen({
    required this.pdfBytes,
    required this.title,
    required this.filename,
    this.backgroundColor,
  });

  Future<void> _sharePdf(BuildContext context) async {
    try {
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: filename,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sharing PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _printPdf(BuildContext context) async {
    try {
      await Printing.layoutPdf(
        onLayout: (format) => pdfBytes,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error printing PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F5),
      body: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Back Button
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade300,
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios,
                        color: Color.fromARGB(223, 107, 107, 107), size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xE0F44336),
                  ),
                ),
                const SizedBox(width: 48), // spacing balance
              ],
            ),
          ),

          // PDF Content with Integrated Action Buttons
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              decoration: const BoxDecoration(
                color: Colors.transparent, // Remove white background
                borderRadius: BorderRadius.all(Radius.circular(20)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Column(
                  children: [
                    // PDF Content Area
                    Expanded(
                      child: InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 4.0,
                        child: ClipRect(
                          child: PdfPreview(
                            build: (format) => pdfBytes,
                            allowPrinting:
                                false, // We handle this in bottom buttons
                            allowSharing:
                                false, // We handle this in bottom buttons
                            canChangePageFormat: false,
                            canChangeOrientation:
                                false, // Disable orientation change
                            canDebug: false,
                            initialPageFormat: PdfPageFormat.a4,
                            pdfFileName: filename,
                            actions: const [], // Remove all default actions
                            useActions: false, // Completely disable action bar
                            scrollViewDecoration: const BoxDecoration(
                              color: Colors.transparent,
                            ),
                            // Remove any bottom decorations
                            dynamicLayout: false,
                            maxPageWidth: double.infinity,
                            previewPageMargin: const EdgeInsets.all(
                                8), // Small margins around pages
                            pageFormats: const {}, // Remove page format options
                          ),
                        ),
                      ),
                    ),

                    // Integrated Action Buttons Inside Container
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Colors.transparent, // Remove background color
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Compact Share Button
                          Expanded(
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    const Color(0xFF4A90E2),
                                    const Color(0xFF357ABD),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF4A90E2)
                                        .withOpacity(0.3),
                                    spreadRadius: 0,
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => _sharePdf(context),
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                    child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.share_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Share',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Compact Print Button
                          Expanded(
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    const Color(0xFF27AE60),
                                    const Color(0xFF219A52),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF27AE60)
                                        .withOpacity(0.3),
                                    spreadRadius: 0,
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => _printPdf(context),
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                    child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.print_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Print',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ],
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
        ],
      ),
    );
  }
}
