import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/chat_service.dart'; // your ChatService

class MyAppointmentPage extends StatefulWidget {
  const MyAppointmentPage({super.key});

  @override
  State<MyAppointmentPage> createState() => _MyAppointmentPageState();
}

class _MyAppointmentPageState extends State<MyAppointmentPage> {
  final ChatService _chatService = ChatService();

  // TODO: replace this with FirebaseAuth.instance.currentUser!.uid when you add auth
  final String currentUserId = "patient123";

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  int _selectedYear = DateTime.now().year;

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

  final List<int> _years =
      List.generate(11, (index) => DateTime.now().year - 5 + index);

  // Appointments (mock). Make sure doctorId exists in your doctors/users collection.
  final List<Map<String, dynamic>> _appointments = [
    {
      "date": DateTime.now(),
      "status": "Approved",
      "doctorId": "doctor123",
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
      "doctorId": "doctor456",
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
  }

  String _monthName(int month) => _months[month - 1];

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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    appointment["status"],
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: appointment["status"] == "Approved"
                          ? Colors.green
                          : Colors.orange,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chat),
                    onPressed: () => _showChatPopup(
                      appointment["doctorId"],
                      appointment["doctorName"],
                    ),
                  ),
                ],
              ),
              const Divider(),
              Text("Doctor: ${appointment["doctorName"]}",
                  style: const TextStyle(fontSize: 16)),
              Text("TB Facility: ${appointment["facility"]}"),
              Text("Experience: ${appointment["experience"]}"),
              const SizedBox(height: 10),
              const Text("Schedule:",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text(
                  "${appointment["date"].toString().split(" ")[0]} at ${appointment["time"]}"),
              const SizedBox(height: 10),
              if ((appointment["meetingLink"] as String).isNotEmpty)
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.video_call),
                  label: const Text("Join Meeting"),
                ),
              const SizedBox(height: 10),
              const Text("E-Prescription:",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              appointment["ePrescription"] != null
                  ? Text(appointment["ePrescription"])
                  : const Text("No e-prescription available yet."),
            ],
          ),
        ),
      ),
    );
  }

  // Chat popup integrated with ChatService
  void _showChatPopup(String doctorId, String doctorName) {
    final TextEditingController messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Message to $doctorName"),
        content: TextField(
          controller: messageController,
          autofocus: true,
          decoration: const InputDecoration(hintText: "Type your message..."),
        ),
        actions: [
          TextButton(
            onPressed: () {
              messageController.dispose();
              Navigator.pop(context);
            },
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final text = messageController.text.trim();
              if (text.isEmpty) {
                // nothing to send
                return;
              }

              // Use ChatService.generateChatId and sendTextMessage
              final chatId =
                  _chatService.generateChatId(currentUserId, doctorId);

              try {
                await _chatService.sendTextMessage(
                  senderId: currentUserId,
                  receiverId: doctorId,
                  text: text,
                );

                // optional: show confirmation
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Message sent')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to send message: $e')),
                  );
                }
              } finally {
                messageController.dispose();
                Navigator.pop(context);
              }
            },
            child: const Text("Send"),
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
              ..._appointments
                  .where((a) =>
                      _selectedDay == null ||
                      isSameDay(a["date"], _selectedDay))
                  .map((appointment) {
                final date = appointment["date"] as DateTime;
                final statusColor = appointment["status"] == "Approved"
                    ? Colors.green
                    : Colors.orange;
                return Card(
                  color: Colors.white,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _showAppointmentDetails(appointment),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
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
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text("${date.day}",
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold)),
                                Text(_monthName(date.month),
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 12)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(appointment["doctorName"],
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue)),
                                Text(appointment["facility"],
                                    style: const TextStyle(color: Colors.grey)),
                                Text(appointment["status"],
                                    style: TextStyle(
                                        color: statusColor,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          const Icon(Icons.more_vert, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }
}
