import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';

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

  @override
  void initState() {
    super.initState();
    _selectedMonth = _months[DateTime.now().month - 1];
    _getCurrentPatientId();
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
        data['id'] = doc.id;
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
        data['id'] = doc.id;
        allAppointments.add(data);
      }

      return allAppointments;
    });
  }

  String _monthName(int month) => _months[month - 1];

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

  void _showAppointmentDetails(Map<String, dynamic> appointment) {
    // Debug: Print all available fields in the appointment data
    debugPrint('=== APPOINTMENT DEBUG INFO ===');
    debugPrint('All appointment data: $appointment');
    debugPrint('Available keys: ${appointment.keys.toList()}');
    debugPrint('Doctor Name: ${appointment['doctorName']}');
    debugPrint('Doctor name alt: ${appointment['doctor_name']}');
    debugPrint('Time: ${appointment['appointment_time']}');
    debugPrint('Time alt: ${appointment['appointmentTime']}');
    debugPrint('Meeting Link: ${appointment['meetingLink']}');
    debugPrint('Jitsi Link: ${appointment['jitsi_link']}');
    debugPrint('Meeting Link alt: ${appointment['meeting_link']}');
    debugPrint('Status: ${appointment['status']}');
    debugPrint('===============================');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Appointment Details',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xE0F44336),
                    ),
                  ),
         
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Doctor Name
                    _buildDetailRow(
                      'Doctor:',
                      appointment['doctorName'] ??
                          appointment['doctor_name'] ??
                          'Not available',
                      Icons.person,
                    ),
                    const SizedBox(height: 16),

                    // Date
                    _buildDetailRow(
                      'Date:',
                      appointment['date'] != null
                          ? '${appointment['date'].day}/${appointment['date'].month}/${appointment['date'].year}'
                          : (appointment['appointmentDate'] != null
                              ? _formatDate(appointment['appointmentDate'])
                              : (appointment['appointment_date'] != null
                                  ? _formatDate(appointment['appointment_date'])
                                  : 'Not set')),
                      Icons.calendar_today,
                    ),
                    const SizedBox(height: 16),

                    // Time
                    _buildDetailRow(
                      'Time:',
                      appointment['appointment_time'] ??
                          appointment['appointmentTime'] ??
                          appointment['time'] ??
                          'Not set',
                      Icons.access_time,
                    ),
                    const SizedBox(height: 16),

                    // Status - Green for approved, grey for others
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            (appointment['status']?.toString().toLowerCase() ==
                                    'approved')
                                ? Colors.green.shade50
                                : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: (appointment['status']
                                      ?.toString()
                                      .toLowerCase() ==
                                  'approved')
                              ? Colors.green.shade200
                              : Colors.grey.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            (appointment['status']?.toString().toLowerCase() ==
                                    'approved')
                                ? Icons.check_circle
                                : Icons.pending,
                            color: (appointment['status']
                                        ?.toString()
                                        .toLowerCase() ==
                                    'approved')
                                ? Colors.green.shade600
                                : Colors.grey.shade600,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Status: ${appointment['status']?.toString().toUpperCase() ?? 'UNKNOWN'}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: (appointment['status']
                                          ?.toString()
                                          .toLowerCase() ==
                                      'approved')
                                  ? Colors.green.shade800
                                  : Colors.grey.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Meeting Link - Always show for debugging
                    Builder(
                      builder: (context) {
                        final meetingLink = appointment['meetingLink'] ??
                            appointment['jitsi_link'] ??
                            appointment['meeting_link'];

                        debugPrint('Meeting link found: $meetingLink');

                        if (meetingLink != null &&
                            meetingLink.toString().isNotEmpty) {
                          return Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 16),
                            child: ElevatedButton.icon(
                              onPressed: () =>
                                  _launchUrl(meetingLink.toString()),
                              icon: const Icon(Icons.videocam,
                                  color: Colors.white),
                              label: const Text('Join Meeting',
                                  style: TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          );
                        } else {
                          return Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info,
                                    color: Colors.grey.shade600, size: 20),
                                const SizedBox(width: 8),
                                const Text(
                                  'Meeting link not yet available',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          );
                        }
                      },
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

  Widget _buildDetailRow(String label, String value, IconData icon,
      {Color? statusColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: statusColor ?? Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.black, fontSize: 14),
              children: [
                TextSpan(
                  text: '$label ',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(
                  text: value,
                  style: TextStyle(
                    color: statusColor ?? Colors.black87,
                    fontWeight: statusColor != null
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _launchUrl(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open the meeting link')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening link: $e')),
        );
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

              // Calendar
              Container(
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
                    // Custom builder for days with appointments
                    defaultBuilder: (context, day, focusedDay) {
                      if (_getEventsForDay(day).isNotEmpty) {
                        return Container(
                          margin: const EdgeInsets.all(4.0),
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
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

                    if (allAppointments.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text(
                            'No appointments found',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      );
                    }

                    return Column(
                      children: allAppointments.map((appointment) {
                        // Determine status - check if it's from approved collection
                        final isApproved =
                            appointment['status'] == 'approved' ||
                                appointment['approvedAt'] != null;
                        final status = isApproved ? 'Approved' : 'Pending';
                        final statusColor =
                            isApproved ? Colors.green : Colors.orange;

                        DateTime? date;
                        try {
                          final appointmentDate =
                              appointment['appointment_date'];
                          if (appointmentDate is Timestamp) {
                            date = appointmentDate.toDate();
                          } else {
                            date = DateTime.parse(appointmentDate.toString());
                          }
                        } catch (e) {
                          debugPrint('Error parsing date: $e');
                        }

                        return Container(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.shade200,
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => _showAppointmentDetails({
                                ...appointment,
                                'status': status,
                                'date': date,
                              }),
                              child: Row(
                                children: [
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: statusColor,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text("${date?.day ?? '?'}",
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold)),
                                        Text(
                                            date != null
                                                ? _monthName(date.month)
                                                : '',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Doctor name - use doctorName field directly
                                        Text(
                                          appointment['doctorName'] ??
                                              appointment['doctor_name'] ??
                                              'Not available',
                                          style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue),
                                        ),
                                        Text(
                                            "Time: ${appointment['appointment_time'] ?? appointment['appointmentTime'] ?? appointment['time'] ?? 'Not set'}",
                                            style: const TextStyle(
                                                color: Colors.grey)),
                                        Text(status,
                                            style: TextStyle(
                                                color: statusColor,
                                                fontWeight: FontWeight.bold)),

                                        // Meeting link indicator for approved appointments
                                        if (isApproved &&
                                            ((appointment['meetingLink'] ??
                                                        appointment[
                                                            'jitsi_link'] ??
                                                        appointment[
                                                            'meeting_link']) !=
                                                    null &&
                                                (appointment['meetingLink'] ??
                                                        appointment[
                                                            'jitsi_link'] ??
                                                        appointment[
                                                            'meeting_link'])
                                                    .toString()
                                                    .isNotEmpty))
                                          Container(
                                            margin:
                                                const EdgeInsets.only(top: 4),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              border: Border.all(
                                                  color: Colors.blue.shade200),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.videocam,
                                                  size: 12,
                                                  color: Colors.blue.shade600,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Meeting Available',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.blue.shade600,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.grey,
                            size: 18,
                          ),
                                ],
                              ),
                            ));
                      }).toList(),
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
            ],
          ),
        ),
      ),
    );
  }
}
