// Core Flutter imports
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// Dart imports
import 'dart:async';
import 'dart:typed_data';
import 'dart:io' show File;
import 'dart:convert';
import 'package:http/http.dart' as http;

// Package imports
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Local imports
import 'package:tb_frontend/models/doctor.dart';
import 'package:tb_frontend/services/auth_service.dart';

class Pbooking1 extends StatefulWidget {
  final Doctor doctor;

  const Pbooking1({
    super.key,
    required this.doctor,
  });

  @override
  State<Pbooking1> createState() => _Pbooking1State();
}

class _Pbooking1State extends State<Pbooking1> {
  // Import AuthService
  final _authService = AuthService();
  // Controllers for patient details
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();

  // Dropdown selections
  String? _selectedGender;
  String? _selectedID;
  DateTime? _selectedDate;
  String? _selectedTime;
  XFile? _idImage;
  Uint8List? _webImage;

  final List<String> _genders = ['Select gender', 'Male', 'Female', 'Other'];
  final List<String> _validIDs = [
    'Select Valid ID',
    'Passport',
    'Driver\'s License',
    'National ID (PhilID)',
    'SSS ID',
    'School ID',
    'Barangay ID',
    'PWD ID',
    'Senior Citizen ID',
    'PRC ID',
    'PhilHealth ID',
    'UMID'
        'Postal ID',
  ];



  @override
  void initState() {
    super.initState();
    // Set default values
    _selectedGender = null;
    _selectedID = null;
    _selectedTime = null;

    // Pre-fill name and email from Firestore user data
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _emailController.text = user.email ?? '';
      _authService.getCurrentUserDetails().then((details) {
        if (details != null) {
          final firstName = details['firstName'] ?? '';
          final lastName = details['lastName'] ?? '';
          setState(() {
            _nameController.text = (firstName + ' ' + lastName).trim();
          });
        }
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _idImage = image;
          _webImage = null; // Clear web image if coming from mobile
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Error capturing image. Please try again.')),
      );
    }
  }

