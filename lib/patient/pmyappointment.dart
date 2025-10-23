import 'package:flutter/material.dart';
import 'package:tb_frontend/patient/appointment_status_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:printing/printing.dart';
import 'dart:io';
import 'dart:async';
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
  final CalendarFormat _calendarFormat = CalendarFormat.month;

  String? _currentPatientId;

  String _selectedMonth = '';
  final int _selectedYear = DateTime.now().year;

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

  // Timer for live time widget
  Timer? _timer;
  DateTime _currentTime = DateTime.now();

  // Filter for appointments
  String _selectedFilter = 'Recent'; // Updated filter options

  // Map to track expansion state of schedule cards by appointment ID
  final Map<String, bool> _scheduleCardExpansionState = {};

  // Highlighted appointment ID for notification click
  String? _highlightedAppointmentId;
  Timer? _highlightTimer;


  // Available filter options
  final List<Map<String, dynamic>> _filterOptions = [
    {
      'key': 'Recent',
      'label': 'Recent',
      'icon': Icons.access_time_rounded,
      'color': Colors.blue,
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

    // Initialize live time timer - Update every MINUTE to prevent blinking
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() => _currentTime = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _highlightTimer?.cancel();
    super.dispose();
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
        return 'Pending';
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

  // Get month abbreviation
  String _getMonthAbbr(int month) {
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC'
    ];
    return months[month - 1];
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

  // Build avatar based on appointment status
  Widget _buildAppointmentAvatar(
      Map<String, dynamic> appointment, String status) {
    if (status == 'approved') {
      // For approved: Show date in avatar with same styling as dlanding_page.dart
      DateTime? appointmentDate;
      try {
        final dynamic date = appointment["date"] ??
            appointment["appointmentDate"] ??
            appointment["appointment_date"];
        if (date is Timestamp) {
          appointmentDate = date.toDate();
        } else if (date is DateTime) {
          appointmentDate = date;
        } else if (date is String) {
          appointmentDate = DateTime.parse(date);
        }
      } catch (e) {
        debugPrint('Error parsing date: $e');
      }

      return Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              appointmentDate != null ? appointmentDate.day.toString() : "?",
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1,
              ),
            ),
            Text(
              appointmentDate != null
                  ? _getMonthAbbr(appointmentDate.month)
                  : "---",
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      );
    } else {
      // For pending, with_prescription, treatment_completed: Show doctor initial
      String doctorName =
          appointment['doctorName'] ?? appointment['doctor_name'] ?? 'Doctor';
      return CircleAvatar(
        backgroundColor: _getStatusColor(status),
        child: Text(
          doctorName.substring(0, 1).toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
  }

  // Build title based on appointment status
  Widget _buildAppointmentTitle(
      Map<String, dynamic> appointment, String status) {
    if (status == 'approved') {
      // For approved: Show TIME in bold
      String? displayTime;
      try {
        final dynamic appointmentDate = appointment["date"] ??
            appointment["appointmentDate"] ??
            appointment["appointment_date"];
        DateTime? date;
        if (appointmentDate is Timestamp) {
          date = appointmentDate.toDate();
        } else if (appointmentDate is DateTime) {
          date = appointmentDate;
        } else if (appointmentDate is String) {
          date = DateTime.parse(appointmentDate);
        }

        if (date != null) {
          int hour = date.hour;
          int minute = date.minute;
          String period = hour >= 12 ? 'PM' : 'AM';
          if (hour > 12) hour -= 12;
          if (hour == 0) hour = 12;
          displayTime =
              "${hour.toString()}:${minute.toString().padLeft(2, '0')} $period";
        }
      } catch (e) {
        debugPrint('Error parsing time: $e');
      }

      displayTime ??= appointment["appointmentTime"] ??
          appointment["appointment_time"] ??
          appointment["time"] ??
          "Time not set";

      return Text(
        displayTime ?? "Time not set",
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      );
    } else {
      // For pending, with_prescription, treatment_completed: Show doctor name
      String doctorName = appointment['doctorName'] ??
          appointment['doctor_name'] ??
          'Doctor Not Available';
      return Text(
        'Dr. $doctorName',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      );
    }
  }

  // Build subtitle based on appointment status
  Widget _buildAppointmentSubtitle(
      Map<String, dynamic> appointment, String status) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        // Doctor name (only for approved appointments)
        if (status == 'approved') ...[
          Text(
            'Dr. ${appointment['doctorName'] ?? appointment['doctor_name'] ?? 'Doctor Not Available'}',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
        ],
        // Status badge and optional room ID
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _getStatusColor(status).withOpacity(0.3),
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
                appointment['roomId'].toString().isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
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
    );
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

        // Check multiple possible date field names
        final dynamic dateField =
            data['date'] ?? data['appointmentDate'] ?? data['appointment_date'];

        debugPrint('Processing pending appointment: $dateField');

        if (dateField != null) {
          try {
            DateTime date;
            if (dateField is Timestamp) {
              date = dateField.toDate();
            } else if (dateField is DateTime) {
              date = dateField;
            } else if (dateField is String) {
              date = DateTime.parse(dateField.toString());
            } else {
              continue; // Skip if unknown type
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

        // Check multiple possible date field names
        final dynamic dateField =
            data['date'] ?? data['appointmentDate'] ?? data['appointment_date'];

        debugPrint('Processing approved appointment: $dateField');

        if (dateField != null) {
          try {
            DateTime date;
            if (dateField is Timestamp) {
              date = dateField.toDate();
            } else if (dateField is DateTime) {
              date = dateField;
            } else if (dateField is String) {
              date = DateTime.parse(dateField.toString());
            } else {
              continue; // Skip if unknown type
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

  // Get time-based gradient colors
  List<Color> _getTimeBasedGradient() {
    final hour = _currentTime.hour;
    final minute = _currentTime.minute;
    final totalMinutes = hour * 60 + minute;

    // 5:30 PM to 7:00 PM - Night but not so dark (dusk)
    if (totalMinutes >= 17 * 60 + 30 && totalMinutes < 19 * 60) {
      return [const Color(0xFF4A5568), const Color(0xFF2D3748)]; // Soft night
    }
    // 7:00 PM to 4:00 AM - So dark (deep night) with violet-black tones
    else if (totalMinutes >= 19 * 60 || totalMinutes < 4 * 60) {
      return [const Color(0xFF0a0015), const Color(0xFF1a0033), const Color(0xFF2d1b4e)]; // Very dark violet-black
    }
    // 4:01 AM to 5:59 AM - Almost sunrise (light black/white)
    else if (totalMinutes >= 4 * 60 + 1 && totalMinutes < 6 * 60) {
      return [const Color(0xFF4B5563), const Color(0xFF6B7280)]; // Light gray
    }
    // 6:00 AM to 8:00 AM - Sunrise (soft pastel)
    else if (totalMinutes >= 6 * 60 && totalMinutes <= 8 * 60) {
      return [const Color.fromARGB(255, 247, 205, 163), const Color(0xFFFDEFEF)]; // Very light peach -> blush
    }
    // 8:01 AM to 12:00 PM - Morning (soft warm pastel)
    else if (totalMinutes > 8 * 60 && totalMinutes <= 12 * 60) {
      return [const Color.fromARGB(255, 245, 210, 130), const Color(0xFFFFF1D6)]; // Pale cream -> warm pastel yellow
    }
    // 12:01 PM to 4:30 PM - Afternoon (soft coral/peach)
    else if (totalMinutes > 12 * 60 && totalMinutes <= 16 * 60 + 30) {
      return [const Color.fromARGB(255, 244, 175, 168), const Color.fromARGB(255, 253, 234, 217)]; // Soft peach -> very light coral
    }
    // 4:31 PM to 5:29 PM - Late afternoon (gentle warm)
    else if (totalMinutes > 16 * 60 + 30 && totalMinutes < 17 * 60 + 30) {
      return [const Color.fromARGB(255, 171, 223, 243), const Color(0xFFFFF3E0)]; // Gentle warm beige/peach
    }

    return [const Color(0xFF87CEEB), const Color(0xFF4682B4)]; // Default sky blue
  }


  // Get formatted time (12-hour format with AM/PM) - WITHOUT SECONDS
  String _getFormattedTime() {
    final hour = _currentTime.hour > 12
        ? _currentTime.hour - 12
        : (_currentTime.hour == 0 ? 12 : _currentTime.hour);
    final minute = _currentTime.minute.toString().padLeft(2, '0');
    final period = _currentTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  // Get formatted date
  String _getFormattedDate() {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final days = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday'
    ];
    return '${days[_currentTime.weekday % 7]}, ${months[_currentTime.month - 1]} ${_currentTime.day}, ${_currentTime.year}';
  }

  // Calculate days until appointment
  String _calculateTimeUntilAppointment(DateTime appointmentDate) {
    final now = DateTime.now();
    final difference = appointmentDate.difference(now);

    if (difference.inDays > 7) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks week${weeks > 1 ? 's' : ''} left';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} left';
    } else if (difference.inDays == 0) {
      return 'Today!';
    } else {
      return 'Overdue';
    }
  }

  // Notification tap handling removed with persistent notification UI

  // (Persistent notification UI removed per request)

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
    return AppointmentStatusCard(status: appointment['status']);
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
        // If still pending, show a cancel appointment button below the timeline
        if (status == 'pending') ...[
          const SizedBox(height: 12),
          Center(
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () async {
                  final apptId = appointment['appointmentId'] ?? appointment['id'] ?? '';
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (dCtx) => AlertDialog(
                      title: const Text('Cancel appointment'),
                      content: const Text('Are you sure you want to cancel this pending appointment?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.of(dCtx).pop(false), child: const Text('No')),
                        TextButton(onPressed: () => Navigator.of(dCtx).pop(true), child: const Text('Yes')),
                      ],
                    ),
                  );
                  if (confirm != true) return;

                  if (apptId == null || apptId == '') {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Appointment ID not found')));
                    return;
                  }

                  try {
                    // Try deleting from pending_patient_data
                    await FirebaseFirestore.instance.collection('pending_patient_data').doc(apptId).delete();
                  } catch (e) {
                    // best-effort: try removing from approved_appointments as fallback
                    try {
                      await FirebaseFirestore.instance.collection('approved_appointments').doc(apptId).delete();
                    } catch (e) {
                      debugPrint('Could not delete appointment: $e');
                    }
                  }

                  // Remove related notifications
                  try {
                    final q = await FirebaseFirestore.instance.collection('patient_notifications').where('appointmentId', isEqualTo: apptId).get();
                    for (var doc in q.docs) {
                      await doc.reference.delete();
                    }
                  } catch (e) {
                    debugPrint('Error deleting related notifications: $e');
                  }

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Appointment cancelled')));
                    Navigator.of(context).pop();
                  }
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.redAccent.shade200),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text('Cancel Appointment', style: TextStyle(color: Colors.redAccent.shade700)),
              ),
            ),
          ),
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

  // Show full calendar in floating bubble dialog
  void _showFullCalendar(BuildContext context) {
    DateTime tempFocusedDay = _focusedDay;
    DateTime? tempSelectedDay = _selectedDay;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              constraints: const BoxConstraints(maxWidth: 420),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 40,
                    spreadRadius: 0,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Modern Calendar Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFFF5252), Color(0xFFFF1744)],
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(28),
                        topRight: Radius.circular(28),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.redAccent.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.calendar_month_rounded,
                              color: Colors.white, size: 19),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Select Date',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: InkWell(
                            onTap: () {
                              Navigator.pop(context);
                            },
                            child: const Icon(Icons.close_rounded,
                                color: Colors.white, size: 19),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Month-Year Selector Bar with Navigation Arrows
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                    ),
                    child: Row(
                      children: [
                        // Left Navigation Arrow
                        InkWell(
                          onTap: () {
                            setDialogState(() {
                              tempFocusedDay = DateTime(tempFocusedDay.year,
                                  tempFocusedDay.month - 1, 1);
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.redAccent.withOpacity(0.2),
                                  width: 1.5),
                            ),
                            child: const Icon(
                              Icons.chevron_left_rounded,
                              color: Colors.redAccent,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Month-Year Selector (Center)
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _showMonthYearPicker(
                                context, setDialogState, tempFocusedDay,
                                (newDate) {
                              tempFocusedDay = newDate;
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: Colors.redAccent.withOpacity(0.3),
                                    width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.12),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.calendar_month_rounded,
                                      color: Colors.redAccent[700], size: 16),
                                  const SizedBox(width: 7),
                                  Text(
                                    '${_getMonthName(tempFocusedDay.month)} ${tempFocusedDay.year}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.redAccent[700],
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Icon(Icons.expand_more_rounded,
                                      color: Colors.redAccent[700], size: 18),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Right Navigation Arrow
                        InkWell(
                          onTap: () {
                            setDialogState(() {
                              tempFocusedDay = DateTime(tempFocusedDay.year,
                                  tempFocusedDay.month + 1, 1);
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.redAccent.withOpacity(0.2),
                                  width: 1.5),
                            ),
                            child: const Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.redAccent,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Calendar content with modern styling
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                    child: TableCalendar(
                      firstDay: DateTime.utc(2020, 1, 1),
                      lastDay: DateTime.utc(2030, 12, 31),
                      focusedDay: tempFocusedDay,
                      selectedDayPredicate: (day) =>
                          isSameDay(tempSelectedDay, day),
                      calendarFormat: CalendarFormat.month,
                      eventLoader: (day) {
                        return _appointmentDates
                            .where((d) => isSameDay(d, day))
                            .toList();
                      },
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                        });
                        Navigator.pop(context);
                      },
                      onPageChanged: (focusedDay) {
                        setDialogState(() {
                          tempFocusedDay = focusedDay;
                        });
                      },
                      calendarStyle: CalendarStyle(
                        // Today's date styling - Modern highlight
                        todayDecoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.redAccent.withOpacity(0.2),
                              Colors.redAccent.withOpacity(0.15)
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.redAccent.withOpacity(0.4),
                              width: 1.5),
                        ),
                        todayTextStyle: const TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                        // Selected date styling - Modern solid
                        selectedDecoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF5252), Color(0xFFFF1744)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.redAccent.withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        selectedTextStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                        // Default date styling
                        defaultDecoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        defaultTextStyle: const TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                        ),
                        // Weekend styling
                        weekendDecoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        weekendTextStyle: TextStyle(
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                        ),
                        // Outside dates
                        outsideDecoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        outsideTextStyle: TextStyle(
                          color: Colors.grey[350],
                          fontWeight: FontWeight.w400,
                          fontSize: 15,
                        ),
                        // Marker (appointment dot) styling - Modern gradient dots
                        markerDecoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF5252), Color(0xFFFF1744)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.redAccent.withOpacity(0.3),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        markersMaxCount: 3,
                        markerSize: 7.0,
                        markerMargin:
                            const EdgeInsets.symmetric(horizontal: 1.5),
                        // Cell decoration
                        cellMargin: const EdgeInsets.all(4),
                        cellPadding: const EdgeInsets.all(0),
                      ),
                      headerStyle: HeaderStyle(
                        titleCentered: true,
                        formatButtonVisible: false,
                        leftChevronVisible: false,
                        rightChevronVisible: false,
                        titleTextStyle: const TextStyle(
                          fontSize: 0,
                          fontWeight: FontWeight.bold,
                          color: Colors.transparent,
                        ),
                        headerPadding: const EdgeInsets.symmetric(vertical: 12),
                        headerMargin: const EdgeInsets.only(bottom: 8),
                      ),
                      daysOfWeekStyle: DaysOfWeekStyle(
                        weekdayStyle: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[700],
                          fontSize: 13,
                          letterSpacing: 1,
                        ),
                        weekendStyle: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[500],
                          fontSize: 13,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Get month name
  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }

  // Show Month-Year Picker (Two-step: Year first, then Month)
  void _showMonthYearPicker(BuildContext context, StateSetter setDialogState,
      DateTime currentDate, Function(DateTime) onDateChanged) async {
    int? selectedYear;
    int? selectedMonth;

    // Step 1: Select Year
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Colors.grey[50]!],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF5252), Color(0xFFFF1744)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.event_note_rounded,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Select Year',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 280,
                height: 320,
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 2.0,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: 20,
                  itemBuilder: (context, index) {
                    final year = DateTime.now().year - 5 + index;
                    final isSelected = year == currentDate.year;
                    return InkWell(
                      onTap: () {
                        selectedYear = year;
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: isSelected
                              ? const LinearGradient(
                                  colors: [
                                    Color(0xFFFF5252),
                                    Color(0xFFFF1744)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : LinearGradient(
                                  colors: [Colors.white, Colors.grey[100]!],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? Colors.redAccent
                                : Colors.grey[300]!,
                            width: isSelected ? 1.5 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: Colors.redAccent.withOpacity(0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.08),
                                    blurRadius: 3,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                        ),
                        child: Center(
                          child: Text(
                            '$year',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color:
                                  isSelected ? Colors.white : Colors.grey[800],
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // If year was selected, proceed to Step 2: Select Month
    if (selectedYear != null) {
      const months = [
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

      await showDialog(
        context: context,
        builder: (context) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, Colors.grey[50]!],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF5252), Color(0xFFFF1744)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.calendar_today_rounded,
                          color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        'Select Month - $selectedYear',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 280,
                  height: 320,
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 2.5,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: 12,
                    itemBuilder: (context, index) {
                      final monthNum = index + 1;
                      final isSelected = monthNum == currentDate.month &&
                          selectedYear == currentDate.year;
                      return InkWell(
                        onTap: () {
                          selectedMonth = monthNum;
                          Navigator.pop(context);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: isSelected
                                ? const LinearGradient(
                                    colors: [
                                      Color(0xFFFF5252),
                                      Color(0xFFFF1744)
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : LinearGradient(
                                    colors: [Colors.white, Colors.grey[100]!],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.redAccent
                                  : Colors.grey[300]!,
                              width: isSelected ? 1.5 : 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: Colors.redAccent.withOpacity(0.3),
                                      blurRadius: 6,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : [
                                    BoxShadow(
                                      color: Colors.grey.withOpacity(0.08),
                                      blurRadius: 3,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                          ),
                          child: Center(
                            child: Text(
                              months[index],
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: isSelected
                                    ? Colors.white
                                    : Colors.grey[800],
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // If both year and month were selected, update the calendar
      if (selectedMonth != null) {
        setDialogState(() {
          onDateChanged(DateTime(selectedYear!, selectedMonth!, 1));
        });
      }
    }
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
              const SizedBox(height: 16),

              // Modern Compact Live Time Widget
              Container(
                width: double.infinity,
                height: 180,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: _getTimeBasedGradient(),
                  ),
                ),
                child: Stack(
                  children: [
                    // STARS (only visible during night time)
                    if (_currentTime.hour >= 19 || _currentTime.hour < 6)
                      ...List.generate(30, (index) {
                        final random = (index * 123) % 100;
                        return Positioned(
                          left: (random * 3.5) % 350,
                          top: (random * 1.2) % 120,
                          child: Container(
                            width: random % 3 == 0 ? 3 : 2,
                            height: random % 3 == 0 ? 3 : 2,
                            decoration: BoxDecoration(
                              color: Colors.white
                                  .withOpacity(random % 2 == 0 ? 0.9 : 0.6),
                              shape: BoxShape.circle,
                            ),
                          ),
                        );
                      }),

                    // MOON (only visible during night time)
                    if (_currentTime.hour >= 19 || _currentTime.hour < 6)
                      Positioned(
                        right: 40,
                        top: 30,
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.9),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withOpacity(0.4),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Mountain silhouette at the bottom
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: CustomPaint(
                        size: const Size(double.infinity, 60),
                        painter: MountainPainter(),
                      ),
                    ),
                    // Time and Date content
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // VIEW CALENDAR BUTTON (replaced LIVE TIME)
                          GestureDetector(
                            onTap: () => _showFullCalendar(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.calendar_month_rounded,
                                      color: Colors.white, size: 14),
                                  SizedBox(width: 6),
                                  Text(
                                    'VIEW CALENDAR',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(Icons.keyboard_arrow_down_rounded,
                                      color: Colors.white, size: 16),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // BIG TIME
                          Text(
                            _getFormattedTime(),
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          // SMALL DATE
                          Padding(
                            padding: const EdgeInsets.only(left: 2),
                            child: Text(
                              _getFormattedDate(),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withOpacity(0.8),
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                      case 'Recent':
                        // Recent: Only pending and approved
                        filteredAppointments = allAppointments
                            .where((appointment) =>
                                appointment['status'] == 'pending' ||
                                appointment['status'] == 'approved')
                            .toList();
                        break;
                      case 'History':
                        // History: All appointments including completed treatments
                        filteredAppointments = allAppointments
                            .where((appointment) =>
                                appointment['status'] == 'pending' ||
                                appointment['status'] == 'approved' ||
                                appointment['status'] ==
                                    'consultation_finished' ||
                                appointment['status'] == 'rejected' ||
                                appointment['status'] ==
                                    'treatment_completed' ||
                                appointment['status'] == 'with_prescription' ||
                                appointment['status'] == 'with_certificate')
                            .toList();
                        break;
                      default:
                        filteredAppointments = allAppointments;
                        break;
                    }

                    if (filteredAppointments.isEmpty) {
                      String emptyMessage;
                      switch (_selectedFilter) {
                        case 'Recent':
                          emptyMessage = 'No recent appointments found';
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

                        // Check if this appointment should be highlighted
                        final appointmentId = appointment['appointmentId'] ??
                            appointment['id'] ??
                            '';
                        final isHighlighted =
                            _highlightedAppointmentId == appointmentId &&
                                appointmentId.isNotEmpty;

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeInOut,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: isHighlighted
                                ? [
                                    BoxShadow(
                                      color: Colors.blue.withOpacity(0.4),
                                      blurRadius: 20,
                                      spreadRadius: 3,
                                      offset: const Offset(0, 0),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Card(
                            color: isHighlighted
                                ? Colors.blue.shade50
                                : Colors.white,
                            margin: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: isHighlighted
                                  ? BorderSide(color: Colors.blue, width: 2)
                                  : BorderSide.none,
                            ),
                            elevation: isHighlighted ? 8 : 2,
                            child: ListTile(
                              leading:
                                  _buildAppointmentAvatar(appointment, status),
                              title:
                                  _buildAppointmentTitle(appointment, status),
                              subtitle: _buildAppointmentSubtitle(
                                  appointment, status),
                              trailing: appointment['status'] == 'rejected'
                                  ? IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                        size: 24,
                                      ),
                                      onPressed: () =>
                                          _deleteRejectedAppointment(
                                              appointment),
                                    )
                                  : const Icon(Icons.chevron_right,
                                      color: Colors.grey),
                              onTap: () => _showAppointmentDetails(appointment),
                            ),
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

// Mountain Painter for the time widget background
class MountainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final path = Path();

    // Start from bottom left
    path.moveTo(0, size.height);

    // First mountain (left)
    path.lineTo(size.width * 0.2, size.height * 0.6);
    path.lineTo(size.width * 0.35, size.height * 0.4);

    // Second mountain (center - tallest)
    path.lineTo(size.width * 0.5, size.height * 0.2);
    path.lineTo(size.width * 0.65, size.height * 0.5);

    // Third mountain (right)
    path.lineTo(size.width * 0.8, size.height * 0.3);
    path.lineTo(size.width, size.height * 0.7);

    // Complete the path
    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
