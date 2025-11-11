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
  // Scroll controller to maintain scroll position
  final ScrollController _scrollController = ScrollController();
  // Save scroll position to restore after dropdown/image picker
  double _savedScrollPosition = 0.0;
  
  // Controllers for patient details
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  // Dropdown selections
  String? _selectedGender;
  String? _selectedID;
  DateTime? _selectedDate;
  String? _selectedTime;
  XFile? _idImage;
  Uint8List? _webImage;
  
  // Doctor facility information
  String _facilityName = '';
  String _facilityAddress = '';
  bool _isLoadingFacility = true;

  // Facility name mapping - converts short names to full names
  // Alphabetically ordered by complete facility name
  String _getCompleteFacilityName(String shortName) {
    final Map<String, String> facilityMap = {
      // AGDAO HEALTH CENTER
      'AGDAO': 'AGDAO HEALTH CENTER',
      'AGDAO HC': 'AGDAO HEALTH CENTER',
      'AGDAO HEALTH CENTER': 'AGDAO HEALTH CENTER',
      
      // BAGUIO (MALAGOS HC)
      'BAGUIO': 'BAGUIO (MALAGOS HC)',
      'MALAGOS': 'BAGUIO (MALAGOS HC)',
      'MALAGOS HC': 'BAGUIO (MALAGOS HC)',
      'BAGUIO (MALAGOS HC)': 'BAGUIO (MALAGOS HC)',
      
      // BUHANGIN DISTRICT HEALTH CENTER
      'BUHANGIN': 'BUHANGIN DISTRICT HEALTH CENTER',
      'BUHANGIN HC': 'BUHANGIN DISTRICT HEALTH CENTER',
      'BUHANGIN DISTRICT HEALTH CENTER': 'BUHANGIN DISTRICT HEALTH CENTER',
      
      // BUNAWAN HEALTH CENTER
      'BUNAWAN': 'BUNAWAN HEALTH CENTER',
      'BUNAWAN HC': 'BUNAWAN HEALTH CENTER',
      'BUNAWAN HEALTH CENTER': 'BUNAWAN HEALTH CENTER',
      
      // CALINAN HEALTH CENTER
      'CALINAN': 'CALINAN HEALTH CENTER',
      'CALINAN HC': 'CALINAN HEALTH CENTER',
      'CALINAN HEALTH CENTER': 'CALINAN HEALTH CENTER',
      
      // DAVAO CHEST CENTER
      'DAVAO CHEST': 'DAVAO CHEST CENTER',
      'DAVAO CHEST CENTER': 'DAVAO CHEST CENTER',
      'CHEST CENTER': 'DAVAO CHEST CENTER',
      
      // EL RIO HEALTH CENTER
      'EL RIO': 'EL RIO HEALTH CENTER',
      'EL RIO HC': 'EL RIO HEALTH CENTER',
      'EL RIO HEALTH CENTER': 'EL RIO HEALTH CENTER',
      
      // JACINTO HEALTH CENTER
      'JACINTO': 'JACINTO HEALTH CENTER',
      'JACINTO HC': 'JACINTO HEALTH CENTER',
      'JACINTO HEALTH CENTER': 'JACINTO HEALTH CENTER',
      
      // MALABOG HEALTH CENTER
      'MALABOG': 'MALABOG HEALTH CENTER',
      'MALABOG HC': 'MALABOG HEALTH CENTER',
      'MALABOG HEALTH CENTER': 'MALABOG HEALTH CENTER',
      
      // MARAHAN HEALTH CENTER
      'MARAHAN': 'MARAHAN HEALTH CENTER',
      'MARAHAN HC': 'MARAHAN HEALTH CENTER',
      'MARAHAN HEALTH CENTER': 'MARAHAN HEALTH CENTER',
      
      // MINIFOREST HEALTH CENTER
      'MINIFOREST': 'MINIFOREST HEALTH CENTER',
      'MINIFOREST HC': 'MINIFOREST HEALTH CENTER',
      'MINIFOREST HEALTH CENTER': 'MINIFOREST HEALTH CENTER',
      
      // SASA DISTRICT HEALTH CENTER
      'SASA': 'SASA DISTRICT HEALTH CENTER',
      'SASA HC': 'SASA DISTRICT HEALTH CENTER',
      'SASA DISTRICT HEALTH CENTER': 'SASA DISTRICT HEALTH CENTER',
      
      // TALOMO CENTRAL (GSIS HC)
      'TALOMO CENTRAL': 'TALOMO CENTRAL (GSIS HC)',
      'GSIS': 'TALOMO CENTRAL (GSIS HC)',
      'GSIS HC': 'TALOMO CENTRAL (GSIS HC)',
      'TALOMO CENTRAL (GSIS HC)': 'TALOMO CENTRAL (GSIS HC)',
      
      // TALOMO NORTH (SIR HC)
      'TALOMO NORTH': 'TALOMO NORTH (SIR HC)',
      'SIR': 'TALOMO NORTH (SIR HC)',
      'SIR HC': 'TALOMO NORTH (SIR HC)',
      'TALOMO NORTH (SIR HC)': 'TALOMO NORTH (SIR HC)',
      
      // TALOMO SOUTH (PUAN HC)
      'TALOMO SOUTH': 'TALOMO SOUTH (PUAN HC)',
      'PUAN': 'TALOMO SOUTH (PUAN HC)',
      'PUAN HC': 'TALOMO SOUTH (PUAN HC)',
      'TALOMO SOUTH (PUAN HC)': 'TALOMO SOUTH (PUAN HC)',
      
      // TOMAS CLAUDIO HEALTH CENTER
      'TOMAS CLAUDIO': 'TOMAS CLAUDIO HEALTH CENTER',
      'TOMAS CLAUDIO HC': 'TOMAS CLAUDIO HEALTH CENTER',
      'TOMAS CLAUDIO HEALTH CENTER': 'TOMAS CLAUDIO HEALTH CENTER',
      
      // TORIL A HEALTH CENTER
      'TORIL A': 'TORIL A HEALTH CENTER',
      'TORIL A HC': 'TORIL A HEALTH CENTER',
      'TORIL A HEALTH CENTER': 'TORIL A HEALTH CENTER',
      
      // TORIL B HEALTH CENTER
      'TORIL B': 'TORIL B HEALTH CENTER',
      'TORIL B HC': 'TORIL B HEALTH CENTER',
      'TORIL B HEALTH CENTER': 'TORIL B HEALTH CENTER',
      
      // TUGBOK (MINTAL HC)
      'TUGBOK': 'TUGBOK (MINTAL HC)',
      'MINTAL': 'TUGBOK (MINTAL HC)',
      'MINTAL HC': 'TUGBOK (MINTAL HC)',
      'TUGBOK (MINTAL HC)': 'TUGBOK (MINTAL HC)',
    };

    // Check for exact match first
    if (facilityMap.containsKey(shortName.toUpperCase())) {
      return facilityMap[shortName.toUpperCase()]!;
    }

    // Check for partial match (case-insensitive)
    for (var entry in facilityMap.entries) {
      if (shortName.toUpperCase().contains(entry.key)) {
        return entry.value;
      }
    }

    // Return original name if no match found
    return shortName;
  }

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

    // Debug: Print doctor information
    debugPrint('========== DOCTOR INFO ==========');
    debugPrint('Doctor ID: ${widget.doctor.id}');
    debugPrint('Doctor Name: ${widget.doctor.name}');
    debugPrint('Doctor Email: ${widget.doctor.email}');
    debugPrint('Doctor Specialization: ${widget.doctor.specialization}');
    debugPrint('Doctor Facility: ${widget.doctor.facility}');
    debugPrint('==================================');

    // Run debug to check doctor data in Firestore
    _debugDoctorData();
    
    // Load facility information
    _loadFacilityInfo();

    // Pre-fill name, email, address, phone, gender, and age from Firestore user data
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _emailController.text = user.email ?? '';
      _authService.getCurrentUserDetails().then((details) {
        if (details != null) {
          final firstName = details['firstName'] ?? '';
          final lastName = details['lastName'] ?? '';
          final address = details['address'] ?? '';
          final phone = details['phone'] ?? '';
          final gender = details['gender'] ?? '';
          final age = details['age'];
          
          setState(() {
            _nameController.text = (firstName + ' ' + lastName).trim();
            _addressController.text = address;
            _phoneController.text = phone;
            
            // Set gender if it exists and is valid
            if (gender.isNotEmpty && _genders.contains(gender)) {
              _selectedGender = gender;
            }
            
            // Set age if it exists
            if (age != null) {
              _ageController.text = age.toString();
            }
          });
        }
      });
    }
  }

  Future<void> _loadFacilityInfo() async {
    if (!mounted) return;

    try {
      final doctorDoc = await FirebaseFirestore.instance
          .collection('doctors')
          .doc(widget.doctor.id)
          .get();

      if (!mounted) return;

      if (doctorDoc.exists) {
        final data = doctorDoc.data();
        final affiliations = data?['affiliations'] as List<dynamic>?;

        String facilityName = 'No facility information';
        String facilityAddress = 'N/A';

        if (affiliations != null && affiliations.isNotEmpty) {
          final firstAffiliation = affiliations[0] as Map<String, dynamic>;
          facilityName = firstAffiliation['name'] ?? 'N/A';
          facilityAddress = firstAffiliation['address'] ?? 'N/A';
        }

        if (mounted) {
          setState(() {
            _facilityName = _getCompleteFacilityName(facilityName);
            _facilityAddress = facilityAddress;
            _isLoadingFacility = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _facilityName = 'No facility information';
            _facilityAddress = 'N/A';
            _isLoadingFacility = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading facility info: $e');
      if (mounted) {
        setState(() {
          _facilityName = 'Error loading facility';
          _facilityAddress = 'N/A';
          _isLoadingFacility = false;
        });
      }
    }
  }

  Future<Map<String, String>> _getDoctorScheduleInfo() async {
    try {
      // Get doctor document from Firestore
      final doctorDoc = await FirebaseFirestore.instance
          .collection('doctors')
          .doc(widget.doctor.id)
          .get();

      if (!doctorDoc.exists) {
        return {};
      }

      final doctorData = doctorDoc.data() as Map<String, dynamic>;
      final affiliations = doctorData['affiliations'] as List<dynamic>? ?? [];

      if (affiliations.isEmpty) {
        return {};
      }

      // Get schedules from first affiliation
      final firstAffiliation = affiliations[0] as Map<String, dynamic>;
      final schedules = firstAffiliation['schedules'] as List<dynamic>? ?? [];

      if (schedules.isEmpty) {
        return {};
      }

      // Get the first schedule to determine time range and session duration
      final firstSchedule = schedules[0] as Map<String, dynamic>;
      String startTime = firstSchedule['start']?.toString() ?? '8:00 AM';
      String endTime = firstSchedule['end']?.toString() ?? '5:00 PM';
      String sessionDuration = firstSchedule['sessionDuration']?.toString() ?? '30';

      // Return schedule and session info separately
      return {
        'schedule': '$startTime - $endTime',
        'session': '${sessionDuration}min session',
      };
    } catch (e) {
      debugPrint('Error getting doctor schedule info: $e');
      return {};
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _ageController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    // Save current scroll position
    if (_scrollController.hasClients) {
      _savedScrollPosition = _scrollController.position.pixels;
    }
    
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
        
        // Restore scroll position after setState
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(_savedScrollPosition);
          }
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
    // Save current scroll position
    if (_scrollController.hasClients) {
      _savedScrollPosition = _scrollController.position.pixels;
    }
    
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
      final dayName = _getDayName(date);
      debugPrint('========================================');
      debugPrint('Date selected: ${_formatDate(date)}');
      debugPrint('Day of week: $dayName');
      debugPrint('Triggering schedule fetch...');
      debugPrint('========================================');
      
      setState(() {
        _selectedDate = date;
        _selectedTime = null; // Reset selected time when date changes
      });
      
      // Restore scroll position after setState
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_savedScrollPosition);
        }
      });
      
      debugPrint('State updated, widget will rebuild');
    }
  }

  Future<List<String>> _getAvailableTimeSlots() async {
    if (_selectedDate == null) {
      debugPrint('No date selected, returning empty slots');
      return [];
    }

    try {
      debugPrint('Getting available time slots for: ${_formatDate(_selectedDate!)}');
      
      // Get doctor's schedule for selected day
      final dayName = _getDayName(_selectedDate!);
      debugPrint('Day name: $dayName');
      
      final doctorSchedules = await _getDoctorScheduleForDay(dayName);

      if (doctorSchedules.isEmpty) {
        debugPrint('No schedules found for $dayName');
        return [];
      }

      debugPrint('Found ${doctorSchedules.length} schedules');

      // Generate time slots based on doctor's schedule
      List<String> allSlots = _generateTimeSlots(doctorSchedules);
      debugPrint('Generated ${allSlots.length} total slots');

      // Get session duration from the first schedule (they should all have the same duration for a day)
      final sessionDuration =
          int.tryParse(doctorSchedules.first['sessionDuration'] ?? '30') ?? 30;
      debugPrint('Session duration: $sessionDuration minutes');

      // Get already booked appointments for this date
      final bookedSlots = await _getBookedSlots(
          _selectedDate!, widget.doctor.id, sessionDuration);
      debugPrint('Found ${bookedSlots.length} booked slots: $bookedSlots');

      // Filter out booked slots
      final availableSlots = allSlots.where((slot) => !bookedSlots.contains(slot)).toList();
      debugPrint('Returning ${availableSlots.length} available slots: $availableSlots');
      
      return availableSlots;
    } catch (e) {
      debugPrint('Error getting available slots: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
      return [];
    }
  }

  String _getDayName(DateTime date) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return days[date.weekday - 1];
  }

  Future<List<Map<String, String>>> _getDoctorScheduleForDay(
      String dayName) async {
    try {
      debugPrint('========== SCHEDULE FETCH START ==========');
      debugPrint('Getting schedule for day: $dayName');
      debugPrint('Doctor ID: ${widget.doctor.id}');
      debugPrint('Doctor Email: ${widget.doctor.email}');
      debugPrint('Doctor Name: ${widget.doctor.name}');
      
      // Try to get doctor's data from Firestore using the ID
      DocumentSnapshot? doctorDoc;
      
      // First try: Use the doctor ID directly
      doctorDoc = await FirebaseFirestore.instance
          .collection('doctors')
          .doc(widget.doctor.id)
          .get();

      // Second try: If not found, try querying by email
      if (!doctorDoc.exists) {
        debugPrint('Doctor not found by ID, trying to query by email...');
        final querySnapshot = await FirebaseFirestore.instance
            .collection('doctors')
            .where('email', isEqualTo: widget.doctor.email)
            .limit(1)
            .get();
        
        if (querySnapshot.docs.isNotEmpty) {
          doctorDoc = querySnapshot.docs.first;
          debugPrint('Doctor found by email! Document ID: ${doctorDoc.id}');
        }
      }

      // Third try: If still not found, try querying by name
      if (!doctorDoc.exists) {
        debugPrint('Doctor not found by email, trying to query by fullName...');
        final querySnapshot = await FirebaseFirestore.instance
            .collection('doctors')
            .where('fullName', isEqualTo: widget.doctor.name)
            .limit(1)
            .get();
        
        if (querySnapshot.docs.isNotEmpty) {
          doctorDoc = querySnapshot.docs.first;
          debugPrint('Doctor found by name! Document ID: ${doctorDoc.id}');
        }
      }

      if (!doctorDoc.exists) {
        debugPrint('ERROR: Doctor document not found after all attempts!');
        debugPrint('Please check Firestore to ensure this doctor exists.');
        return [];
      }

      final doctorData = doctorDoc.data() as Map<String, dynamic>?;
      debugPrint('Doctor data keys: ${doctorData?.keys.join(", ")}');
      
      if (doctorData == null) {
        debugPrint('ERROR: Doctor data is null!');
        return [];
      }

      // Check if affiliations exist
      if (doctorData['affiliations'] == null) {
        debugPrint('WARNING: No affiliations field found in doctor data');
        debugPrint('Doctor data structure: ${doctorData.toString()}');
        return [];
      }

      final affiliations = doctorData['affiliations'] as List<dynamic>;
      debugPrint('Found ${affiliations.length} affiliations');

      // Collect all schedules for the day from all affiliations
      List<Map<String, String>> allDaySchedules = [];

      for (var i = 0; i < affiliations.length; i++) {
        final affiliation = affiliations[i];
        debugPrint('--- Affiliation $i ---');
        debugPrint('Name: ${affiliation['name']}');
        debugPrint('Address: ${affiliation['address']}');
        
        if (affiliation['schedules'] == null) {
          debugPrint('WARNING: No schedules field in affiliation $i');
          continue;
        }

        final schedules = affiliation['schedules'] as List<dynamic>;
        debugPrint('Schedules count: ${schedules.length}');
        
        // Log all schedule days to help debug
        for (var j = 0; j < schedules.length; j++) {
          final schedule = schedules[j];
          debugPrint('  Schedule $j: day="${schedule['day']}", start="${schedule['start']}", end="${schedule['end']}"');
        }

        final daySchedules = schedules
            .where((s) {
              final scheduleDay = s['day']?.toString() ?? '';
              final match = scheduleDay == dayName;
              if (match) {
                debugPrint('MATCH FOUND: Schedule day "$scheduleDay" matches requested day "$dayName"');
              }
              return match;
            })
            .map((s) {
              // Ensure all fields are strings
              return {
                'day': s['day']?.toString() ?? '',
                'start': s['start']?.toString() ?? '9:00 AM',
                'end': s['end']?.toString() ?? '5:00 PM',
                'breakStart': s['breakStart']?.toString() ?? '12:00 PM',
                'breakEnd': s['breakEnd']?.toString() ?? '1:00 PM',
                'sessionDuration': s['sessionDuration']?.toString() ?? '30',
              };
            })
            .toList();

        if (daySchedules.isNotEmpty) {
          debugPrint('Found ${daySchedules.length} schedules for $dayName in affiliation $i');
          allDaySchedules.addAll(daySchedules);
        }
      }

      if (allDaySchedules.isEmpty) {
        debugPrint('WARNING: No schedules found for $dayName in any affiliation');
        debugPrint('Available days in schedules:');
        for (var affiliation in affiliations) {
          final schedules = affiliation['schedules'] as List<dynamic>? ?? [];
          final days = schedules.map((s) => s['day']).toSet().toList();
          debugPrint('  Affiliation "${affiliation['name']}": $days');
        }
      } else {
        debugPrint('SUCCESS: Returning ${allDaySchedules.length} schedules for $dayName');
        for (var schedule in allDaySchedules) {
          debugPrint('  ${schedule.toString()}');
        }
      }

      debugPrint('========== SCHEDULE FETCH END ==========');
      return allDaySchedules;
    } catch (e, stackTrace) {
      debugPrint('ERROR getting doctor schedule: $e');
      debugPrint('Stack trace: $stackTrace');
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
      final sessionDuration =
          int.tryParse(schedule['sessionDuration'] ?? '30') ?? 30;

      debugPrint(
          'Generating slots: $startTime to $endTime, break: $breakStart-$breakEnd, duration: ${sessionDuration}min');

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
          final slotEnd =
              _formatMinutesToTime(currentMinutes + sessionDuration);
          slots.add('$slotStart - $slotEnd');
          currentMinutes += sessionDuration;
        }

        // Generate slots from break end to day end (as time ranges)
        currentMinutes = breakEndMinutes;
        while (currentMinutes + sessionDuration <= endHour) {
          final slotStart = _formatMinutesToTime(currentMinutes);
          final slotEnd =
              _formatMinutesToTime(currentMinutes + sessionDuration);
          slots.add('$slotStart - $slotEnd');
          currentMinutes += sessionDuration;
        }
      } catch (e) {
        debugPrint('Error parsing times, using default slots: $e');
        // Fallback to default slots with ranges if parsing fails
        slots.addAll([
          '9:00 AM - 9:30 AM',
          '9:30 AM - 10:00 AM',
          '10:00 AM - 10:30 AM',
          '10:30 AM - 11:00 AM',
          '11:00 AM - 11:30 AM',
          '11:30 AM - 12:00 PM',
          '1:00 PM - 1:30 PM',
          '1:30 PM - 2:00 PM',
          '2:00 PM - 2:30 PM',
          '2:30 PM - 3:00 PM',
          '3:00 PM - 3:30 PM',
          '3:30 PM - 4:00 PM',
          '4:00 PM - 4:30 PM',
          '4:30 PM - 5:00 PM'
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

  // Helper widget for confirmation dialog details
  Widget _buildConfirmationDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF1F2937),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<List<String>> _getBookedSlots(
      DateTime date, String doctorId, int sessionDuration) async {
    try {
      final formattedDate =
          Timestamp.fromDate(DateTime(date.year, date.month, date.day));

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
              final endTime =
                  _formatMinutesToTime(startMinutes + sessionDuration);
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
                  final endTime =
                      _formatMinutesToTime(startMinutes + sessionDuration);
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
        _addressController.text.isEmpty ||
        _selectedGender == null ||
        _selectedGender == _genders.first ||
        _selectedID == null ||
        _selectedID == _validIDs.first ||
        _idImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Please fill all fields including address, select gender and valid ID, and upload ID')),
      );
      return;
    }

    // Show confirmation dialog first
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 520),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.redAccent.shade200, Colors.redAccent.shade700],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.check_circle_outline, color: Colors.white, size: 22),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Confirm Booking',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                // Body
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Please review your appointment details:',
                        style: TextStyle(fontSize: 14, color: Colors.black87),
                      ),
                      const SizedBox(height: 16),
                      _buildConfirmationDetail('Doctor', 'Dr. ${widget.doctor.name}'),
                      _buildConfirmationDetail('Facility', _facilityName),
                      _buildConfirmationDetail('Date', _formatDate(_selectedDate!)),
                      _buildConfirmationDetail('Time', _selectedTime!),
                      const SizedBox(height: 16),
                      const Text(
                        'Do you want to proceed with this booking?',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(dialogContext).pop(false),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                side: BorderSide(color: Colors.grey.shade300),
                              ),
                              child: const Text('Cancel', style: TextStyle(color: Colors.black87)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => Navigator.of(dialogContext).pop(true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Confirm', style: TextStyle(color: Colors.white)),
                            ),
                          ),
                        ],
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

    // If user cancelled, return
    if (confirmed != true) {
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
        'patientAddress': _addressController.text.trim(),
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
        
        // Update user profile with address, phone, gender, and age for future use
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .update({
            'address': _addressController.text.trim(),
            'phone': _phoneController.text.trim(),
            'gender': _selectedGender,
            'age': int.parse(_ageController.text),
          });
          debugPrint('User profile updated successfully (address, phone, gender, age)');
        } catch (e) {
          debugPrint('Error updating user profile: $e');
          // Non-critical error, continue with booking
        }
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
          duration: Duration(seconds: 2),
        ),
      );

      // Go back to the previous page
      if (context.mounted) {
        Navigator.of(context).pop();
      }
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

  // DEBUG METHOD - Remove this after fixing the issue
  Future<void> _debugDoctorData() async {
    debugPrint('========== DEBUG DOCTOR DATA START ==========');
    try {
      // Try multiple ways to fetch doctor data
      final doctorId = widget.doctor.id;
      final doctorEmail = widget.doctor.email;
      
      debugPrint('Attempting to fetch doctor with ID: $doctorId');
      
      // Method 1: Direct ID lookup
      final directDoc = await FirebaseFirestore.instance
          .collection('doctors')
          .doc(doctorId)
          .get();
      
      if (directDoc.exists) {
        debugPrint('✓ Doctor found by ID');
        final data = directDoc.data();
        debugPrint('Document ID: ${directDoc.id}');
        debugPrint('Full data: ${data.toString()}');
        
        if (data?['affiliations'] != null) {
          final affiliations = data!['affiliations'] as List<dynamic>;
          debugPrint('Affiliations count: ${affiliations.length}');
          
          for (var i = 0; i < affiliations.length; i++) {
            final aff = affiliations[i];
            debugPrint('Affiliation $i:');
            debugPrint('  Name: ${aff['name']}');
            debugPrint('  Address: ${aff['address']}');
            
            if (aff['schedules'] != null) {
              final schedules = aff['schedules'] as List<dynamic>;
              debugPrint('  Schedules: ${schedules.length}');
              for (var j = 0; j < schedules.length; j++) {
                final sched = schedules[j];
                debugPrint('    Schedule $j: ${sched.toString()}');
              }
            }
          }
        } else {
          debugPrint('✗ No affiliations found in doctor data');
        }
      } else {
        debugPrint('✗ Doctor NOT found by ID: $doctorId');
        
        // Try by email
        debugPrint('Trying to find by email: $doctorEmail');
        final emailQuery = await FirebaseFirestore.instance
            .collection('doctors')
            .where('email', isEqualTo: doctorEmail)
            .get();
        
        if (emailQuery.docs.isNotEmpty) {
          debugPrint('✓ Found ${emailQuery.docs.length} doctor(s) by email');
          for (var doc in emailQuery.docs) {
            debugPrint('  Doc ID: ${doc.id}');
            debugPrint('  Data: ${doc.data()}');
          }
        } else {
          debugPrint('✗ No doctor found by email');
        }
      }
    } catch (e, stackTrace) {
      debugPrint('ERROR in debug: $e');
      debugPrint('Stack: $stackTrace');
    }
    debugPrint('========== DEBUG DOCTOR DATA END ==========');
  }

  // Build time slots widget with AM/PM separation
  Widget _buildTimeSlots() {
    // Save scroll position before FutureBuilder rebuilds
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients && _savedScrollPosition > 0) {
          _scrollController.jumpTo(_savedScrollPosition);
        }
      });
    }
    
    // Use a key based on selected date to force rebuild
    return FutureBuilder<List<String>>(
      key: ValueKey(_selectedDate?.toString() ?? 'no-date'),
      future: _getAvailableTimeSlots(),
      builder: (context, snapshot) {
        // Save position when builder starts
        if (snapshot.connectionState == ConnectionState.waiting && _scrollController.hasClients) {
          _savedScrollPosition = _scrollController.position.pixels;
        }
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xE0F44336)),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'Error loading slots: ${snapshot.error}',
              style: TextStyle(color: Colors.red.shade700),
              textAlign: TextAlign.center,
            ),
          );
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
              'No available slots for this date. The doctor may not have scheduled appointments for this day.',
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
              _buildSessionHeader(
                  'Morning Session', Icons.wb_sunny, Colors.orange),
              const SizedBox(height: 12),
              _buildSessionContainer(
                  morningSlots, Colors.orange.withOpacity(0.1)),
              const SizedBox(height: 20),
            ],

            // Afternoon Session
            if (afternoonSlots.isNotEmpty) ...[
              _buildSessionHeader(
                  'Afternoon Session', Icons.wb_sunny_outlined, Colors.blue),
              const SizedBox(height: 12),
              _buildSessionContainer(
                  afternoonSlots, Colors.blue.withOpacity(0.1)),
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
                // Save scroll position before updating time
                if (_scrollController.hasClients) {
                  _savedScrollPosition = _scrollController.position.pixels;
                }
                
                setState(() {
                  _selectedTime = time;
                });
                
                // Restore scroll position after setState
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.jumpTo(_savedScrollPosition);
                  }
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
        scrollPadding: EdgeInsets.zero, // Prevent automatic scrolling to this field
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
        value: value,
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
        onChanged: (newValue) {
          // Save scroll position before dropdown change
          if (_scrollController.hasClients) {
            _savedScrollPosition = _scrollController.position.pixels;
          }
          
          // Call the original onChanged callback
          onChanged(newValue);
          
          // Restore scroll position after setState
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.jumpTo(_savedScrollPosition);
            }
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F5),
      body: SingleChildScrollView(
        controller: _scrollController,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const ClampingScrollPhysics(), // Prevents bouncing and maintains position
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

              // DOCTOR INFO CONTAINER
              _isLoadingFacility
                  ? Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFE3F2FD),
                            Color(0xFFBBDEFB),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1976D2)),
                        ),
                      ),
                    )
                  : Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFE3F2FD),
                            Color(0xFFBBDEFB),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.person_outline,
                              color: Color(0xFF1976D2),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Doctor',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF546E7A),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Dr. ${widget.doctor.name}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1F2937),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _facilityName,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF1976D2),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.location_on_outlined,
                                      size: 12,
                                      color: Color(0xFF546E7A),
                                    ),
                                    const SizedBox(width: 3),
                                    Expanded(
                                      child: Text(
                                        _facilityAddress,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF546E7A),
                                          height: 1.3,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                FutureBuilder<Map<String, String>>(
                                  future: _getDoctorScheduleInfo(),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                                      final scheduleData = snapshot.data!;
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFFFFB74D), Color(0xFFFF9800)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(8),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFFFF9800).withOpacity(0.3),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            const Icon(
                                              Icons.access_time_rounded,
                                              size: 18,
                                              color: Colors.white,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Schedule: ${scheduleData['schedule'] ?? ''}',
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.white,
                                                      height: 1.3,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    scheduleData['session'] ?? '',
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w500,
                                                      color: Colors.white,
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
                                    return const SizedBox.shrink();
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
              const SizedBox(height: 12),

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
              _customTextField(_addressController, 'Complete Address',
                  keyboardType: TextInputType.streetAddress),
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
