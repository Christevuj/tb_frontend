import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:printing/printing.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:http/http.dart' as http;

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

  // Filter for appointments
  String _selectedFilter = 'All'; // Updated filter options

  // Available filter options
  final List<Map<String, dynamic>> _filterOptions = [
    {
      'key': 'All',
      'label': 'All',
      'icon': Icons.list,
      'color': Colors.blue,
    },
    {
      'key': 'Pending',
      'label': 'Pending',
      'icon': Icons.pending,
      'color': Colors.amber,
    },
    {
      'key': 'Approved',
      'label': 'Approved',
      'icon': Icons.check_circle,
      'color': Colors.green,
    },
    {
      'key': 'Consultation Completed',
      'label': 'Consultation\nCompleted',
      'icon': Icons.medical_services,
      'color': Colors.orange,
    },
    {
      'key': 'Treatment Completed',
      'label': 'Treatment\nCompleted',
      'icon': Icons.verified,
      'color': Colors.purple,
    },
    {
      'key': 'Rejected',
      'label': 'Rejected',
      'icon': Icons.cancel,
      'color': Colors.red,
    },
  ];

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
        data['appointmentSource'] = 'pending';
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
        data['appointmentSource'] = 'approved';
        allAppointments.add(data);
      }

      // Get completed appointments
      final completedSnapshot = await FirebaseFirestore.instance
          .collection('completed_appointments')
          .where('patientUid', isEqualTo: _currentPatientId)
          .get();

      for (var doc in completedSnapshot.docs) {
        final data = doc.data();

        // Check if certificate has been sent to determine status
        bool certificateSent = false;
        try {
          final notificationSnapshot = await FirebaseFirestore.instance
              .collection('patient_notifications')
              .where('patientUid', isEqualTo: _currentPatientId)
              .where('appointmentId', isEqualTo: data['appointmentId'])
              .where('type', isEqualTo: 'certificate_available')
              .get();

          certificateSent = notificationSnapshot.docs.isNotEmpty;
        } catch (e) {
          debugPrint('Error checking certificate status: $e');
        }

        data['status'] =
            certificateSent ? 'treatment_completed' : 'consultation_finished';
        data['id'] = doc.id;
        data['appointmentSource'] = 'completed';
        data['certificateSent'] = certificateSent;
        allAppointments.add(data);
      }

      // Get rejected appointments
      final rejectedSnapshot = await FirebaseFirestore.instance
          .collection('rejected_appointments')
          .where('patientUid', isEqualTo: _currentPatientId)
          .get();

      for (var doc in rejectedSnapshot.docs) {
        final data = doc.data();
        data['status'] = 'rejected';
        data['id'] = doc.id;
        data['appointmentSource'] = 'rejected';
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

  String _getDoctorName(Map<String, dynamic>? doctorData) {
    if (doctorData == null) return 'Doctor Name';

    // Try different possible field combinations
    if (doctorData['fullName'] != null) {
      return 'Dr. ${doctorData['fullName']}';
    } else if (doctorData['firstName'] != null &&
        doctorData['lastName'] != null) {
      return 'Dr. ${doctorData['firstName']} ${doctorData['lastName']}';
    } else if (doctorData['firstName'] != null) {
      return 'Dr. ${doctorData['firstName']}';
    } else if (doctorData['doctorName'] != null) {
      return '${doctorData['doctorName']}';
    } else {
      return 'Dr. Doctor';
    }
  }

  Future<void> _deleteRejectedAppointment(
      Map<String, dynamic> appointment) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Rejected Appointment'),
          content: const Text(
              'Are you sure you want to delete this rejected appointment? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        // Delete from rejected_appointments collection
        await FirebaseFirestore.instance
            .collection('rejected_appointments')
            .doc(appointment['id'])
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Rejected appointment deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        debugPrint('Error deleting rejected appointment: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting appointment: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showAppointmentDetails(Map<String, dynamic> appointment) async {
    // For completed appointments, fetch additional data
    Map<String, dynamic>? prescriptionData;
    Map<String, dynamic>? doctorData;

    if (appointment['appointmentSource'] == 'completed') {
      // Fetch prescription data
      try {
        final appointmentId = appointment['appointmentId'] ?? appointment['id'];
        debugPrint('Fetching prescription for appointmentId: $appointmentId');

        final prescriptionSnapshot = await FirebaseFirestore.instance
            .collection('prescriptions')
            .where('appointmentId', isEqualTo: appointmentId)
            .get();

        debugPrint(
            'Prescription query results: ${prescriptionSnapshot.docs.length} documents found');

        if (prescriptionSnapshot.docs.isNotEmpty) {
          prescriptionData = prescriptionSnapshot.docs.first.data();
          debugPrint(
              'Prescription data found: ${prescriptionData['prescriptionDetails'] != null ? 'Has prescriptionDetails' : 'No prescriptionDetails'}');
          debugPrint('PDF Path: ${prescriptionData['pdfPath']}');
          debugPrint('PDF URL: ${prescriptionData['pdfUrl']}');
        } else {
          debugPrint(
              'No prescription documents found for appointmentId: $appointmentId');
        }
      } catch (e) {
        debugPrint('Error fetching prescription: $e');
      }

      // Fetch doctor data
      try {
        if (appointment['doctorId'] != null) {
          final doctorDoc = await FirebaseFirestore.instance
              .collection('doctors')
              .doc(appointment['doctorId'])
              .get();

          if (doctorDoc.exists) {
            doctorData = doctorDoc.data();
            debugPrint(
                'Doctor data fields: ${doctorData != null ? doctorData.keys.toList() : 'null'}');
            debugPrint(
                'Doctor fullName: ${doctorData != null ? doctorData['fullName'] : 'null'}');
            debugPrint(
                'Doctor firstName: ${doctorData != null ? doctorData['firstName'] : 'null'}');
            debugPrint(
                'Doctor lastName: ${doctorData != null ? doctorData['lastName'] : 'null'}');
            debugPrint(
                'Doctor doctorName: ${doctorData != null ? doctorData['doctorName'] : 'null'}');
          }
        }
      } catch (e) {
        debugPrint('Error fetching doctor data: $e');
      }
    }

    if (!mounted) return;

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

                // Status first - most important info
                _statusCard(appointment["status"]?.toString() ?? "N/A"),

                // Rejection reason for rejected appointments
                if (appointment["status"]?.toString() == "rejected" &&
                    appointment['rejectionReason'] != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.red.shade200, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.red.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.info_outline,
                                color: Colors.red.shade600,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              "Rejection Reason",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          appointment['rejectionReason'],
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.red.shade600,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Patient Details (for completed appointments, show more details)
                if (appointment['appointmentSource'] == 'completed') ...[
                  const SizedBox(height: 16),
                  const Text(
                    "Patient Information",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _infoCard(
                    icon: Icons.person,
                    iconBg: Colors.blue,
                    cardBg: Colors.blue.shade50,
                    value: appointment['patientName'] ?? 'Not available',
                    label: "Patient Name",
                  ),
                  _infoCard(
                    icon: Icons.email,
                    iconBg: Colors.teal,
                    cardBg: Colors.teal.shade50,
                    value: appointment['patientEmail'] ?? 'Not available',
                    label: "Email",
                  ),
                  _infoCard(
                    icon: Icons.phone,
                    iconBg: Colors.green,
                    cardBg: Colors.green.shade50,
                    value: appointment['patientPhone'] ?? 'Not available',
                    label: "Phone Number",
                  ),
                  if (appointment['patientAge'] != null)
                    _infoCard(
                      icon: Icons.calendar_today,
                      iconBg: Colors.orange,
                      cardBg: Colors.orange.shade50,
                      value: '${appointment['patientAge']} years',
                      label: "Age",
                    ),
                  if (appointment['patientGender'] != null)
                    _infoCard(
                      icon: Icons.person_outline,
                      iconBg: Colors.purple,
                      cardBg: Colors.purple.shade50,
                      value: appointment['patientGender'],
                      label: "Gender",
                    ),
                ],

                // Doctor Information
                const SizedBox(height: 16),
                const Text(
                  "Doctor Information",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                _infoCard(
                  icon: Icons.medical_services,
                  iconBg: Colors.teal,
                  cardBg: Colors.teal.shade50,
                  value: appointment['appointmentSource'] == 'completed' &&
                          doctorData != null
                      ? _getDoctorName(doctorData)
                      : (appointment['doctorName'] ??
                          appointment['doctor_name'] ??
                          'Not available'),
                  label: "Doctor Name",
                ),

                // Doctor address and experience (for completed appointments)
                if (appointment['appointmentSource'] == 'completed' &&
                    doctorData != null) ...[
                  if (doctorData['address'] != null)
                    _infoCard(
                      icon: Icons.location_on,
                      iconBg: Colors.red,
                      cardBg: Colors.red.shade50,
                      value: doctorData['address'],
                      label: "Doctor's Address",
                    ),
                  if (doctorData['experience'] != null)
                    _infoCard(
                      icon: Icons.badge,
                      iconBg: Colors.indigo,
                      cardBg: Colors.indigo.shade50,
                      value: '${doctorData['experience']} years experience',
                      label: "Experience",
                    ),
                ] else
                  // Fetch Doctor's Clinic Address for other appointments
                  FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('doctors')
                        .doc(
                            appointment["doctorId"] ?? appointment["doctor_id"])
                        .get(),
                    builder: (context, snapshot) {
                      String address = "Loading...";

                      if (snapshot.hasData && snapshot.data!.exists) {
                        final doctorData =
                            snapshot.data!.data() as Map<String, dynamic>;
                        if (doctorData["affiliations"] != null &&
                            (doctorData["affiliations"] as List).isNotEmpty) {
                          address = (doctorData["affiliations"][0]["address"] ??
                                  "No address")
                              .toString();
                        } else {
                          address = "No address available";
                        }
                      } else if (snapshot.hasError) {
                        address = "Error loading data";
                      }

                      return _infoCard(
                        icon: Icons.location_on,
                        iconBg: Colors.red,
                        cardBg: Colors.red.shade50,
                        value: address,
                        label: "Clinic Address",
                      );
                    },
                  ),

                // Appointment Schedule
                const SizedBox(height: 16),
                const Text(
                  "Schedule",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                _infoCard(
                  icon: Icons.calendar_today,
                  iconBg: Colors.indigo,
                  cardBg: Colors.indigo.shade50,
                  value: appointment['date'] != null
                      ? '${appointment['date'].day}/${appointment['date'].month}/${appointment['date'].year}'
                      : (appointment['appointmentDate'] != null
                          ? _formatDate(appointment['appointmentDate'])
                          : (appointment['appointment_date'] != null
                              ? _formatDate(appointment['appointment_date'])
                              : 'Not set')),
                  label: "Appointment Date",
                ),

                _infoCard(
                  icon: Icons.access_time,
                  iconBg: Colors.amber,
                  cardBg: Colors.amber.shade50,
                  value: appointment['appointment_time'] ??
                      appointment['appointmentTime'] ??
                      appointment['time'] ??
                      'Not set',
                  label: "Appointment Time",
                ),

                // Meeting Information
                if (appointment["status"]?.toString().toLowerCase() ==
                    "approved")
                  if ((appointment['meetingLink'] ??
                              appointment['jitsi_link'] ??
                              appointment['meeting_link']) !=
                          null &&
                      (appointment['meetingLink'] ??
                              appointment['jitsi_link'] ??
                              appointment['meeting_link'])
                          .toString()
                          .isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      "Meeting",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    _meetingCard(
                      url: (appointment['meetingLink'] ??
                              appointment['jitsi_link'] ??
                              appointment['meeting_link'])
                          .toString(),
                      onJoin: () async {
                        final Uri uri = Uri.parse((appointment['meetingLink'] ??
                                appointment['jitsi_link'] ??
                                appointment['meeting_link'])
                            .toString());
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
                    ),
                  ] else ...[
                    const SizedBox(height: 16),
                    _infoCard(
                      icon: Icons.link_off,
                      iconBg: Colors.grey,
                      cardBg: Colors.grey.shade200,
                      value: "No meeting link available yet",
                      label: "Meeting Link",
                    ),
                  ]
                else if (appointment["status"]?.toString().toLowerCase() ==
                    "pending") ...[
                  const SizedBox(height: 16),
                  _infoCard(
                    icon: Icons.schedule,
                    iconBg: Colors.orange,
                    cardBg: Colors.orange.shade50,
                    value: "Meeting will be available once approved",
                    label: "Meeting Status",
                  ),
                ],

                // Prescription Information (for completed appointments)
                if (appointment['appointmentSource'] == 'completed') ...[
                  const SizedBox(height: 16),
                  const Text(
                    "Treatment Information",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  if (prescriptionData != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.medical_services,
                                  color: Colors.green, size: 24),
                              const SizedBox(width: 8),
                              const Text(
                                'Prescription Available',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Check if it's the new prescription format with prescriptionDetails
                          if (prescriptionData['prescriptionDetails'] !=
                              null) ...[
                            // New prescription format
                            const Text(
                              'Prescription Details:',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Text(
                                prescriptionData['prescriptionDetails']
                                    .toString(),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),

                            // PDF viewing button
                            if (prescriptionData['pdfPath'] != null ||
                                (prescriptionData['pdfUrl'] != null &&
                                    prescriptionData['pdfUrl']
                                        .toString()
                                        .isNotEmpty)) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () =>
                                      _viewPrescriptionPdf(prescriptionData!),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  icon: const Icon(Icons.picture_as_pdf,
                                      size: 20),
                                  label: const Text('View Prescription PDF'),
                                ),
                              ),
                            ],
                          ] else ...[
                            // Old prescription format (medicines and notes)
                            _buildMedicinesSection(prescriptionData),

                            // Notes section
                            if (prescriptionData['notes'] != null) ...[
                              const SizedBox(height: 12),
                              const Text(
                                'Additional Instructions:',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(prescriptionData['notes'].toString()),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ] else ...[
                    _infoCard(
                      icon: Icons.info,
                      iconBg: Colors.grey,
                      cardBg: Colors.grey.shade50,
                      value: "No prescription data available",
                      label: "Prescription Status",
                    ),
                  ],

                  // Certificate Status
                  const SizedBox(height: 12),
                  if (appointment['certificateSent'] == true) ...[
                    _infoCard(
                      icon: Icons.verified,
                      iconBg: Colors.purple,
                      cardBg: Colors.purple.shade50,
                      value: "Treatment completion certificate available",
                      label: "Certificate Status",
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _viewCertificatePdf(appointment),
                        icon: const Icon(Icons.verified),
                        label: const Text('View Certificate PDF'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ] else ...[
                    _infoCard(
                      icon: Icons.pending,
                      iconBg: Colors.orange,
                      cardBg: Colors.orange.shade50,
                      value:
                          "Certificate will be available once issued by doctor",
                      label: "Certificate Status",
                    ),
                  ],
                ],
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

  // Status card with custom styling based on status
  Widget _statusCard(String status) {
    Color statusColor;
    Color bgColor;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'approved':
        statusColor = Colors.green;
        bgColor = Colors.green.shade50;
        icon = Icons.check_circle;
        break;
      case 'pending':
        statusColor = Colors.orange;
        bgColor = Colors.orange.shade50;
        icon = Icons.pending;
        break;
      case 'consultation_finished':
        statusColor = Colors.blue;
        bgColor = Colors.blue.shade50;
        icon = Icons.medical_services;
        break;
      case 'treatment_completed':
        statusColor = Colors.purple;
        bgColor = Colors.purple.shade50;
        icon = Icons.verified;
        break;
      case 'cancelled':
        statusColor = Colors.red;
        bgColor = Colors.red.shade50;
        icon = Icons.cancel;
        break;
      default:
        statusColor = Colors.grey;
        bgColor = Colors.grey.shade50;
        icon = Icons.help;
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(icon, color: Colors.white, size: 24),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
                const SizedBox(height: 4),
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

  // Meeting card with join button
  Widget _meetingCard({required String url, required VoidCallback onJoin}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Icon(Icons.videocam, color: Colors.white, size: 24),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Meeting Available",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Tap to join the virtual appointment",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onJoin,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text(
              "Join",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to build medicines section safely
  Widget _buildMedicinesSection(Map<String, dynamic> prescriptionData) {
    if (prescriptionData['medicines'] == null ||
        prescriptionData['medicines'] is! List) {
      return const SizedBox.shrink();
    }

    final medicinesList = prescriptionData['medicines'] as List;
    if (medicinesList.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Prescribed Medicines:',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ...medicinesList.asMap().entries.map((entry) {
          final index = entry.key;
          final medicine = entry.value as Map<String, dynamic>;

          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  medicine['name']?.toString() ?? 'Medicine ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (medicine['dosage'] != null)
                  Text('Dosage: ${medicine['dosage']}'),
                if (medicine['frequency'] != null)
                  Text('Frequency: ${medicine['frequency']}'),
              ],
            ),
          );
        }),
      ],
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

              // Filter carousel
              SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: _filterOptions.length,
                  itemBuilder: (context, index) {
                    final filter = _filterOptions[index];
                    final isSelected = _selectedFilter == filter['key'];

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _selectedFilter = filter['key'];
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isSelected
                              ? Colors.redAccent
                              : Colors.grey.shade200,
                          foregroundColor:
                              isSelected ? Colors.white : Colors.black54,
                          elevation: isSelected ? 3 : 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                        ),
                        icon: Icon(
                          filter['icon'],
                          size: 18,
                          color: isSelected ? Colors.white : Colors.black54,
                        ),
                        label: Text(
                          filter['label'].replaceAll('\n', ' '),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  },
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

                    // Filter appointments based on selected filter
                    List<Map<String, dynamic>> filteredAppointments;
                    switch (_selectedFilter) {
                      case 'Pending':
                        filteredAppointments = allAppointments
                            .where((appointment) =>
                                appointment['status'] == 'pending')
                            .toList();
                        break;
                      case 'Approved':
                        filteredAppointments = allAppointments
                            .where((appointment) =>
                                appointment['status'] == 'approved')
                            .toList();
                        break;
                      case 'Consultation Completed':
                        filteredAppointments = allAppointments
                            .where((appointment) =>
                                appointment['status'] ==
                                'consultation_finished')
                            .toList();
                        break;
                      case 'Treatment Completed':
                        filteredAppointments = allAppointments
                            .where((appointment) =>
                                appointment['status'] == 'treatment_completed')
                            .toList();
                        break;
                      case 'Rejected':
                        filteredAppointments = allAppointments
                            .where((appointment) =>
                                appointment['status'] == 'rejected')
                            .toList();
                        break;
                      case 'All':
                      default:
                        filteredAppointments = allAppointments;
                        break;
                    }

                    if (filteredAppointments.isEmpty) {
                      String emptyMessage;
                      switch (_selectedFilter) {
                        case 'Pending':
                          emptyMessage = 'No pending appointments found';
                          break;
                        case 'Approved':
                          emptyMessage = 'No approved appointments found';
                          break;
                        case 'Consultation Completed':
                          emptyMessage =
                              'No consultation completed appointments found';
                          break;
                        case 'Treatment Completed':
                          emptyMessage =
                              'No treatment completed appointments found';
                          break;
                        case 'Rejected':
                          emptyMessage = 'No rejected appointments found';
                          break;
                        default:
                          emptyMessage = 'No appointments found';
                          break;
                      }

                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            emptyMessage,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ),
                      );
                    }

                    return Column(
                      children: filteredAppointments.map((appointment) {
                        // Determine status and colors based on appointment source and state
                        String status;
                        Color statusColor;

                        switch (appointment['status']) {
                          case 'pending':
                            status = 'Pending';
                            statusColor = Colors.orange;
                            break;
                          case 'approved':
                            status = 'Approved';
                            statusColor = Colors.green;
                            break;
                          case 'consultation_finished':
                            status = 'Consultation Finished';
                            statusColor = Colors.blue;
                            break;
                          case 'treatment_completed':
                            status = 'Treatment Completed';
                            statusColor = Colors.purple;
                            break;
                          case 'rejected':
                            status = 'Rejected';
                            statusColor = Colors.red;
                            break;
                          default:
                            status = 'Unknown';
                            statusColor = Colors.grey;
                        }

                        DateTime? date;
                        try {
                          final appointmentDate =
                              appointment['appointmentDate'] ??
                                  appointment['appointment_date'];
                          if (appointmentDate is Timestamp) {
                            date = appointmentDate.toDate();
                          } else if (appointmentDate != null) {
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
                                        if (appointment['status'] ==
                                                'approved' &&
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
                                  // Show delete button for rejected appointments, otherwise show arrow
                                  if (appointment['status'] == 'rejected')
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                        size: 24,
                                      ),
                                      onPressed: () =>
                                          _deleteRejectedAppointment(
                                              appointment),
                                    )
                                  else
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

  // Method to view prescription PDF in-app
  Future<void> _viewPrescriptionPdf(
      Map<String, dynamic> prescriptionData) async {
    try {
      String filename = 'Prescription.pdf';

      // Check for Cloudinary URL first
      if (prescriptionData['pdfUrl'] != null &&
          prescriptionData['pdfUrl'].toString().isNotEmpty) {
        String pdfUrl = prescriptionData['pdfUrl'].toString();
        debugPrint('Opening PDF from URL: $pdfUrl');

        // Navigate to URL-based PDF viewer
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => _PdfViewerFromUrlScreen(
              pdfUrl: pdfUrl,
              title: 'Prescription PDF',
              filename: filename,
              backgroundColor: Colors.blue,
            ),
          ),
        );
        return;
      }

      // Check for local PDF path (fallback)
      if (prescriptionData['pdfPath'] != null) {
        final file = File(prescriptionData['pdfPath']);
        if (await file.exists()) {
          final pdfBytes = await file.readAsBytes();
          // Show in-app PDF viewer
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => _PdfViewerScreen(
                pdfBytes: pdfBytes,
                title: 'Prescription PDF',
                filename: filename,
                backgroundColor: Colors.blue,
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'PDF file not found. It may have been moved or deleted.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF not available. Please contact your doctor.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error viewing prescription: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Method to view certificate PDF in-app
  Future<void> _viewCertificatePdf(Map<String, dynamic> appointment) async {
    try {
      // Query the certificates collection for this appointment
      final appointmentId = appointment['appointmentId'] ?? appointment['id'];
      final certificateSnapshot = await FirebaseFirestore.instance
          .collection('certificates')
          .where('appointmentId', isEqualTo: appointmentId)
          .get();

      if (certificateSnapshot.docs.isNotEmpty) {
        final certificateData = certificateSnapshot.docs.first.data();

        // Check for Cloudinary URL first
        if (certificateData['pdfUrl'] != null &&
            certificateData['pdfUrl'].toString().isNotEmpty) {
          String pdfUrl = certificateData['pdfUrl'].toString();
          debugPrint('Opening certificate PDF from URL: $pdfUrl');

          // Navigate to URL-based PDF viewer
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => _PdfViewerFromUrlScreen(
                pdfUrl: pdfUrl,
                title: 'TB Treatment Certificate',
                filename: 'TB_Certificate.pdf',
                backgroundColor: Colors.purple,
              ),
            ),
          );
          return;
        }

        // Check for local PDF path (fallback)
        if (certificateData['pdfPath'] != null) {
          final file = File(certificateData['pdfPath']);
          if (await file.exists()) {
            final pdfBytes = await file.readAsBytes();
            // Show in-app PDF viewer
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => _PdfViewerScreen(
                  pdfBytes: pdfBytes,
                  title: 'TB Treatment Certificate',
                  filename: 'TB_Certificate.pdf',
                  backgroundColor: Colors.purple,
                ),
              ),
            );
            return;
          }
        }
      }

      // No certificate found or no PDF available
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Certificate PDF not available. Please contact your healthcare provider.'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error viewing certificate: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// In-app PDF Viewer Screen for URLs
class _PdfViewerFromUrlScreen extends StatefulWidget {
  final String pdfUrl;
  final String title;
  final String filename;
  final Color? backgroundColor;

  const _PdfViewerFromUrlScreen({
    required this.pdfUrl,
    required this.title,
    required this.filename,
    this.backgroundColor,
  });

  @override
  State<_PdfViewerFromUrlScreen> createState() =>
      _PdfViewerFromUrlScreenState();
}

class _PdfViewerFromUrlScreenState extends State<_PdfViewerFromUrlScreen> {
  pdfx.PdfController? _pdfController;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializePdf();
  }

  Future<void> _initializePdf() async {
    try {
      debugPrint('Initializing PDF from URL: ${widget.pdfUrl}');

      // Download PDF from URL
      final response = await http.get(Uri.parse(widget.pdfUrl));
      if (response.statusCode == 200) {
        final pdfBytes = response.bodyBytes;
        _pdfController = pdfx.PdfController(
          document: pdfx.PdfDocument.openData(pdfBytes),
        );
        setState(() {
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to download PDF: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error loading PDF: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load PDF: ${e.toString()}';
      });
    }
  }

  Future<void> _downloadAndSharePdf() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Download PDF bytes from URL
      final response = await http.get(Uri.parse(widget.pdfUrl));

      // Close loading dialog
      Navigator.of(context).pop();

      if (response.statusCode == 200) {
        final pdfBytes = response.bodyBytes;

        // Share the PDF
        await Printing.sharePdf(
          bytes: pdfBytes,
          filename: widget.filename,
        );
      } else {
        throw Exception('Failed to download PDF: ${response.statusCode}');
      }
    } catch (e) {
      // Close loading dialog if still open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error downloading PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _printPdf() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Download PDF bytes from URL
      final response = await http.get(Uri.parse(widget.pdfUrl));

      // Close loading dialog
      Navigator.of(context).pop();

      if (response.statusCode == 200) {
        final pdfBytes = response.bodyBytes;

        // Print the PDF
        await Printing.layoutPdf(
          onLayout: (format) => pdfBytes,
        );
      } else {
        throw Exception('Failed to download PDF: ${response.statusCode}');
      }
    } catch (e) {
      // Close loading dialog if still open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error printing PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: widget.backgroundColor ?? Colors.red,
        foregroundColor: Colors.white,
        actions: [
          // Share/Download button
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _downloadAndSharePdf,
            tooltip: 'Share PDF',
          ),
          // Print button
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: _printPdf,
            tooltip: 'Print PDF',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading PDF...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load PDF',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                });
                _initializePdf();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_pdfController == null) {
      return const Center(
        child: Text('PDF controller not initialized'),
      );
    }

    return pdfx.PdfView(
      controller: _pdfController!,
      scrollDirection: Axis.vertical,
      backgroundDecoration: const BoxDecoration(
        color: Colors.grey,
      ),
    );
  }
}

// In-app PDF Viewer Screen
class _PdfViewerScreen extends StatelessWidget {
  final Uint8List pdfBytes;
  final String title;
  final String filename;
  final Color? backgroundColor;

  const _PdfViewerScreen({
    required this.pdfBytes,
    required this.title,
    required this.filename,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: backgroundColor ?? Colors.red,
        foregroundColor: Colors.white,
        actions: [
          // Share/Download button
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () async {
              try {
                await Printing.sharePdf(
                  bytes: pdfBytes,
                  filename: filename,
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error sharing PDF: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
          // Print button
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () async {
              try {
                await Printing.layoutPdf(
                  onLayout: (format) => pdfBytes,
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error printing PDF: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: PdfPreview(
          build: (format) => pdfBytes,
          allowPrinting: true,
          allowSharing: true,
          canChangePageFormat: false,
          canDebug: false,
          initialPageFormat: PdfPageFormat.a4,
          pdfFileName: filename,
        ),
      ),
    );
  }
}
