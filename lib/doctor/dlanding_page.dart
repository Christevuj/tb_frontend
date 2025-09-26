import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'prescription.dart';

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
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, controller) => Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            controller: controller,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    height: 5,
                    width: 50,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                Center(
                  child: const Text(
                    "Appointment Details",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 20),

                // Patient Name
                _infoCard(
                  icon: Icons.person,
                  iconBg: Colors.blue,
                  cardBg: Colors.blue.shade50,
                  value: appointment["patientName"]?.toString() ?? "N/A",
                  label: "Patient Name",
                ),

                // Appointment Date & Time
                _infoCard(
                  icon: Icons.calendar_today,
                  iconBg: Colors.indigo,
                  cardBg: Colors.indigo.shade50,
                  value: appointment["appointmentDate"] != null
                      ? "${(appointment["appointmentDate"] as Timestamp).toDate().toLocal()}"
                          .split(' ')[0]
                      : "N/A",
                  label: "Appointment Date",
                ),
                _infoCard(
                  icon: Icons.access_time,
                  iconBg: Colors.amber,
                  cardBg: Colors.amber.shade50,
                  value: appointment["appointmentTime"]?.toString() ?? "N/A",
                  label: "Appointment Time",
                ),

                // Status
                _statusCard(appointment["status"]?.toString() ?? "N/A"),

                // Meeting Link
                if (appointment["meetingLink"] != null &&
                    appointment["meetingLink"].toString().isNotEmpty)
                  _meetingCard(
                    url: appointment["meetingLink"].toString(),
                    onJoin: () async {
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
                  )
                else
                  _infoCard(
                    icon: Icons.link_off,
                    iconBg: Colors.grey,
                    cardBg: Colors.grey.shade200,
                    value: "No meeting link",
                    label: "Meeting Link",
                  ),

                // Prescription Container
                _prescriptionCard(appointment),

                // Done Meeting Button
                _doneMeetingButton(appointment),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Styled info card (matches screenshot style)
  Widget _infoCard({
    required IconData icon,
    required Color iconBg,
    required Color cardBg,
    required String value,
    required String label,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center, // <-- Center vertically
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              // <-- Center the icon
              child: Icon(icon, color: Colors.white, size: 24),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusCard(String statusRaw) {
    final status = statusRaw.toUpperCase();
    final bool isApproved = status == 'APPROVED';
    final bool isPending = status == 'PENDING';
    final bool isCancelled = status == 'CANCELLED';

    Color chipBg;
    Color chipText;
    Color cardBg;

    if (isApproved) {
      chipBg = Colors.green.shade100;
      chipText = Colors.green.shade800;
      cardBg = Colors.green.shade50;
    } else if (isPending) {
      chipBg = Colors.amber.shade100;
      chipText = Colors.amber.shade800;
      cardBg = Colors.amber.shade50;
    } else if (isCancelled) {
      chipBg = Colors.red.shade100;
      chipText = Colors.red.shade800;
      cardBg = Colors.red.shade50;
    } else {
      chipBg = Colors.blueGrey.shade100;
      chipText = Colors.blueGrey.shade800;
      cardBg = Colors.blueGrey.shade50;
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center, // <-- Center vertically
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.green.shade500,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              // <-- Center the icon
              child: Icon(Icons.check_circle, color: Colors.white, size: 24),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: chipBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status[0].toUpperCase() + status.substring(1).toLowerCase(),
                    style: TextStyle(
                      color: chipText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Appointment Status",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _meetingCard({required String url, required VoidCallback onJoin}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center, // <-- Center vertically
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.blue.shade500,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              // <-- Center the icon
              child: Icon(Icons.videocam, color: Colors.white, size: 24),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ElevatedButton.icon(
                  onPressed: onJoin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.blue.shade700,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: Colors.blue.shade200),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text(
                    'Join Meeting',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Tap to join the online consultation",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _prescriptionCard(Map<String, dynamic> appointment) {
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

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color:
                hasPrescription ? Colors.green.shade50 : Colors.orange.shade50,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: hasPrescription
                      ? Colors.green.shade500
                      : Colors.orange.shade500,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(
                    hasPrescription
                        ? Icons.medical_services
                        : Icons.description,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasPrescription) ...[
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  Prescription(appointment: appointment),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.green.shade700,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: Colors.green.shade200),
                          ),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.visibility, size: 18),
                        label: const Text(
                          'View Prescription',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Prescription uploaded successfully",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ] else ...[
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  Prescription(appointment: appointment),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.orange.shade700,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: Colors.orange.shade200),
                          ),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text(
                          'Add Prescription',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "No prescription uploaded yet",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ]
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _doneMeetingButton(Map<String, dynamic> appointment) {
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
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 12),
          child: ElevatedButton(
            onPressed: hasPrescription
                ? () async {
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

                      // Remove the appointment from approved_appointments (this removes it from both patient and doctor views)
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
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: hasPrescription
                  ? Colors.green.shade600
                  : Colors.grey.shade400,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: hasPrescription ? 3 : 0,
            ),
            child: Text(
              hasPrescription ? 'DONE MEETING' : 'UPLOAD PRESCRIPTION FIRST',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
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
                      return Card(
                        color: Colors.white,
                        elevation: 3,
                        margin: const EdgeInsets.symmetric(
                            vertical: 6, horizontal: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          onTap: () => _showAppointmentDetails(appointment),
                          leading: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    appointment["appointmentDate"] != null
                                        ? "${(appointment["appointmentDate"] as Timestamp).toDate().day}"
                                        : "--",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    appointment["appointmentDate"] != null
                                        ? _months[
                                                (appointment["appointmentDate"]
                                                            as Timestamp)
                                                        .toDate()
                                                        .month -
                                                    1]
                                            .substring(0, 3)
                                        : "---",
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          title: Text(
                            appointment["patientName"] ?? "N/A",
                            style: const TextStyle(color: Colors.blue),
                          ),
                          subtitle: Text(
                            "${appointment["appointmentTime"] ?? "No time"} - ${appointment["status"]}",
                            style: const TextStyle(color: Colors.green),
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.grey,
                            size: 18,
                          ),
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
}
