import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'prescription.dart';
import '../services/chat_service.dart';
import '../chat_screens/chat_screen.dart';

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
  bool _isMeetingLinkExpanded = false;

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
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.teal.shade50,
                    Colors.white,
                  ],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                                setModalState(() {
                                  _isPatientInfoExpanded = !_isPatientInfoExpanded;
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

                            // Meeting Link Section - Join Only for Approved
                            _buildMeetingLinkCard(
                              title: "Meeting Link",
                              subtitle: "Join online consultation",
                              isExpanded: _isMeetingLinkExpanded,
                              onToggle: () {
                                setModalState(() {
                                  _isMeetingLinkExpanded = !_isMeetingLinkExpanded;
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

              // Complete Meeting button when prescription exists
              if (hasPrescription)
                Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.green.shade400,
                        Colors.green.shade600
                      ],
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
              // Logo
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child:
                    Image.asset('assets/images/tbisita_logo2.png', height: 44),
              ),

              // Month & Year Header aligned with Calendar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                padding:
                    const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white,
                ),
                child: Row(
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
              ),

              const SizedBox(height: 12),

              // Calendar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey[100],
                ),
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
                      if (_showAllAppointments &&
                          _getEventsForDay(selectedDay).isEmpty) {
                        _showAllAppointments = false;
                      }
                    });
                  },
                  onFormatChanged: (format) {
                    setState(() {
                      _calendarFormat = format;
                    });
                  },
                  onPageChanged: (focusedDay) {
                    setState(() {
                      _focusedDay = focusedDay;
                      _selectedMonth = _months[focusedDay.month - 1];
                      _selectedYear = focusedDay.year;
                    });
                  },
                  headerVisible: false,
                  daysOfWeekHeight: 30,
                  calendarStyle: const CalendarStyle(
                    todayDecoration: BoxDecoration(
                        color: Colors.green, shape: BoxShape.circle),
                    selectedDecoration: BoxDecoration(
                        color: Colors.blueAccent, shape: BoxShape.circle),
                    outsideTextStyle: TextStyle(color: Colors.grey),
                    weekendTextStyle: TextStyle(color: Colors.redAccent),
                    defaultTextStyle: TextStyle(color: Colors.black),
                    markersMaxCount: 0,
                    canMarkersOverflow: false,
                  ),
                  calendarBuilders: CalendarBuilders(
                    defaultBuilder: (context, day, focusedDay) {
                      if (_getEventsForDay(day).isNotEmpty) {
                        return Container(
                          margin: const EdgeInsets.all(4.0),
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${day.day}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      }
                      return null;
                    },
                    todayBuilder: (context, day, focusedDay) {
                      return Container(
                        margin: const EdgeInsets.all(4.0),
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${day.day}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  daysOfWeekStyle: const DaysOfWeekStyle(
                    weekendStyle: TextStyle(
                        color: Colors.redAccent, fontWeight: FontWeight.bold),
                    weekdayStyle: TextStyle(
                        color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // See All button and Appointments (only Approved for current doctor)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _showAllAppointments = !_showAllAppointments;
                      });
                    },
                    child: Text(_showAllAppointments ? 'Show Less' : 'See All'),
                  ),
                ],
              ),

              StreamBuilder<QuerySnapshot>(
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

                  return Column(
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

                      return Card(
                        color: Colors.white,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                        child: ListTile(
                          onTap: () => _showAppointmentDetails(appointment),
                          leading: CircleAvatar(
                            backgroundColor: Colors.redAccent,
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
                            appointment["patientName"] ?? "Unknown Patient",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                appointmentDate != null
                                    ? "${appointmentDate.day}/${appointmentDate.month}/${appointmentDate.year} at $appointmentTime"
                                    : "$appointmentTime",
                              ),
                              Text(
                                "Approved",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.redAccent,
                                ),
                              ),
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right,
                              color: Colors.grey),
                        ),
                      );
                    }).toList(),
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
                          : const SizedBox.shrink(),
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

  // Helper method to build meeting link card (join only for approved appointments)
  Widget _buildMeetingLinkCard({
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
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  // Join Meeting button directly in the header
                  if (appointment["meetingLink"] != null &&
                      appointment["meetingLink"].toString().isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () async {
                        final Uri uri =
                            Uri.parse(appointment["meetingLink"].toString());
                        try {
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri,
                                mode: LaunchMode.externalApplication);
                          } else {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text("Could not launch meeting link")),
                              );
                            }
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Error: $e")),
                            );
                          }
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF0A84FF)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      icon: const Icon(Icons.video_call, color: Color(0xFF0A84FF), size: 16),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10),
                        child: Text(
                          "Join Meeting",
                          style: const TextStyle(color: Color(0xFF0A84FF)),
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.link_off, color: Colors.grey.shade600, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            "No meeting link available",
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
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
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
                            hasPrescription ? "View Prescription" : "Add Prescription",
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
                            instruction: 'Patient requested appointment with a Doctor',
                            isCompleted: true,
                          ),
                          const SizedBox(height: 8),
                          _buildStepInstruction(
                            stepNumber: '2',
                            instruction: 'Doctor confirmed and approved the appointment schedule',
                            isCompleted: true, // This should be true for approved appointments
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
