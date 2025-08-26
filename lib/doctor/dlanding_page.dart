import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

class Dlandingpage extends StatefulWidget {
  const Dlandingpage({super.key});

  @override
  State<Dlandingpage> createState() => _DlandingpageState();
}

class _DlandingpageState extends State<Dlandingpage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.week;

  final List<String> _months = [
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December"
  ];

  late String _selectedMonth;
  late int _selectedYear;
  final List<int> _years = List.generate(20, (index) => DateTime.now().year - 5 + index);

  final List<Map<String, dynamic>> _appointments = [
    {
      "date": DateTime.now(),
      "status": "Approved",
      "doctorName": "Dr. Maria Santos",
      "facility": "Agdao TB DOTS",
      "experience": "10 years",
      "time": "10:00 AM",
      "meetingLink": "https://meet.example.com/abc123",
      "ePrescription": "Take medicine 2x a day for 14 days"
    },
    {
      "date": DateTime.now().add(const Duration(days: 1)),
      "status": "Pending",
      "doctorName": "Dr. Juan Dela Cruz",
      "facility": "Buhangin TB DOTS",
      "experience": "7 years",
      "time": "2:00 PM",
      "meetingLink": "",
      "ePrescription": null
    },
  ];

  @override
  void initState() {
    super.initState();
    _selectedMonth = _months[_focusedDay.month - 1];
    _selectedYear = _focusedDay.year;
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
            crossAxisAlignment: CrossAxisAlignment.start,
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
              const SizedBox(height: 10),
              Text("Doctor: ${appointment["doctorName"]}", style: const TextStyle(fontWeight: FontWeight.bold)),
              Text("Facility: ${appointment["facility"]}"),
              Text("Status: ${appointment["status"]}"),
              Text("Schedule: ${appointment["date"].toString().split(' ')[0]} at ${appointment["time"]}"),
              const SizedBox(height: 10),
              if (appointment["meetingLink"].isNotEmpty)
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.video_call),
                  label: const Text("Join Meeting"),
                ),
              const SizedBox(height: 10),
              Text("E-Prescription: ${appointment["ePrescription"] ?? "N/A"}"),
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
                child: Image.asset('assets/images/tbisita_logo2.png', height: 44),
              ),
              // Month & Year Header aligned with Calendar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
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
                          items: _months.map((month) => DropdownMenuItem(
                            value: month,
                            child: Text(month, style: const TextStyle(fontWeight: FontWeight.bold)),
                          )).toList(),
                          onChanged: (month) {
                            if (month != null) {
                              setState(() {
                                _selectedMonth = month;
                                final monthIndex = _months.indexOf(month) + 1;
                                _focusedDay = DateTime(_selectedYear, monthIndex, 1);
                              });
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        DropdownButton<int>(
                          value: _selectedYear,
                          items: _years.map((year) => DropdownMenuItem(
                            value: year,
                            child: Text(year.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                          )).toList(),
                          onChanged: (year) {
                            if (year != null) {
                              setState(() {
                                _selectedYear = year;
                                final monthIndex = _months.indexOf(_selectedMonth) + 1;
                                _focusedDay = DateTime(_selectedYear, monthIndex, 1);
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
                    todayDecoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                    selectedDecoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                    outsideTextStyle: const TextStyle(color: Colors.grey),
                    weekendTextStyle: const TextStyle(color: Colors.redAccent),
                    defaultTextStyle: const TextStyle(color: Colors.black),
                  ),
                  daysOfWeekStyle: const DaysOfWeekStyle(
                    weekendStyle: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                    weekdayStyle: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Appointments (only Approved)
              Column(
                children: _appointments
                    .where((a) => a["status"] == "Approved" && (_selectedDay == null || isSameDay(a["date"], _selectedDay)))
                    .map((appointment) {
                  final date = appointment["date"] as DateTime;
                  return Card(
                    color: Colors.white,
                    elevation: 3,
                    margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      onTap: () => _showAppointmentDetails(appointment),
                      leading: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(8)),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text("${date.day}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              Text(_months[date.month - 1].substring(0, 3), style: const TextStyle(color: Colors.white, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                      title: Text(appointment["doctorName"], style: const TextStyle(color: Colors.blue)),
                      subtitle: Text("${appointment["facility"]} - ${appointment["status"]}", style: const TextStyle(color: Colors.green)),
                      trailing: const Icon(Icons.more_vert),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