  String _formatDate(DateTime date) {
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
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Future<void> _pickDate() async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: const Color(0xE0F44336),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.grey.shade800,
            ),
            dialogTheme: DialogThemeData(backgroundColor: Colors.white),
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      setState(() {
        _selectedDate = date;
      });
    }
  }

  Future<List<String>> _getAvailableTimeSlots() async {
    if (_selectedDate == null) return [];

    try {
      // Get doctor's schedule for selected day
      final dayName = _getDayName(_selectedDate!);
      final doctorSchedules = await _getDoctorScheduleForDay(dayName);
      
      if (doctorSchedules.isEmpty) return [];

      // Generate time slots based on doctor's schedule
      List<String> allSlots = _generateTimeSlots(doctorSchedules);

      // Get session duration from the first schedule (they should all have the same duration for a day)
      final sessionDuration = int.tryParse(doctorSchedules.first['sessionDuration'] ?? '30') ?? 30;

      // Get already booked appointments for this date
      final bookedSlots = await _getBookedSlots(_selectedDate!, widget.doctor.id, sessionDuration);

      // Filter out booked slots
      return allSlots.where((slot) => !bookedSlots.contains(slot)).toList();
    } catch (e) {
      debugPrint('Error getting available slots: $e');
      return [];
    }
  }

  String _getDayName(DateTime date) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[date.weekday - 1];
  }

  Future<List<Map<String, String>>> _getDoctorScheduleForDay(String dayName) async {
    try {
      // Get doctor's data from Firestore to access affiliations
      final doctorDoc = await FirebaseFirestore.instance
          .collection('doctors')
          .doc(widget.doctor.id)
          .get();

      if (doctorDoc.exists) {
        final doctorData = doctorDoc.data();
        if (doctorData != null && doctorData['affiliations'] != null) {
          final affiliations = doctorData['affiliations'] as List<dynamic>;
          
          for (var affiliation in affiliations) {
            final schedules = affiliation['schedules'] as List<dynamic>? ?? [];
            final daySchedules = schedules
                .where((s) => s['day'] == dayName)
                .map((s) => Map<String, String>.from(s))
                .toList();
            
            if (daySchedules.isNotEmpty) {
              return daySchedules;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error getting doctor schedule: $e');
    }
    return [];
  }

  List<String> _generateTimeSlots(List<Map<String, String>> schedules) {
    List<String> slots = [];
    for (var schedule in schedules) {
      final startTime = schedule['start'] ?? '9:00 AM';
      final endTime = schedule['end'] ?? '5:00 PM'; 
      final breakStart = schedule['breakStart'] ?? '12:00 PM';
      final breakEnd = schedule['breakEnd'] ?? '1:00 PM';
      final sessionDuration = int.tryParse(schedule['sessionDuration'] ?? '30') ?? 30;
      
      debugPrint('Generating slots: $startTime to $endTime, break: $breakStart-$breakEnd, duration: ${sessionDuration}min');
      
      try {
        // Parse times (simplified parsing)
        final startHour = _parseTimeToMinutes(startTime);
        final endHour = _parseTimeToMinutes(endTime);
        final breakStartMinutes = _parseTimeToMinutes(breakStart);
        final breakEndMinutes = _parseTimeToMinutes(breakEnd);
        
        // Generate slots from start to break (as time ranges)
        int currentMinutes = startHour;
        while (currentMinutes + sessionDuration <= breakStartMinutes) {
          final slotStart = _formatMinutesToTime(currentMinutes);
          final slotEnd = _formatMinutesToTime(currentMinutes + sessionDuration);
          slots.add('$slotStart - $slotEnd');
          currentMinutes += sessionDuration;
        }
        
        // Generate slots from break end to day end (as time ranges)
        currentMinutes = breakEndMinutes;
        while (currentMinutes + sessionDuration <= endHour) {
          final slotStart = _formatMinutesToTime(currentMinutes);
          final slotEnd = _formatMinutesToTime(currentMinutes + sessionDuration);
          slots.add('$slotStart - $slotEnd');
          currentMinutes += sessionDuration;
        }
        
      } catch (e) {
        debugPrint('Error parsing times, using default slots: $e');
        // Fallback to default slots with ranges if parsing fails
        slots.addAll([
          '9:00 AM - 9:30 AM', '9:30 AM - 10:00 AM', '10:00 AM - 10:30 AM', 
          '10:30 AM - 11:00 AM', '11:00 AM - 11:30 AM', '11:30 AM - 12:00 PM',
          '1:00 PM - 1:30 PM', '1:30 PM - 2:00 PM', '2:00 PM - 2:30 PM', 
          '2:30 PM - 3:00 PM', '3:00 PM - 3:30 PM', '3:30 PM - 4:00 PM', 
          '4:00 PM - 4:30 PM', '4:30 PM - 5:00 PM'
        ]);
      }
    }
    return slots.toSet().toList(); // Remove duplicates
  }

  // Helper method to parse time string to minutes since midnight
  int _parseTimeToMinutes(String timeStr) {
    try {
      timeStr = timeStr.trim().toUpperCase();
      final isAM = timeStr.contains('AM');
      final isPM = timeStr.contains('PM');
      
      String time = timeStr.replaceAll(RegExp(r'[AP]M'), '').trim();
      List<String> parts = time.split(':');
      
      int hours = int.parse(parts[0]);
      int minutes = parts.length > 1 ? int.parse(parts[1]) : 0;
      
      // Convert to 24-hour format
      if (isPM && hours != 12) hours += 12;
      if (isAM && hours == 12) hours = 0;
      
      return hours * 60 + minutes;
    } catch (e) {
      debugPrint('Error parsing time $timeStr: $e');
      return 9 * 60; // Default to 9 AM
    }
  }

  // Helper method to format minutes back to time string
  String _formatMinutesToTime(int minutes) {
    int hours = minutes ~/ 60;
    int mins = minutes % 60;
    
    String period = hours >= 12 ? 'PM' : 'AM';
    int displayHour = hours > 12 ? hours - 12 : (hours == 0 ? 12 : hours);
    
    String minuteStr = mins == 0 ? '00' : mins.toString().padLeft(2, '0');
    return '$displayHour:$minuteStr $period';
  }

  Future<List<String>> _getBookedSlots(DateTime date, String doctorId, int sessionDuration) async {
    try {
      final formattedDate = Timestamp.fromDate(DateTime(date.year, date.month, date.day));
      
      // Check both pending and approved appointments
      final pendingQuery = await FirebaseFirestore.instance
          .collection('pending_patient_data')
          .where('doctorId', isEqualTo: doctorId)
          .where('appointmentDate', isEqualTo: formattedDate)
          .get();
      
      // Check if approved_appointments collection exists
      QuerySnapshot? approvedQuery;
      try {
        approvedQuery = await FirebaseFirestore.instance
            .collection('approved_appointments')
            .where('doctorId', isEqualTo: doctorId)
            .where('appointmentDate', isEqualTo: formattedDate)
            .get();
      } catch (e) {
        debugPrint('approved_appointments collection may not exist yet: $e');
      }

      Set<String> bookedTimes = {};
      
      for (var doc in pendingQuery.docs) {
        final data = doc.data();
        final time = data['appointmentTime'];
        if (time != null) {
          // Handle both old format (start time only) and new format (time range)
          bookedTimes.add(time);
          // If it's an old format (just start time), also block the corresponding range
          if (!time.contains(' - ')) {
            // Try to convert single time to range format for comparison
            final startTime = time;
            try {
              final startMinutes = _parseTimeToMinutes(startTime);
              final endTime = _formatMinutesToTime(startMinutes + sessionDuration);
              bookedTimes.add('$startTime - $endTime');
            } catch (e) {
              debugPrint('Error converting time format: $e');
            }
          }
        }
      }
      
      if (approvedQuery != null) {
        for (var doc in approvedQuery.docs) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data != null) {
            final time = data['appointmentTime'];
            if (time != null) {
              // Handle both old format (start time only) and new format (time range)
              bookedTimes.add(time);
              // If it's an old format (just start time), also block the corresponding range
              if (!time.contains(' - ')) {
                // Try to convert single time to range format for comparison
                final startTime = time;
                try {
                  final startMinutes = _parseTimeToMinutes(startTime);
                  final endTime = _formatMinutesToTime(startMinutes + sessionDuration);
                  bookedTimes.add('$startTime - $endTime');
                } catch (e) {
                  debugPrint('Error converting time format: $e');
                }
              }
            }
          }
        }
      }

      return bookedTimes.toList();
    } catch (e) {
      debugPrint('Error getting booked slots: $e');
      return [];
    }
  }

  Future<void> _submitBooking() async {
    // Validate all fields
    if (_selectedDate == null ||
        _selectedTime == null ||
        _nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _ageController.text.isEmpty ||
        _selectedGender == null ||
        _selectedGender == _genders.first ||
        _selectedID == null ||
        _selectedID == _validIDs.first ||
        _idImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Please fill all fields, select gender and valid ID, and upload ID')),
      );
      return;
    }

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        },
      );

      String idImageUrl;
      if (kIsWeb) {
        // Web upload logic (using html)
        // ...existing code for web upload (html.FormData, html.HttpRequest)...
        throw UnimplementedError('Web upload not shown here');
      } else {
        // Mobile upload logic using http.MultipartRequest
        debugPrint('Starting Cloudinary upload (MOBILE)...');
        final uri =
            Uri.parse('https://api.cloudinary.com/v1_1/ddjraogpj/image/upload');
        final request = http.MultipartRequest('POST', uri);
        request.fields['upload_preset'] = 'uploads';
        request.files
            .add(await http.MultipartFile.fromPath('file', _idImage!.path));
        final response = await request.send();
        if (response.statusCode == 200) {
          final respStr = await response.stream.bytesToString();
          final respJson = json.decode(respStr);
          idImageUrl = respJson['secure_url'] as String? ?? '';
          if (idImageUrl.isEmpty) {
            throw Exception('Upload failed: No secure_url in response');
          }
          debugPrint('Upload successful: $idImageUrl');
        } else {
          throw Exception('Upload failed: ${response.statusCode}');
        }
      }

      // Get current user's UID
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not logged in. Please log in and try again.');
      }

      // Create appointment data
      final appointmentData = {
        'patientUid': currentUser.uid, // Add the UID here
        'patientName': _nameController.text.trim(),
        'patientEmail': _emailController.text.trim(),
        'patientPhone': _phoneController.text.trim(),
        'patientAge': int.parse(_ageController.text),
        'patientGender': _selectedGender,
        'idType': _selectedID,
        'idImageUrl': idImageUrl,
        'appointmentDate': Timestamp.fromDate(_selectedDate!),
        'appointmentTime': _selectedTime,
        'status': 'pending',
        'doctorId': widget.doctor.id,
        'doctorName': widget.doctor.name,
        'doctorSpecialization': widget.doctor.specialization,
        'facility': widget.doctor.facility,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      debugPrint('Preparing to save appointment data: $appointmentData');

      // Save to Firestore with explicit collection creation
      final firestore = FirebaseFirestore.instance;
      final pendingCollection = firestore.collection('pending_patient_data');

      try {
        // First, try to create the collection by adding the first document
        await pendingCollection.add(appointmentData);
        debugPrint('Successfully created appointment in pending_patient_data');
      } catch (e) {
        debugPrint('Error creating appointment: $e');
        throw Exception('Failed to create appointment. Please try again.');
      }

      // Close loading dialog
      Navigator.of(context).pop();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Booking submitted successfully! Please wait for doctor\'s confirmation.'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate back
      Navigator.of(context).pop();
    } catch (e) {
      // Close loading dialog if it's showing
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e is Exception
                ? e.toString()
                : 'Error submitting booking. Please check your internet connection and try again.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // Build time slots widget with AM/PM separation
  Widget _buildTimeSlots() {
    return FutureBuilder<List<String>>(
      future: _getAvailableTimeSlots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final availableSlots = snapshot.data ?? [];
        
        if (availableSlots.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'No available slots for this date',
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          );
        }

        // Separate AM and PM slots
        final morningSlots = <String>[];
        final afternoonSlots = <String>[];

        for (String slot in availableSlots) {
          if (slot.contains('AM')) {
            morningSlots.add(slot);
          } else if (slot.contains('PM')) {
            // Check if it's 12:XX PM (should be in afternoon)
            if (slot.startsWith('12:')) {
              afternoonSlots.add(slot);
            } else {
              afternoonSlots.add(slot);
            }
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Morning Session
            if (morningSlots.isNotEmpty) ...[
              _buildSessionHeader('Morning Session', Icons.wb_sunny, Colors.orange),
              const SizedBox(height: 12),
              _buildSessionContainer(morningSlots, Colors.orange.withOpacity(0.1)),
              const SizedBox(height: 20),
            ],
            
            // Afternoon Session
            if (afternoonSlots.isNotEmpty) ...[
              _buildSessionHeader('Afternoon Session', Icons.wb_sunny_outlined, Colors.blue),
              const SizedBox(height: 12),
              _buildSessionContainer(afternoonSlots, Colors.blue.withOpacity(0.1)),
            ],
          ],
        );
      },
    );
  }

  // Build session header
  Widget _buildSessionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  // Build session container with time slots
  Widget _buildSessionContainer(List<String> slots, Color backgroundColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: backgroundColor.withOpacity(0.5)),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: slots.map((time) {
          final isSelected = _selectedTime == time;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedTime = time;
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                constraints: const BoxConstraints(minWidth: 130),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xE0F44336) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: isSelected 
                          ? const Color(0xE0F44336).withOpacity(0.3)
                          : Colors.grey.withOpacity(0.2),
                      blurRadius: isSelected ? 8 : 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  border: isSelected 
                      ? Border.all(color: const Color(0xE0F44336), width: 2)
                      : Border.all(color: Colors.grey.shade300, width: 1),
                ),
                child: Text(
                  time,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Custom Input Decoration
  Widget _customTextField(TextEditingController controller, String label,
      {TextInputType keyboardType = TextInputType.text}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 16),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
          floatingLabelStyle: const TextStyle(
            color: Color(0xE0F44336),
            fontWeight: FontWeight.w600,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xE0F44336), width: 2),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          fillColor: Colors.white,
          filled: true,
        ),
      ),
    );
  }

  // Custom Dropdown
  Widget _customDropdown<T>(
      {required T? value,
      required String label,
      required List<T> items,
      required Function(T?) onChanged}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DropdownButtonFormField<T>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
          floatingLabelStyle: const TextStyle(
            color: Color(0xE0F44336),
            fontWeight: FontWeight.w600,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xE0F44336), width: 2),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 20),
          fillColor: Colors.white,
          filled: true,
        ),
        icon:
            const Icon(Icons.arrow_drop_down_rounded, color: Color(0xE0F44336)),
        dropdownColor: Colors.white,
        style: const TextStyle(
          fontSize: 16,
          color: Colors.black87,
        ),
        items: items
            .map((item) => DropdownMenuItem(
                  value: item,
                  child: Text(item.toString()),
                ))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F5),
      body: SingleChildScrollView(
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16), // ✅ Global margin
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 40, 0, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Modern Back Button
                    Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new,
                            color: Color(0xFF1F2937), size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const Text(
                      "Book Appointment",
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
              const SizedBox(height: 20),

              // SELECT DATE
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        'Select Date',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Color(0xFF2D3142),
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFFFEEBEE),
                              const Color(0xFFFFCDD2),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFEF9A9A),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xE0F44336).withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xE0F44336),
                                    Colors.red.shade400,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xE0F44336)
                                        .withOpacity(0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.calendar_today_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedDate == null
                                        ? 'Select a date'
                                        : _formatDate(_selectedDate!),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.red.shade900,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Tap to change date',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.red.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.red.shade200,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.edit_rounded,
                                color: Colors.red.shade700,
                                size: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // SELECT TIME
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 12),
                      child: Text(
                        'Available Slots',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Color(0xFF2D3142),
                        ),
                      ),
                    ),
                    _selectedDate == null 
                      ? Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            'Please select a date first',
                            style: TextStyle(color: Colors.grey.shade600),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : _buildTimeSlots(),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // PATIENT DETAILS
              Container(
                margin: const EdgeInsets.only(left: 4),
                child: const Text(
                  'Patient Details',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Color(0xFF2D3142),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _customTextField(_nameController, 'Full Name'),
              const SizedBox(height: 12),
              _customTextField(_emailController, 'Email',
                  keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 12),
              _customTextField(_phoneController, 'Phone Number',
                  keyboardType: TextInputType.phone),
              const SizedBox(height: 12),
              _customDropdown<String>(
                value: _selectedGender,
                label: 'Gender',
                items: _genders,
                onChanged: (value) => setState(() => _selectedGender = value),
              ),
              const SizedBox(height: 12),
              _customTextField(_ageController, 'Age',
                  keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              _customDropdown<String>(
                value: _selectedID,
                label: 'Valid ID',
                items: _validIDs,
                onChanged: (value) => setState(() => _selectedID = value),
              ),
              const SizedBox(height: 20),

              // Upload ID
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 12),
                      child: Text(
                        'Upload Valid ID (Capture Photo)',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Color(0xFF2D3142),
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: _pickImage,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        height: 160,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _idImage == null
                                ? Colors.grey.shade300
                                : const Color(0xE0F44336),
                            width: _idImage == null ? 1 : 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.shade200,
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: _idImage == null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEEBEE),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Icon(
                                      Icons.add_photo_alternate_rounded,
                                      size: 40,
                                      color: Color(0xE0F44336),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Tap to Upload ID',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              )
                            : Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: kIsWeb
                                        ? Image.memory(
                                            _webImage!,
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            height: double.infinity,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              return const Center(
                                                child:
                                                    Text('Error loading image'),
                                              );
                                            },
                                          )
                                        : Image.file(
                                            File(_idImage!.path),
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            height: double.infinity,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              return const Center(
                                                child:
                                                    Text('Error loading image'),
                                              );
                                            },
                                          ),
                                  ),
                                  Positioned(
                                    top: 12,
                                    right: 12,
                                    child: InkWell(
                                      onTap: () {
                                        setState(() {
                                          _idImage = null;
                                          _webImage = null;
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.6),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: const Icon(
                                          Icons.close_rounded,
                                          color: Colors.white,
                                          size: 20,
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
              const SizedBox(height: 20),

              // Submit Button
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _submitBooking,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xE0F44336),
                    elevation: 4,
                    shadowColor: const Color(0xE0F44336).withOpacity(0.4),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Confirm Booking',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
