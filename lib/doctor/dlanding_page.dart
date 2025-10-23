import 'dart:async';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'prescription.dart';
import '../services/chat_service.dart';
import '../chat_screens/chat_screen.dart';
import '../screens/video_call_screen.dart';
import '../services/webrtc_service.dart';
import 'package:permission_handler/permission_handler.dart';

bool _showAllAppointments = false; // Track See All state

class Dlandingpage extends StatefulWidget {
  const Dlandingpage({super.key});
  @override
  State<Dlandingpage> createState() => _DlandingpageState();
}

class _DlandingpageState extends State<Dlandingpage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.week;
  List<DateTime> _appointmentDates = []; // Track dates with appointments
  String? _currentDoctorId; // Store current doctor's ID

  // State variables for collapsible sections in appointment details
  bool _isPatientInfoExpanded = false;
  bool _isScheduleExpanded = false;
  bool _isVideoCallExpanded = false;
  // Selection mode for approved appointments
  bool _isApprovedSelectionMode = false;
  final Set<String> _selectedApprovedAppointments = {};

  // Timer for live time widget
  Timer? _timer;
  DateTime _currentTime = DateTime.now();

  final List<String> _months = [
    "January",
    "February",
    "March",
    "April",
    "May",
    "June",
    "July",
    "August",
    "September",
    "October",
    "November",
    "December"
  ];
  late String _selectedMonth;
  late int _selectedYear;
  final List<int> _years =
      List.generate(20, (index) => DateTime.now().year - 5 + index);

  @override
  void initState() {
    super.initState();
    _selectedMonth = _months[_focusedDay.month - 1];
    _selectedYear = _focusedDay.year;
    _getCurrentDoctorId();
    _loadAppointmentDates();
    
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
    super.dispose();
  }

  // Get current doctor's ID
  void _getCurrentDoctorId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _currentDoctorId = user.uid;
      });
      // Reload appointment dates once we have the doctor ID
      _loadAppointmentDates();
    }
  }

  // Load appointment dates from Firestore
  void _loadAppointmentDates() async {
    if (_currentDoctorId == null) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('approved_appointments')
          .where('doctorId', isEqualTo: _currentDoctorId)
          .get();

      final dates = <DateTime>[];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['appointmentDate'] != null) {
          try {
            DateTime appointmentDate;
            if (data['appointmentDate'] is Timestamp) {
              appointmentDate = (data['appointmentDate'] as Timestamp).toDate();
            } else {
              appointmentDate =
                  DateTime.parse(data['appointmentDate'].toString());
            }
            // Normalize to date only (remove time component)
            final dateOnly = DateTime(appointmentDate.year,
                appointmentDate.month, appointmentDate.day);
            if (!dates.any((d) => isSameDay(d, dateOnly))) {
              dates.add(dateOnly);
            }
          } catch (e) {
            debugPrint('Error parsing appointment date: $e');
          }
        }
      }

      if (mounted) {
        setState(() {
          _appointmentDates = dates;
        });
      }
    } catch (e) {
      debugPrint('Error loading appointment dates: $e');
    }
  }

  // Check if a day has appointments
  List<String> _getEventsForDay(DateTime day) {
    return _appointmentDates.any((date) => isSameDay(date, day))
        ? ['appointment']
        : [];
  }

  // Helper method to compare two lists of DateTime
  bool _listsEqual(List<DateTime> list1, List<DateTime> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (!isSameDay(list1[i], list2[i])) return false;
    }
    return true;
  }

  void _showAppointmentDetails(Map<String, dynamic> appointment) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.8,
            maxChildSize: 0.95,
            minChildSize: 0.6,
            builder: (_, controller) => Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                controller: controller,
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
                                    "Appointment Details",
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
                                setModalState(() {
                                  _isPatientInfoExpanded =
                                      !_isPatientInfoExpanded;
                                });
                              },
                              bullets: [
                                'Full Name: ${appointment["patientName"] ?? "Unknown Patient"}',
                                'Email: ${appointment["patientEmail"] ?? "No email provided"}',
                                'Phone: ${appointment["patientPhone"] ?? "No phone provided"}',
                                'Gender: ${appointment["patientGender"] ?? "Not specified"} | Age: ${appointment["patientAge"]?.toString() ?? "Not specified"}',
                              ],
                              buttonText: 'MESSAGE PATIENT',
                              onPressed: () => _openChat(appointment),
                            ),

                            const SizedBox(height: 12),

                            // Schedule Section - Read Only for Approved Appointments
                            _buildScheduleCard(
                              title: "Appointment Schedule",
                              subtitle: "Confirmed appointment details",
                              isExpanded: _isScheduleExpanded,
                              onToggle: () {
                                setModalState(() {
                                  _isScheduleExpanded = !_isScheduleExpanded;
                                });
                              },
                              appointment: appointment,
                            ),

                            const SizedBox(height: 12),

                            // Video Call Section - Join Only for Approved
                            _buildVideoCallCard(
                              title: "Video Call",
                              subtitle: "Join online consultation",
                              isExpanded: _isVideoCallExpanded,
                              onToggle: () {
                                setModalState(() {
                                  _isVideoCallExpanded = !_isVideoCallExpanded;
                                });
                              },
                              appointment: appointment,
                            ),

                            const SizedBox(height: 12),

                            // Prescription Section with New UI
                            _buildPrescriptionCard(appointment),

                            const SizedBox(height: 16),

                            // Patient Journey Timeline Section
                            _buildTimelineCard(appointment),

                            const SizedBox(height: 32),

                            // Action Buttons (Accept/Reject with E-Prescription requirement)
                            _buildActionButtons(appointment),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openChat(Map<String, dynamic> appointment) async {
    try {
      final ChatService chatService = ChatService();
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('No authenticated user found');
      }

      final patientId = appointment['patientUid'];
      final patientName = appointment['patientName'] ?? 'Unknown Patient';

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

  // Build action buttons for Accept/Reject
  Widget _buildActionButtons(Map<String, dynamic> appointment) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('prescriptions')
          .where('appointmentId', isEqualTo: appointment['appointmentId'])
          .snapshots(),
      builder: (context, snapshot) {
        bool hasPrescription = false;
        Map<String, dynamic>? prescriptionData;

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          hasPrescription = true;
          prescriptionData =
              snapshot.data!.docs.first.data() as Map<String, dynamic>;
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

              // Upload Prescription First Button
              if (!hasPrescription)
                Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.grey.shade400, Colors.grey.shade500],
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

              // Complete Meeting button when prescription exists
              if (hasPrescription)
                Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.green.shade400, Colors.green.shade600],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.3),
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
                                    "Meeting completed successfully! Appointment removed from active appointments. Patient notified about e-prescription."),
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
                                content: Text("Error completing meeting: $e"),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
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
            ],
          ),
        );
      },
    );
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
    // 6:00 AM to 8:00 AM - Sunrise
    else if (totalMinutes >= 6 * 60 && totalMinutes <= 8 * 60) {
      return [const Color(0xFFFFA500), const Color(0xFFFF6B6B)]; // Orange-pink
    }
    // 8:01 AM to 12:00 PM - Quite hot
    else if (totalMinutes > 8 * 60 && totalMinutes <= 12 * 60) {
      return [const Color(0xFFFFD700), const Color(0xFFFFA500)]; // Golden yellow
    }
    // 12:01 PM to 4:30 PM - So hot
    else if (totalMinutes > 12 * 60 && totalMinutes <= 16 * 60 + 30) {
      return [const Color(0xFFFF8C00), const Color(0xFFFF4500)]; // Hot orange-red
    }
    // 4:31 PM to 5:29 PM - Not so hot already
    else if (totalMinutes > 16 * 60 + 30 && totalMinutes < 17 * 60 + 30) {
      return [const Color(0xFFFFB347), const Color(0xFFFF8C42)]; // Soft orange
    }

    return [const Color(0xFF87CEEB), const Color(0xFF4682B4)]; // Default sky blue
  }

  // Get formatted time (12-hour format with AM/PM) - WITHOUT SECONDS
  String _getFormattedTime() {
    final hour = _currentTime.hour > 12 ? _currentTime.hour - 12 : (_currentTime.hour == 0 ? 12 : _currentTime.hour);
    final minute = _currentTime.minute.toString().padLeft(2, '0');
    final period = _currentTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  // Get month abbreviation
  String _getMonthAbbr(int month) {
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    return months[month - 1];
  }

  // Build week preview with appointment dots
  Widget _buildWeekPreview() {
    final today = DateTime.now();
    final startOfWeek = today.subtract(Duration(days: today.weekday % 7));
    final weekDays = List.generate(7, (index) => startOfWeek.add(Duration(days: index)));

    return StreamBuilder<QuerySnapshot>(
      stream: _currentDoctorId != null
          ? FirebaseFirestore.instance
              .collection('approved_appointments')
              .where('doctorId', isEqualTo: _currentDoctorId)
              .snapshots()
          : const Stream.empty(),
      builder: (context, snapshot) {
        final appointments = snapshot.data?.docs ?? [];
        
        // Count appointments per day
        Map<String, int> appointmentCounts = {};
        for (var doc in appointments) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['appointmentDate'] != null) {
            try {
              DateTime appointmentDate;
              if (data['appointmentDate'] is Timestamp) {
                appointmentDate = (data['appointmentDate'] as Timestamp).toDate();
              } else {
                appointmentDate = DateTime.parse(data['appointmentDate'].toString());
              }
              final dateKey = '${appointmentDate.year}-${appointmentDate.month}-${appointmentDate.day}';
              appointmentCounts[dateKey] = (appointmentCounts[dateKey] ?? 0) + 1;
            } catch (e) {
              debugPrint('Error parsing appointment date: $e');
            }
          }
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: weekDays.map((day) {
            final dateKey = '${day.year}-${day.month}-${day.day}';
            final count = appointmentCounts[dateKey] ?? 0;
            final isToday = day.day == today.day && day.month == today.month && day.year == today.year;
            
            return Column(
              children: [
                // Day name
                Text(
                  ['S', 'M', 'T', 'W', 'T', 'F', 'S'][day.weekday % 7],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.7),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                // Day number with highlight for today
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isToday 
                        ? Colors.redAccent 
                        : Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      '${day.day}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // Appointment indicator dots (max 3)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    count > 3 ? 3 : count,
                    (index) => Container(
                      width: 4,
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        );
      },
    );
  }

  // Show full calendar in floating bubble dialog
  void _showFullCalendar(BuildContext context) {
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
                        child: const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 23),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Select Date',
                        style: TextStyle(
                          fontSize: 19,
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
                            // Restore to today's date when canceled
                            setState(() {
                              _focusedDay = DateTime.now();
                            });
                            Navigator.pop(context);
                          },
                          child: const Icon(Icons.close_rounded, color: Colors.white, size: 23),
                        ),
                      ),
                    ],
                  ),
                ),
                // Month-Year Selector Bar with Navigation Arrows
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                  ),
                  child: Row(
                    children: [
                      // Left Navigation Arrow
                      InkWell(
                        onTap: () {
                          setDialogState(() {
                            _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1, 1);
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.redAccent.withOpacity(0.2), width: 1.5),
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
                          onTap: () => _showMonthYearPicker(context, setDialogState),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.redAccent.withOpacity(0.3), width: 1.5),
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
                                Icon(Icons.calendar_month_rounded, color: Colors.redAccent[700], size: 16),
                                const SizedBox(width: 7),
                                Text(
                                  '${_getMonthName(_focusedDay.month)} ${_focusedDay.year}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.redAccent[700],
                                    letterSpacing: 0.4,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Icon(Icons.expand_more_rounded, color: Colors.redAccent[700], size: 18),
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
                            _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1, 1);
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.redAccent.withOpacity(0.2), width: 1.5),
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
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    calendarFormat: CalendarFormat.month,
                    eventLoader: (day) {
                      return _appointmentDates.where((d) => isSameDay(d, day)).toList();
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
                        _focusedDay = focusedDay;
                      });
                    },
                    calendarStyle: CalendarStyle(
                      // Today's date styling - Modern highlight
                      todayDecoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.redAccent.withOpacity(0.2), Colors.redAccent.withOpacity(0.15)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.redAccent.withOpacity(0.4), width: 1.5),
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
                      markerMargin: const EdgeInsets.symmetric(horizontal: 1.5),
                      // Cell decoration
                      cellMargin: const EdgeInsets.all(4),
                      cellPadding: const EdgeInsets.all(0),
                    ),
                    headerStyle: HeaderStyle(
                      titleCentered: true,
                      formatButtonVisible: false,
                      leftChevronVisible: false, // Hide built-in arrows (we have custom ones above)
                      rightChevronVisible: false,
                      titleTextStyle: const TextStyle(
                        fontSize: 0, // Hide default title (we show it in selector)
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
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  // Show Month-Year Picker (Two-step: Year first, then Month)
  void _showMonthYearPicker(BuildContext context, StateSetter setDialogState) async {
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
                    child: const Icon(Icons.event_note_rounded, color: Colors.white, size: 18),
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
                    final isSelected = year == _focusedDay.year;
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
                                  colors: [Color(0xFFFF5252), Color(0xFFFF1744)],
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
                            color: isSelected ? Colors.redAccent : Colors.grey[300]!,
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
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                              color: isSelected ? Colors.white : Colors.grey[800],
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
      const months = ['January', 'February', 'March', 'April', 'May', 'June', 
                      'July', 'August', 'September', 'October', 'November', 'December'];
      
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
                      child: const Icon(Icons.calendar_today_rounded, color: Colors.white, size: 18),
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
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 2.5,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: 12,
                    itemBuilder: (context, index) {
                      final monthNum = index + 1;
                      final isSelected = monthNum == _focusedDay.month && selectedYear == _focusedDay.year;
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
                                    colors: [Color(0xFFFF5252), Color(0xFFFF1744)],
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
                              color: isSelected ? Colors.redAccent : Colors.grey[300]!,
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
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                color: isSelected ? Colors.white : Colors.grey[800],
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
          _focusedDay = DateTime(selectedYear!, selectedMonth!, 1);
        });
        setState(() {
          _focusedDay = DateTime(selectedYear!, selectedMonth!, 1);
        });
      }
    }
  }  // Get formatted date
  String _getFormattedDate() {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    return '${days[_currentTime.weekday % 7]}, ${months[_currentTime.month - 1]} ${_currentTime.day}, ${_currentTime.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // TBisita Logo
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Image.asset('assets/images/tbisita_logo2.png', height: 44),
              ),

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
                              color: Colors.white.withOpacity(random % 2 == 0 ? 0.9 : 0.6),
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
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.calendar_month_rounded, color: Colors.white, size: 14),
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
                                  Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 16),
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

              const SizedBox(height: 20),

              // Show bulk action icon only when in selection mode (entered via long-press)
              if (_isApprovedSelectionMode)
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8.0, right: 4.0),
                    child: IconButton(
                      iconSize: 36,
                      icon: Icon(
                        Icons.check_circle_outline_rounded,
                        color: _selectedApprovedAppointments.isNotEmpty ? Colors.orange : Colors.grey.shade300,
                      ),
                      onPressed: _selectedApprovedAppointments.isEmpty
                          ? null
                          : () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Mark as Incomplete Consultation'),
                                  content: Text('Are you sure you want to mark ${_selectedApprovedAppointments.length} appointment(s) as Incomplete consultation?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                    ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
                                  ],
                                ),
                              );

                              if (confirmed == true) {
                                try {
                                  for (final appointmentId in _selectedApprovedAppointments) {
                                    final doc = await FirebaseFirestore.instance.collection('approved_appointments').doc(appointmentId).get();
                                    if (!doc.exists) continue;
                                    final data = doc.data() as Map<String, dynamic>;

                                    final historyEntry = {
                                      ...data,
                                      'status': 'incomplete_consultation',
                                      'incompleteMarkedAt': FieldValue.serverTimestamp(),
                                      'source': 'appointment_history',
                                    };

                                    await FirebaseFirestore.instance.collection('appointment_history').add(historyEntry);
                                    await FirebaseFirestore.instance.collection('approved_appointments').doc(appointmentId).delete();
                                  }

                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('${_selectedApprovedAppointments.length} appointment(s) marked as Incomplete')),
                                    );
                                  }

                                  setState(() {
                                    _isApprovedSelectionMode = false;
                                    _selectedApprovedAppointments.clear();
                                  });
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error marking appointments: $e'), backgroundColor: Colors.red),
                                    );
                                  }
                                }
                              }
                            },
                    ),
                  ),
                ),

              StreamBuilder<QuerySnapshot>(
                key: const ValueKey('appointments_stream'),
                stream: _currentDoctorId != null
                    ? FirebaseFirestore.instance
                        .collection('approved_appointments')
                        .where('doctorId', isEqualTo: _currentDoctorId)
                        .snapshots()
                    : const Stream.empty(),
                builder: (context, snapshot) {
                  if (_currentDoctorId == null) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return const Center(child: Text('Something went wrong'));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final appointments = snapshot.data?.docs ?? [];
                  final newDates = <DateTime>[];

                  for (var doc in appointments) {
                    final data = doc.data() as Map<String, dynamic>;
                    if (data['doctorId'] == _currentDoctorId &&
                        data['appointmentDate'] != null) {
                      try {
                        DateTime appointmentDate;
                        if (data['appointmentDate'] is Timestamp) {
                          appointmentDate =
                              (data['appointmentDate'] as Timestamp).toDate();
                        } else {
                          appointmentDate = DateTime.parse(
                              data['appointmentDate'].toString());
                        }
                        final dateOnly = DateTime(appointmentDate.year,
                            appointmentDate.month, appointmentDate.day);
                        if (!newDates.any((d) => isSameDay(d, dateOnly))) {
                          newDates.add(dateOnly);
                        }
                      } catch (e) {
                        debugPrint('Error parsing appointment date: $e');
                      }
                    }
                  }

                  if (!_listsEqual(_appointmentDates, newDates)) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() {
                          _appointmentDates = newDates;
                        });
                      }
                    });
                  }

                  // Filter appointments based on _showAllAppointments
                  final filteredAppointments = _showAllAppointments
                      ? appointments
                      : appointments.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          if (data['appointmentDate'] == null) return false;
                          try {
                            final appointmentDate =
                                (data['appointmentDate'] as Timestamp).toDate();
                            return _selectedDay == null ||
                                isSameDay(appointmentDate, _selectedDay);
                          } catch (e) {
                            debugPrint('Error processing appointment date: $e');
                            return false;
                          }
                        }).toList();

                  if (filteredAppointments.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('No approved appointments found.'),
                      ),
                    );
                  }

                  return RepaintBoundary(
                    child: Column(
                      children: filteredAppointments.map((doc) {
                        final appointment = doc.data() as Map<String, dynamic>;
                        // Add document ID as appointmentId to ensure unique identification
                        appointment['appointmentId'] = doc.id;

                      // Enhanced date extraction with multiple field name support
                      DateTime? appointmentDate;

                      try {
                        dynamic dateField = appointment["appointmentDate"] ??
                            appointment["appointment_date"] ??
                            appointment["date"];

                        if (dateField != null) {
                          if (dateField is Timestamp) {
                            appointmentDate = dateField.toDate();
                          } else if (dateField is String) {
                            appointmentDate = DateTime.parse(dateField);
                          } else if (dateField is DateTime) {
                            appointmentDate = dateField;
                          }
                        }
                      } catch (e) {
                        debugPrint('Error parsing appointment date: $e');
                        debugPrint('Appointment data: $appointment');
                      }

                      // Enhanced time extraction with multiple field name support
                      String appointmentTime = appointment["appointmentTime"] ??
                          appointment["appointment_time"] ??
                          appointment["time"] ??
                          "No time";

                        return Container(
                          key: ValueKey(doc.id),
                          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                                spreadRadius: 0,
                              ),
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                if (_isApprovedSelectionMode) {
                                  setState(() {
                                    if (_selectedApprovedAppointments.contains(doc.id)) {
                                      _selectedApprovedAppointments.remove(doc.id);
                                      if (_selectedApprovedAppointments.isEmpty) {
                                        _isApprovedSelectionMode = false;
                                      }
                                    } else {
                                      _selectedApprovedAppointments.add(doc.id);
                                    }
                                  });
                                } else {
                                  _showAppointmentDetails(appointment);
                                }
                              },
                              onLongPress: () {
                                setState(() {
                                  _isApprovedSelectionMode = true;
                                  _selectedApprovedAppointments.add(doc.id);
                                });
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    // Selection Checkbox (visible only in selection mode)
                                    if (_isApprovedSelectionMode) ...[
                                      Checkbox(
                                        value: _selectedApprovedAppointments.contains(doc.id),
                                        onChanged: (val) {
                                          setState(() {
                                            if (val == true) {
                                              _selectedApprovedAppointments.add(doc.id);
                                            } else {
                                              _selectedApprovedAppointments.remove(doc.id);
                                              if (_selectedApprovedAppointments.isEmpty) {
                                                _isApprovedSelectionMode = false;
                                              }
                                            }
                                          });
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    // DATE AVATAR
                                    Container(
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
                                          appointmentDate != null
                                              ? appointmentDate.day.toString()
                                              : "?",
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
                                    ),
                                    const SizedBox(width: 14),
                                    // CONTENT
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // TIME (BOLD)
                                          Text(
                                            appointmentTime,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF1A1A1A),
                                              letterSpacing: -0.3,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          // PATIENT NAME
                                          Text(
                                            appointment["patientName"] ?? "Unknown Patient",
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // CHEVRON ICON
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: Colors.grey[400],
                                      size: 24,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
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
      final dynamic appointmentDate = appointment["appointmentDate"];
      if (appointmentDate is Timestamp) {
        date = appointmentDate.toDate();
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

  // Helper method to build video call card (join only for approved appointments)
  Widget _buildVideoCallCard({
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
                  const SizedBox(width: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  // Join Video Call button directly in the header
                  if (appointment["roomId"] != null &&
                      appointment["roomId"].toString().isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          print('🎥 Join Video Call button pressed');

                          // Check permissions before starting video call
                          print(
                              '🔒 Requesting camera and microphone permissions...');
                          final webrtcService = WebRTCService();
                          bool hasPermissions =
                              await webrtcService.requestPermissions();
                          print('🔒 Permission result: $hasPermissions');

                          if (!hasPermissions) {
                            print(
                                '❌ Permissions not granted, showing error message');
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

                          print(
                              '✅ Permissions granted, navigating to video call screen');
                          // Navigate to WebRTC video call screen with fullscreen modal
                          await Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute(
                              fullscreenDialog: true,
                              builder: (context) => VideoCallScreen(
                                appointmentId:
                                    appointment['appointmentId'] ?? '',
                                patientName:
                                    appointment['patientName'] ?? 'Patient',
                                roomId: appointment['roomId'],
                                isDoctorCalling: true,
                                onCallEnded: () {
                                  print('Video call ended callback triggered');
                                  if (mounted) {
                                    print(
                                        'Doctor landing page is mounted, refreshing...');
                                    setState(() {
                                      // Force refresh of the landing page
                                    });
                                    print('Doctor landing page refreshed');
                                  } else {
                                    print('Doctor landing page is not mounted');
                                  }
                                },
                              ),
                            ),
                          );

                          // Refresh the page after returning from video call
                          print('Returned from video call screen');
                          if (mounted) {
                            print(
                                'Refreshing doctor landing page after return');
                            setState(() {
                              // Trigger a rebuild to refresh the UI
                            });
                          }
                        } catch (e) {
                          print('💥 Error in video call process: $e');

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
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF0A84FF)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      icon: const Icon(Icons.video_call,
                          color: Color(0xFF0A84FF), size: 16),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12.0, vertical: 10),
                        child: Text(
                          "Join Video Call",
                          style: const TextStyle(color: Color(0xFF0A84FF)),
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.link_off,
                              color: Colors.grey.shade600, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            "No video call room available",
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
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
    );
  }

  // Helper method to build prescription card with new UI
  Widget _buildPrescriptionCard(Map<String, dynamic> appointment) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('prescriptions')
          .where('appointmentId', isEqualTo: appointment['appointmentId'])
          .snapshots(),
      builder: (context, snapshot) {
        bool hasPrescription = false;

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          hasPrescription = true;
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
                        "E-Prescription",
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasPrescription
                            ? "Prescription available for viewing"
                            : "Upload prescription for patient",
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    Prescription(appointment: appointment),
                              ),
                            );
                          },
                          icon: Icon(
                            hasPrescription ? Icons.visibility : Icons.add,
                            size: 20,
                          ),
                          label: Text(
                            hasPrescription
                                ? "View Prescription"
                                : "Add Prescription",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade600,
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

  // Helper method to build timeline card
  Widget _buildTimelineCard(Map<String, dynamic> appointment) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('prescriptions')
          .where('appointmentId', isEqualTo: appointment['appointmentId'])
          .snapshots(),
      builder: (context, snapshot) {
        bool hasPrescription = false;

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          hasPrescription = true;
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
                                true, // This should be true for approved appointments
                          ),
                          const SizedBox(height: 8),
                          _buildStepInstruction(
                            stepNumber: '3',
                            instruction:
                                'Consultation completed with prescription issued',
                            isCompleted:
                                hasPrescription, // Now checks if prescription exists
                          ),
                          const SizedBox(height: 8),
                          _buildStepInstruction(
                            stepNumber: '4',
                            instruction:
                                'Treatment completion certificate delivered',
                            isCompleted: false,
                          ),
                          const SizedBox(height: 8),
                          _buildStepInstruction(
                            stepNumber: '5',
                            instruction: 'Full TB treatment program completed',
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
}

// Custom painter for mountain silhouette
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
