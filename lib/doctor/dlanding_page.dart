import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  height: 5,
                  width: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.person, color: Colors.purple),
                title: Text(appointment["patientName"]?.toString() ?? "N/A"),
                subtitle: const Text("Patient Name"),
              ),
              ListTile(
                leading: const Icon(Icons.access_time, color: Colors.orange),
                title:
                    Text(appointment["appointmentTime"]?.toString() ?? "N/A"),
                subtitle: const Text("Appointment Time"),
              ),
              ListTile(
                leading: const Icon(Icons.medical_services, color: Colors.blue),
                title: Text(appointment["doctorName"]?.toString() ?? "N/A"),
                subtitle: const Text("Doctor Name"),
              ),

              // Fetch address and experience from doctors collection
              FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('doctors')
                    .doc(appointment["doctorId"])
                    .get(),
                builder: (context, snapshot) {
                  String address = "Loading address...";
                  String experience = "Loading experience...";

                  if (snapshot.hasData && snapshot.data!.exists) {
                    final doctorData =
                        snapshot.data!.data() as Map<String, dynamic>;

                    // Get address from affiliations array if it exists
                    if (doctorData["affiliations"] != null &&
                        (doctorData["affiliations"] as List).isNotEmpty) {
                      address = (doctorData["affiliations"][0]["address"] ??
                              "No address available")
                          .toString();
                    } else {
                      address = "No address available";
                    }

                    // Get experience from doctor data - improved formatting
                    if (doctorData["experience"] != null) {
                      experience = "${doctorData["experience"]} years";
                    } else {
                      experience = "No experience data";
                    }
                  } else if (snapshot.hasError) {
                    address = "Error loading address";
                    experience = "Error loading experience";
                  }

                  return Column(
                    children: [
                      ListTile(
                        leading:
                            const Icon(Icons.location_on, color: Colors.red),
                        title: Text(address),
                        subtitle: const Text("Address"),
                      ),
                      ListTile(
                        leading: const Icon(Icons.work, color: Colors.teal),
                        title: Text(
                            experience), // Now includes "years" in the string
                        subtitle: const Text("Experience"),
                      ),
                    ],
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: Text(
                    appointment["status"]?.toString().toUpperCase() ?? "N/A"),
                subtitle: const Text("Status"),
              ),

              // Meeting Link
              if (appointment["meetingLink"] != null &&
                  appointment["meetingLink"].toString().isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.videocam, color: Colors.blue),
                  title: InkWell(
                    onTap: () async {
                      // Launch the meeting link
                      final Uri uri = Uri.parse(appointment["meetingLink"]);
                      try {
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri,
                              mode: LaunchMode.externalApplication);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Could not launch meeting link')),
                          );
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    },
                    child: Text(
                      appointment["meetingLink"],
                      style: const TextStyle(
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  subtitle: const Text("Meeting Link (Tap to join)"),
                )
              else
                const ListTile(
                  leading: Icon(Icons.link_off, color: Colors.grey),
                  title: Text("No meeting link available"),
                  subtitle: Text("Meeting Link"),
                ),
            ],
          ),
        ),
      ),
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
                  calendarStyle: CalendarStyle(
                    todayDecoration: const BoxDecoration(
                        color: Colors.green, shape: BoxShape.circle),
                    selectedDecoration: const BoxDecoration(
                        color: Colors.blueAccent, shape: BoxShape.circle),
                    outsideTextStyle: const TextStyle(color: Colors.grey),
                    weekendTextStyle: const TextStyle(color: Colors.redAccent),
                    defaultTextStyle: const TextStyle(color: Colors.black),
                    // Remove marker decorations since we'll use calendarBuilders
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
              // Appointments (only Approved for current doctor)
              StreamBuilder<QuerySnapshot>(
                stream: _currentDoctorId != null
                    ? FirebaseFirestore.instance
                        .collection('approved_appointments')
                        .where('doctorId', isEqualTo: _currentDoctorId)
                        .snapshots()
                    : const Stream.empty(),
                builder: (context, snapshot) {
                  // Show loading if doctor ID is not available yet
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

                  // Update appointment dates when data actually changes (not every rebuild)
                  final newDates = <DateTime>[];
                  for (var doc in appointments) {
                    final data = doc.data() as Map<String, dynamic>;
                    // Only process appointments for current doctor
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

                  // Only update if dates actually changed
                  if (!_listsEqual(_appointmentDates, newDates)) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() {
                          _appointmentDates = newDates;
                        });
                      }
                    });
                  }

                  final filteredAppointments = appointments.where((doc) {
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

                  return Column(
                    children: filteredAppointments.map((doc) {
                      final appointment = doc.data() as Map<String, dynamic>;

                      return Card(
                        color: Colors.white,
                        elevation: 3,
                        margin: const EdgeInsets.symmetric(
                            vertical: 6, horizontal: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          onTap: () => _showAppointmentDetails(appointment),
                          leading: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(8)),
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
                                        fontWeight: FontWeight.bold),
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
                          trailing: const Icon(Icons.more_vert),
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
