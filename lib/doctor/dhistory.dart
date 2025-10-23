import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tb_frontend/doctor/viewhistory.dart';
import 'package:tb_frontend/doctor/historyarchived.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'dart:io';
import 'dart:ui' show ImageFilter;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';

class Dhistory extends StatefulWidget {
  const Dhistory({super.key});

  @override
  State<Dhistory> createState() => _DhistoryState();
}

class _DhistoryState extends State<Dhistory> {
  String? _currentDoctorId;
  bool _isSelectionMode = false;
  final Set<String> _selectedAppointments = {};

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ));
    _getCurrentDoctorId();
  }

  Future<void> _getCurrentDoctorId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _currentDoctorId = user.uid;
      });
    }
  }

  void _toggleSelectionMode(String appointmentId) {
    setState(() {
      if (!_isSelectionMode) {
        _isSelectionMode = true;
        _selectedAppointments.add(appointmentId);
      }
    });
  }

  void _toggleSelection(String appointmentId) {
    setState(() {
      if (_selectedAppointments.contains(appointmentId)) {
        _selectedAppointments.remove(appointmentId);
        if (_selectedAppointments.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedAppointments.add(appointmentId);
      }
    });
  }

  void _cancelSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedAppointments.clear();
    });
  }

  Future<void> _archiveSelectedAppointments() async {
    if (_selectedAppointments.isEmpty) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.archive_rounded, color: Colors.orange, size: 24),
            ),
            const SizedBox(width: 12),
            const Text(
              'Archive History',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to archive ${_selectedAppointments.length} history item(s)?',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text(
              'Archive',
              style: TextStyle(color: Colors.white, fontSize: 15),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Show loading
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Text('Archiving ${_selectedAppointments.length} item(s)...'),
              ],
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Archive each selected appointment
      for (String appointmentId in _selectedAppointments) {
        // Check if it's from appointment_history or completed_appointments
        final historyDoc = await FirebaseFirestore.instance
            .collection('appointment_history')
            .doc(appointmentId)
            .get();

        if (historyDoc.exists) {
          // Update in appointment_history
          await FirebaseFirestore.instance
              .collection('appointment_history')
              .doc(appointmentId)
              .update({
            'archived': true,
            'archivedAt': FieldValue.serverTimestamp(),
          });
        } else {
          // Update in completed_appointments
          await FirebaseFirestore.instance
              .collection('completed_appointments')
              .doc(appointmentId)
              .update({
            'archived': true,
            'archivedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      // Exit selection mode
      setState(() {
        _isSelectionMode = false;
        _selectedAppointments.clear();
      });

      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.check_circle, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Text('History archived successfully'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error archiving history: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  // Show export options dialog
  Future<void> _showExportDialog() async {
    final now = DateTime.now();
    DateTime? startDate;
    DateTime? endDate;
    
    final result = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        elevation: 16,
        backgroundColor: Colors.white,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4CAF50).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.download_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Export Patient Data',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Select time range for export',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Options
              _buildExportOption(
                context,
                'Daily',
                'Today\'s patients',
                Icons.today,
                Colors.blue,
              ),
              const SizedBox(height: 10),
              _buildExportOption(
                context,
                'Weekly',
                'Last 7 days',
                Icons.date_range,
                Colors.purple,
              ),
              const SizedBox(height: 10),
              _buildExportOption(
                context,
                'Monthly',
                'This month',
                Icons.calendar_month,
                Colors.orange,
              ),
              const SizedBox(height: 10),
              _buildExportOption(
                context,
                'Yearly',
                'This year',
                Icons.calendar_today,
                Colors.green,
              ),
              const SizedBox(height: 10),
              _buildExportOption(
                context,
                'Custom',
                'Select date range',
                Icons.event_note,
                Colors.red,
              ),
              const SizedBox(height: 20),
              // Cancel Button
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (result != null && mounted) {
      if (result == 'Custom') {
        // Show ultra-modern floating date range picker with circular day cells
        final DateTimeRange? picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: now,
          initialEntryMode: DatePickerEntryMode.calendarOnly, // Disable text input mode (removes pencil icon)
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(
                  primary: Color(0xFFE53935), // Vibrant red
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: Color(0xFF2D2D2D),
                  secondary: Color(0xFFE53935),
                  onSecondary: Colors.white,
                ),
                dialogBackgroundColor: Colors.transparent,
                dialogTheme: DialogThemeData(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32),
                  ),
                ),
                datePickerTheme: DatePickerThemeData(
                  backgroundColor: Colors.white,
                  elevation: 28,
                  shadowColor: const Color(0xFFE53935).withOpacity(0.15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32),
                  ),
                  // Compact header aligned with X button
                  headerBackgroundColor: const Color(0xFFE53935),
                  headerForegroundColor: Colors.white,
                  headerHeadlineStyle: const TextStyle(
                    fontSize: 18, // Compact "Select Range" text
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.5,
                    height: 1.3,
                  ),
                  headerHelpStyle: TextStyle(
                    fontSize: 12, // Very small for "Start Date - End Date"
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withOpacity(0.85),
                    letterSpacing: 0.3,
                    height: 1.3,
                  ),
                  // Range picker styling
                  rangePickerBackgroundColor: Colors.white,
                  rangePickerHeaderBackgroundColor: const Color(0xFFE53935),
                  rangePickerHeaderForegroundColor: Colors.white,
                  rangePickerHeaderHeadlineStyle: const TextStyle(
                    fontSize: 18, // Compact header text
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.5,
                    height: 1.3,
                  ),
                  rangePickerHeaderHelpStyle: TextStyle(
                    fontSize: 12, // Very small date range text fits in 1 line
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withOpacity(0.85),
                    letterSpacing: 0.3,
                    height: 1.3,
                  ),
                  // Soft range selection background
                  rangeSelectionBackgroundColor: const Color(0xFFFFEBEE),
                  rangeSelectionOverlayColor: MaterialStateProperty.all(
                    const Color(0xFFE53935).withOpacity(0.06),
                  ),
                  // Modern day cell styling with enhanced bubble effect
                  dayStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                  // Today indicator - Bright pink bubble with red border
                  todayBackgroundColor: MaterialStateProperty.resolveWith((states) {
                    if (states.contains(MaterialState.selected)) {
                      return const Color(0xFFE53935); // Solid red when selected
                    }
                    return const Color(0xFFFFCDD2); // Brighter pink bubble
                  }),
                  todayForegroundColor: MaterialStateProperty.resolveWith((states) {
                    if (states.contains(MaterialState.selected)) {
                      return Colors.white;
                    }
                    return const Color(0xFFE53935);
                  }),
                  todayBorder: const BorderSide(
                    color: Color(0xFFE53935),
                    width: 2.5,
                  ),
                  // Enhanced bubble background for ALL day cells
                  dayBackgroundColor: MaterialStateProperty.resolveWith((states) {
                    if (states.contains(MaterialState.selected)) {
                      return const Color(0xFFE53935); // Vibrant red bubble when selected
                    }
                    if (states.contains(MaterialState.hovered)) {
                      return const Color(0xFFFFEBEE); // Light pink bubble on hover
                    }
                    return const Color(0xFFF5F5F5); // Soft grey bubble background
                  }),
                  dayForegroundColor: MaterialStateProperty.resolveWith((states) {
                    if (states.contains(MaterialState.selected)) {
                      return Colors.white;
                    }
                    if (states.contains(MaterialState.disabled)) {
                      return Colors.grey.shade300;
                    }
                    return const Color(0xFF2D2D2D);
                  }),
                  dayOverlayColor: MaterialStateProperty.all(
                    const Color(0xFFE53935).withOpacity(0.08),
                  ),
                  // Clean, modern weekday labels (S  M  T  W  T  F  S)
                  weekdayStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF757575),
                    letterSpacing: 2.0,
                  ),
                  // Very subtle divider
                  dividerColor: const Color(0xFFF0F0F0),
                ),
                textButtonTheme: TextButtonThemeData(
                  style: ButtonStyle(
                    foregroundColor: WidgetStateProperty.all(const Color(0xFFE53935)),
                    textStyle: WidgetStateProperty.all(
                      const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        letterSpacing: 1.0,
                      ),
                    ),
                    padding: WidgetStateProperty.all(
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                    ),
                    minimumSize: WidgetStateProperty.all(const Size(100, 48)),
                    shape: WidgetStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.hovered)) {
                        return const Color(0xFFFFEBEE);
                      }
                      return Colors.transparent;
                    }),
                    overlayColor: WidgetStateProperty.all(
                      const Color(0xFFE53935).withOpacity(0.08),
                    ),
                    elevation: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.hovered)) {
                        return 2.0;
                      }
                      return 0.0;
                    }),
                  ),
                ),
              ),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(
                    maxWidth: 420,
                    maxHeight: 650,
                  ),
                  margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white,
                        Colors.grey.shade50,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE53935).withOpacity(0.15),
                        blurRadius: 40,
                        spreadRadius: 0,
                        offset: const Offset(0, 20),
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 20,
                        spreadRadius: 0,
                        offset: const Offset(0, 10),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white.withOpacity(0.8),
                      width: 1.5,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: child!,
                    ),
                  ),
                ),
              ),
            );
          },
        );
        
        if (picked != null) {
          startDate = picked.start;
          endDate = picked.end;
          await _exportToCSV(startDate, endDate);
        }
      } else {
        // Calculate date range based on selection
        switch (result) {
          case 'Daily':
            startDate = DateTime(now.year, now.month, now.day);
            endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
            break;
          case 'Weekly':
            startDate = now.subtract(const Duration(days: 7));
            endDate = now;
            break;
          case 'Monthly':
            startDate = DateTime(now.year, now.month, 1);
            endDate = now;
            break;
          case 'Yearly':
            startDate = DateTime(now.year, 1, 1);
            endDate = now;
            break;
        }
        
        if (startDate != null && endDate != null) {
          await _exportToCSV(startDate, endDate);
        }
      }
    }
  }

  Widget _buildExportOption(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.pop(context, title),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: color),
          ],
        ),
      ),
    );
  }

  Future<void> _exportToCSV(DateTime startDate, DateTime endDate) async {
    try {
      // Show loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 12),
                Text('Generating report...'),
              ],
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }

      // Fetch data within date range
      final historySnapshot = await FirebaseFirestore.instance
          .collection('appointment_history')
          .where('doctorId', isEqualTo: _currentDoctorId)
          .get();

      final completedSnapshot = await FirebaseFirestore.instance
          .collection('completed_appointments')
          .where('doctorId', isEqualTo: _currentDoctorId)
          .get();

      List<List<dynamic>> rows = [];
      
      // Add headers
      rows.add([
        'Patient Name',
        'Appointment Date',
        'Appointment Time',
        'Completed Date',
        'Completed Time',
        'Status',
        'Treatment Type',
        'Treatment Completed',
        'Source',
        'Notes',
      ]);

      // Process history appointments
      for (var doc in historySnapshot.docs) {
        final data = doc.data();
        
        // Get appointment date/time
        DateTime? appointmentDateTime;
        if (data['appointmentDate'] != null) {
          appointmentDateTime = (data['appointmentDate'] as Timestamp).toDate();
        }
        
        // Get completion date
        DateTime? completionDateTime;
        if (data['treatmentCompletedAt'] != null) {
          completionDateTime = (data['treatmentCompletedAt'] as Timestamp).toDate();
        } else if (data['movedToHistoryAt'] != null) {
          completionDateTime = (data['movedToHistoryAt'] as Timestamp).toDate();
        } else if (data['completedAt'] != null) {
          completionDateTime = (data['completedAt'] as Timestamp).toDate();
        }

        // Filter by date range
        if (completionDateTime != null &&
            completionDateTime.isAfter(startDate.subtract(const Duration(days: 1))) &&
            completionDateTime.isBefore(endDate.add(const Duration(days: 1)))) {
          rows.add([
            data['patientName'] ?? 'Unknown',
            appointmentDateTime != null ? DateFormat('yyyy-MM-dd').format(appointmentDateTime) : 'N/A',
            appointmentDateTime != null ? DateFormat('HH:mm').format(appointmentDateTime) : 'N/A',
            DateFormat('yyyy-MM-dd').format(completionDateTime),
            DateFormat('HH:mm').format(completionDateTime),
            'Treatment Completed',
            data['treatmentType'] ?? 'N/A',
            'Yes',
            'History',
            data['notes'] ?? '',
          ]);
        }
      }

      // Process completed appointments
      for (var doc in completedSnapshot.docs) {
        final data = doc.data();
        
        // Get appointment date/time
        DateTime? appointmentDateTime;
        if (data['appointmentDate'] != null) {
          appointmentDateTime = (data['appointmentDate'] as Timestamp).toDate();
        }
        
        // Get completion date
        DateTime? completionDateTime;
        if (data['completedAt'] != null) {
          completionDateTime = (data['completedAt'] as Timestamp).toDate();
        }

        // Filter by date range and exclude archived
        if (completionDateTime != null &&
            data['archived'] != true &&
            completionDateTime.isAfter(startDate.subtract(const Duration(days: 1))) &&
            completionDateTime.isBefore(endDate.add(const Duration(days: 1)))) {
          
          // Determine status
          String status = 'Post-Appointment';
          if (data['treatmentCompleted'] == true) {
            status = 'Treatment Completed';
          } else if (data['hasPrescription'] == true) {
            status = 'Completed with Prescription';
          }
          
          rows.add([
            data['patientName'] ?? 'Unknown',
            appointmentDateTime != null ? DateFormat('yyyy-MM-dd').format(appointmentDateTime) : 'N/A',
            appointmentDateTime != null ? DateFormat('HH:mm').format(appointmentDateTime) : 'N/A',
            DateFormat('yyyy-MM-dd').format(completionDateTime),
            DateFormat('HH:mm').format(completionDateTime),
            status,
            data['treatmentType'] ?? 'N/A',
            data['treatmentCompleted'] == true ? 'Yes' : 'No',
            'Post-Consultation',
            data['notes'] ?? '',
          ]);
        }
      }

      if (rows.length == 1) {
        // Only headers, no data
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('No patient data found for selected date range'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
        return;
      }

      // Convert to CSV
      String csv = const ListToCsvConverter().convert(rows);

      // Handle permissions for Android
      if (Platform.isAndroid) {
        var status = await Permission.manageExternalStorage.status;
        if (!status.isGranted) {
          status = await Permission.manageExternalStorage.request();
        }
        
        // Fallback to storage permission
        if (!status.isGranted) {
          var storageStatus = await Permission.storage.status;
          if (!storageStatus.isGranted) {
            storageStatus = await Permission.storage.request();
          }
          
          if (!storageStatus.isGranted) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Storage permission required to save file'),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            }
            return;
          }
        }
      }

      // Get directory - save to public Downloads folder
      final fileName = 'patient_report_${DateFormat('yyyy-MM-dd').format(startDate)}_to_${DateFormat('yyyy-MM-dd').format(endDate)}.csv';
      
      String filePath;
      if (Platform.isAndroid) {
        // For Android: Save to public Downloads folder
        // This makes it accessible in File Manager > Downloads
        final directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
        filePath = '${directory.path}/$fileName';
      } else {
        // For iOS: Use documents directory
        final directory = await getApplicationDocumentsDirectory();
        filePath = '${directory.path}/$fileName';
      }

      // Write file
      final file = File(filePath);
      await file.writeAsString(csv);

      debugPrint('File saved at: $filePath');

      // Show success and file options dialog
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.check_circle, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '✓ Saved to Downloads!',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Found ${rows.length - 1} patients',
                        style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Check File Manager > Downloads',
                        style: TextStyle(fontSize: 10, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            action: SnackBarAction(
              label: 'OPTIONS',
              textColor: Colors.white,
              onPressed: () {
                _showFileOptionsDialog(filePath, fileName);
              },
            ),
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error exporting data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating report: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  // Show file options dialog
  void _showFileOptionsDialog(String filePath, String fileName) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        elevation: 16,
        backgroundColor: Colors.white,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4CAF50).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.file_present_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Report Ready',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Choose how to view',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // File info
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.insert_drive_file, size: 16, color: Colors.green.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        fileName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade900,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Options
              Column(
                children: [
                  // Open with Excel/Sheets
                  _buildFileOption(
                    icon: Icons.table_chart_rounded,
                    iconColor: Colors.green,
                    title: 'Open with Excel/Sheets',
                    subtitle: 'View in spreadsheet app',
                    onTap: () async {
                      Navigator.pop(context);
                      try {
                        // Show loading
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Row(
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text('Opening file...'),
                                ],
                              ),
                              duration: Duration(seconds: 2),
                              backgroundColor: Colors.blue,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                        
                        // Open file with system default app
                        final result = await OpenFile.open(
                          filePath,
                          type: 'text/csv',
                        );
                        
                        debugPrint('Open file result: ${result.type} - ${result.message}');
                        
                        if (result.type == ResultType.done) {
                          // Success - file opened
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Row(
                                  children: [
                                    Icon(Icons.check_circle, color: Colors.white),
                                    SizedBox(width: 12),
                                    Text('File opened successfully!'),
                                  ],
                                ),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        } else if (result.type == ResultType.noAppToOpen) {
                          // No app found
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'No spreadsheet app found!',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Please install Excel, Google Sheets, or WPS Office',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                                backgroundColor: Colors.orange,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                duration: const Duration(seconds: 5),
                              ),
                            );
                          }
                        } else {
                          // Other error
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Unable to open file: ${result.message}'),
                                backgroundColor: Colors.orange,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        debugPrint('Error opening file: $e');
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Error opening file',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'File saved at: $fileName',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        }
                      }
                    },
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Share file
                  _buildFileOption(
                    icon: Icons.share_rounded,
                    iconColor: Colors.blue,
                    title: 'Share via...',
                    subtitle: 'Send via WhatsApp, Email, etc.',
                    onTap: () async {
                      Navigator.pop(context);
                      try {
                        final result = await Share.shareXFiles(
                          [XFile(filePath)],
                          text: 'TB Patient Report - $fileName',
                          subject: 'TB Patient Report',
                        );
                        
                        debugPrint('Share result: ${result.status}');
                        
                        if (result.status == ShareResultStatus.success) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Row(
                                  children: [
                                    Icon(Icons.check_circle, color: Colors.white),
                                    SizedBox(width: 12),
                                    Text('File shared successfully!'),
                                  ],
                                ),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        debugPrint('Error sharing file: $e');
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error sharing file: $e'),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Close button
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Close',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper widget for file options
  Widget _buildFileOption({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: iconColor.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: iconColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: iconColor),
          ],
        ),
      ),
    );
  }

  // Load appointments from history collection
  Stream<List<Map<String, dynamic>>> _getHistoryStream() {
    if (_currentDoctorId == null) {
      return Stream.value([]);
    }

    return FirebaseFirestore.instance
        .collection('appointment_history')
        .where('doctorId', isEqualTo: _currentDoctorId)
        .snapshots()
        .asyncMap((snapshot) async {
      List<Map<String, dynamic>> allAppointments = [];

      // Get appointments from appointment_history collection (fully completed treatments)
      for (var doc in snapshot.docs) {
        final data = doc.data();
        // Filter out archived items
        if (data['archived'] != true) {
          data['id'] = doc.id;
          data['source'] = 'appointment_history';
          allAppointments.add(data);
        }
      }

      // Also get appointments from completed_appointments collection (post-consultation appointments)
      final completedAppointmentsSnapshot = await FirebaseFirestore.instance
          .collection('completed_appointments')
          .where('doctorId', isEqualTo: _currentDoctorId)
          .get();

      for (var doc in completedAppointmentsSnapshot.docs) {
        final data = doc.data();
        // Filter out archived items and those already processed to history
        if (data['archived'] != true && data['processedToHistory'] != true) {
          data['id'] = doc.id;
          data['source'] = 'completed_appointments';
          allAppointments.add(data);
        }
      }

      // History shows all post-consultation appointments: both completed meetings and fully completed treatments

      // Sort by most relevant timestamp (prioritize treatment completed appointments)
      allAppointments.sort((a, b) {
        // Get the most relevant timestamp for each appointment
        final timestampA = a['treatmentCompletedAt'] ??
            a['movedToHistoryAt'] ??
            a['completedAt'] ??
            a['approvedAt'] ??
            a['rejectedAt'];
        final timestampB = b['treatmentCompletedAt'] ??
            b['movedToHistoryAt'] ??
            b['completedAt'] ??
            b['approvedAt'] ??
            b['rejectedAt'];

        if (timestampA == null && timestampB == null) return 0;
        if (timestampA == null) return 1;
        if (timestampB == null) return -1;

        // Sort descending (newest first)
        return timestampB.compareTo(timestampA);
      });

      return allAppointments;
    });
  }

  // ✅ Show appointment details in full screen
  void _showAppointmentDetails(Map<String, dynamic> appointment) async {
    // Fetch additional data similar to dpost.dart
    final originalAppointmentId =
        appointment['appointmentId'] ?? appointment['id'];

    // Fetch prescription data for this appointment
    Map<String, dynamic>? prescriptionData;
    if (appointment['prescriptionData'] != null) {
      // Use existing prescription data if already available
      prescriptionData = appointment['prescriptionData'];
    } else {
      // Fetch prescription data from collection
      try {
        final prescriptionSnapshot = await FirebaseFirestore.instance
            .collection('prescriptions')
            .where('appointmentId', isEqualTo: originalAppointmentId)
            .get();

        if (prescriptionSnapshot.docs.isNotEmpty) {
          prescriptionData = prescriptionSnapshot.docs.first.data();
        }
      } catch (e) {
        debugPrint('Error fetching prescription data: $e');
      }
    }

    // Fetch certificate data for this appointment
    Map<String, dynamic>? certificateData;
    if (appointment['certificateData'] != null) {
      // Use existing certificate data if already available
      certificateData = appointment['certificateData'];
    } else {
      // Fetch certificate data from collection
      try {
        final certificateSnapshot = await FirebaseFirestore.instance
            .collection('certificates')
            .where('appointmentId', isEqualTo: originalAppointmentId)
            .get();

        if (certificateSnapshot.docs.isNotEmpty) {
          certificateData = certificateSnapshot.docs.first.data();
        }
      } catch (e) {
        debugPrint('Error fetching certificate data: $e');
      }
    }

    // Fetch doctor information from doctors collection
    Map<String, dynamic>? doctorData;
    if (appointment['doctorId'] != null) {
      try {
        final doctorDoc = await FirebaseFirestore.instance
            .collection('doctors')
            .doc(appointment['doctorId'])
            .get();

        if (doctorDoc.exists) {
          doctorData = doctorDoc.data();
        }
      } catch (e) {
        debugPrint('Error fetching doctor data: $e');
      }
    }

    if (context.mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Viewhistory(
            appointment: {
              ...appointment,
              'prescriptionData': prescriptionData,
              'certificateData': certificateData,
              'doctorData': doctorData,
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 20, 0, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Back Button or Cancel Button
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
                          icon: Icon(
                            _isSelectionMode ? Icons.close : Icons.arrow_back_ios,
                            color: const Color(0xE0F44336),
                          ),
                          onPressed: () {
                            if (_isSelectionMode) {
                              _cancelSelectionMode();
                            } else {
                              Navigator.pop(context);
                            }
                          },
                        ),
                      ),

                      // Title
                      Text(
                        _isSelectionMode 
                            ? "${_selectedAppointments.length} Selected"
                            : "Appointment History",
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xE0F44336),
                        ),
                      ),

                      // Archive Button or Check Button
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, animation) {
                          return ScaleTransition(scale: animation, child: child);
                        },
                        child: _isSelectionMode
                            ? Container(
                                key: const ValueKey('check_button'),
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFFF9800), Color(0xFFFF6F00)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.orange.withOpacity(0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.check_rounded,
                                      color: Colors.white),
                                  onPressed: _selectedAppointments.isNotEmpty
                                      ? _archiveSelectedAppointments
                                      : null,
                                ),
                              )
                            : Container(
                                key: const ValueKey('archive_button'),
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
                                  icon: const Icon(
                                    Icons.archive_outlined,
                                    color: Color(0xFFFF9800),
                                    size: 24,
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const Historyarchived(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // StreamBuilder for history data
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _getHistoryStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error loading history: ${snapshot.error}',
                          style: const TextStyle(color: Colors.red),
                        ),
                      );
                    }

                    final appointments = snapshot.data ?? [];

                    // Only show items that are either Treatment Completed or Rejected
                    List<Map<String, dynamic>> filteredAppointments = appointments.where((appointment) {
                      try {
                        // From appointment_history: treat as Treatment Completed when movedToHistoryAt or treatmentCompletedAt exists
                        if (appointment['source'] == 'appointment_history') {
                          // Include treatment completed, movedToHistory, or explicitly marked incomplete consultations
                          if (appointment['treatmentCompletedAt'] != null || appointment['movedToHistoryAt'] != null) {
                            return true;
                          }
                          if ((appointment['status'] ?? '').toString().toLowerCase() == 'incomplete_consultation') return true;
                          if (appointment['incompleteMarkedAt'] != null) return true;
                        }

                        // From completed_appointments: treat as Treatment Completed when a boolean flag is present
                        if (appointment['source'] == 'completed_appointments') {
                          if (appointment['treatmentCompleted'] == true) return true;
                          if ((appointment['status'] ?? '').toString().toLowerCase() == 'treatment_completed') return true;
                          if ((appointment['status'] ?? '').toString().toLowerCase() == 'incomplete_consultation') return true;
                        }

                        // Rejected: presence of rejectedAt or explicit status
                        if (appointment['rejectedAt'] != null) return true;
                        if ((appointment['status'] ?? '').toString().toLowerCase() == 'rejected') return true;
                      } catch (e) {
                        // If any unexpected structure, exclude by default
                        debugPrint('Error while filtering appointment: $e');
                      }
                      return false;
                    }).toList();

                    if (filteredAppointments.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: Column(
                            children: [
                              Icon(
                                Icons.history,
                                size: 64,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                "No appointment history yet.",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                "Completed consultations and treatments will appear here",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                            ],
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

                        // Determine status based on source
                        String statusDisplayText = 'Unknown';
                        Color statusColor = Colors.orange;

                        // Different logic based on source collection
                        if (appointment['source'] == 'appointment_history') {
                          // From appointment_history - treatment completed
                          var treatmentCompletedAt =
                              appointment['treatmentCompletedAt'];
                          var movedToHistoryAt =
                              appointment['movedToHistoryAt'];

                          if (treatmentCompletedAt != null || movedToHistoryAt != null) {
                            statusDisplayText = 'Treatment Completed';
                            statusColor = Colors.purple;
                          }
                        } else {
                          // From completed_appointments - consultation completed, awaiting treatment completion
                          var completedAt = appointment['completedAt'];
                          if (completedAt != null) {
                            statusDisplayText = 'Consultation Completed';
                            statusColor = Colors.blue;
                          }
                        }

                        // Fallback logic for other statuses
                        if (statusDisplayText == 'Unknown') {
                          var approvedAt = appointment['approvedAt'];
                          var rejectedAt = appointment['rejectedAt'];

                          if (approvedAt != null) {
                            statusDisplayText = 'Approved';
                            statusColor = Colors.green;
                          } else if (rejectedAt != null) {
                            statusDisplayText = 'Rejected';
                            statusColor = Colors.red;
                          } else {
                            // Final fallback to appointment status
                            String status = appointment['status'] ?? 'unknown';
                            statusDisplayText =
                                status.replaceAll('_', ' ').toUpperCase();
                          }
                        }

                        // Check if appointment has prescription or certificate data
                        final hasPrescription =
                            appointment['prescriptionData'] != null;
                        final hasCertificate =
                            appointment['certificateData'] != null;
                        
                        final appointmentId = appointment['id'] as String;
                        final isSelected = _selectedAppointments.contains(appointmentId);

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: isSelected 
                                    ? Colors.orange.withOpacity(0.3)
                                    : Colors.grey.withOpacity(0.1),
                                blurRadius: isSelected ? 12 : 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                if (_isSelectionMode) {
                                  _toggleSelection(appointmentId);
                                } else {
                                  _showAppointmentDetails(appointment);
                                }
                              },
                              onLongPress: () {
                                if (!_isSelectionMode) {
                                  _toggleSelectionMode(appointmentId);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: isSelected 
                                        ? Colors.orange
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  children: [
                                    // Checkbox (appears in selection mode)
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 300),
                                      width: _isSelectionMode ? 32 : 0,
                                      height: 32,
                                      margin: EdgeInsets.only(
                                        right: _isSelectionMode ? 12 : 0,
                                      ),
                                      child: _isSelectionMode
                                          ? Transform.scale(
                                              scale: 1.2,
                                              child: Checkbox(
                                                value: isSelected,
                                                onChanged: (value) {
                                                  _toggleSelection(appointmentId);
                                                },
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                activeColor: Colors.orange,
                                                side: BorderSide(
                                                  color: Colors.grey.shade400,
                                                  width: 2,
                                                ),
                                              ),
                                            )
                                          : null,
                                    ),
                                    
                                    // Avatar
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            statusColor.withOpacity(0.8),
                                            statusColor,
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: statusColor.withOpacity(0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: Text(
                                          appointment["patientName"]
                                                  ?.substring(0, 1)
                                                  .toUpperCase() ??
                                              "P",
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 20,
                                          ),
                                        ),
                                      ),
                                    ),
                                    
                                    const SizedBox(width: 16),
                                    
                                    // Content
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  appointment["patientName"] ??
                                                      "Unknown Patient",
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                    color: Color(0xFF1F2937),
                                                  ),
                                                ),
                                              ),
                                              // Show indicators for prescription and certificate
                                              if (hasPrescription)
                                                Container(
                                                  margin: const EdgeInsets.only(left: 4),
                                                  padding: const EdgeInsets.all(6),
                                                  decoration: BoxDecoration(
                                                    color: Colors.blue.shade100,
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: const Icon(
                                                    Icons.medical_services,
                                                    size: 14,
                                                    color: Colors.blue,
                                                  ),
                                                ),
                                              if (hasCertificate)
                                                Container(
                                                  margin: const EdgeInsets.only(left: 4),
                                                  padding: const EdgeInsets.all(6),
                                                  decoration: BoxDecoration(
                                                    color: Colors.purple.shade100,
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: const Icon(
                                                    Icons.card_membership,
                                                    size: 14,
                                                    color: Colors.purple,
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: statusColor.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              statusDisplayText,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: statusColor,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    
                                    // Trailing icon
                                    if (!_isSelectionMode)
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          Icons.arrow_forward_ios_rounded,
                                          size: 16,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showExportDialog,
        backgroundColor: const Color(0xFF4CAF50),
        elevation: 6,
        icon: const Icon(Icons.download_rounded, color: Colors.white),
        label: const Text(
          'Export',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
