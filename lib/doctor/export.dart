import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

class ExportPatientData extends StatefulWidget {
  final String doctorId;
  final String reportTitle;
  final String collection; // 'appointment_history' or 'completed_appointments'

  const ExportPatientData({
    super.key,
    required this.doctorId,
    required this.reportTitle,
    this.collection = 'appointment_history',
  });

  @override
  State<ExportPatientData> createState() => _ExportPatientDataState();
}

class _ExportPatientDataState extends State<ExportPatientData> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
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
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.download_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.reportTitle,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                      const Text(
                        'Select date range',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Date Range Selection
            _buildDateRangePicker(),

            const SizedBox(height: 24),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isExporting ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Colors.grey),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isExporting ? null : _exportData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isExporting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'EXPORT',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRangePicker() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        children: [
          // Start Date
          _buildDateSelector(
            label: 'Start Date',
            date: _startDate,
            onTap: () => _selectDate(context, true),
          ),
          const SizedBox(height: 12),
          // End Date
          _buildDateSelector(
            label: 'End Date',
            date: _endDate,
            onTap: () => _selectDate(context, false),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.shade300),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: Colors.green.shade700, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMMM dd, yyyy').format(date),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_drop_down, color: Colors.green.shade700),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF4CAF50),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          if (_startDate.isAfter(_endDate)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _startDate = _endDate;
          }
        }
      });
    }
  }

  Future<void> _exportData() async {
    setState(() => _isExporting = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(widget.collection)
          .where('doctorId', isEqualTo: widget.doctorId)
          .get();

      List<List<dynamic>> rows = [];

      // Headers
      rows.add([
        'Patient Name',
        'Appointment Date',
        'Appointment Time',
        'Completed Date',
        'Completed Time',
        'Status',
        'Treatment Type',
        'Treatment Completed',
        'Has Prescription',
        'Notes',
      ]);

      int foundCount = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();

        // Get appointment date/time
        DateTime? appointmentDateTime;
        if (data['appointmentDate'] != null) {
          appointmentDateTime = (data['appointmentDate'] as Timestamp).toDate();
        }

        // Get completion date/time
        DateTime? completedDateTime;
        if (data['completedAt'] != null) {
          completedDateTime = (data['completedAt'] as Timestamp).toDate();
        } else if (data['rejectedAt'] != null) {
          completedDateTime = (data['rejectedAt'] as Timestamp).toDate();
        }

        // Filter by date range
        if (completedDateTime != null &&
            completedDateTime.isAfter(_startDate.subtract(const Duration(days: 1))) &&
            completedDateTime.isBefore(_endDate.add(const Duration(days: 1)))) {
          
          foundCount++;

          // Determine status
          String status = data['status'] ?? 'Unknown';
          if (status == 'rejected') {
            status = 'Rejected';
          } else if (data['treatmentCompleted'] == true) {
            status = 'Treatment Completed';
          } else if (data['hasPrescription'] == true) {
            status = 'Completed with Prescription';
          }

          rows.add([
            data['patientName'] ?? 'Unknown',
            appointmentDateTime != null
                ? DateFormat('yyyy-MM-dd').format(appointmentDateTime)
                : 'N/A',
            appointmentDateTime != null
                ? DateFormat('HH:mm').format(appointmentDateTime)
                : 'N/A',
            completedDateTime != null
                ? DateFormat('yyyy-MM-dd').format(completedDateTime)
                : 'N/A',
            completedDateTime != null
                ? DateFormat('HH:mm').format(completedDateTime)
                : 'N/A',
            status,
            data['treatmentType'] ?? 'N/A',
            data['treatmentCompleted'] == true ? 'Yes' : 'No',
            data['hasPrescription'] == true ? 'Yes' : 'No',
            data['notes'] ?? (data['rejectionReason'] ?? ''),
          ]);
        }
      }

      if (foundCount == 0) {
        if (mounted) {
          Navigator.pop(context);
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

      // Handle permissions
      if (Platform.isAndroid) {
        var status = await Permission.manageExternalStorage.status;
        if (!status.isGranted) {
          status = await Permission.manageExternalStorage.request();
        }

        if (!status.isGranted) {
          var storageStatus = await Permission.storage.status;
          if (!storageStatus.isGranted) {
            storageStatus = await Permission.storage.request();
          }

          if (!storageStatus.isGranted) {
            if (mounted) {
              Navigator.pop(context);
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

      // Get directory
      Directory? directory;
      if (Platform.isAndroid) {
        directory = await getExternalStorageDirectory();
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory == null) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Unable to access storage directory'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
        return;
      }

      final fileName =
          'TB_Patients_Report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      final filePath = '${directory.path}/$fileName';

      final file = File(filePath);
      await file.writeAsString(csv);

      debugPrint('File saved at: $filePath');

      if (mounted) {
        Navigator.pop(context);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
                    const Expanded(
                      child: Text(
                        'Report generated successfully!',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('📁 $fileName', style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  'Found $foundCount patients • Tap "OPTIONS" to open or share',
                  style: const TextStyle(fontSize: 11),
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
                _showFileOptionsDialog(context, filePath, fileName);
              },
            ),
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error exporting data: $e');
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating report: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  void _showFileOptionsDialog(BuildContext context, String filePath, String fileName) {
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
                    context: context,
                    icon: Icons.table_chart_rounded,
                    iconColor: Colors.green,
                    title: 'Open with Excel/Sheets',
                    subtitle: 'View in spreadsheet app',
                    onTap: () async {
                      Navigator.pop(context);
                      try {
                        final result = await OpenFile.open(filePath);
                        if (result.type != ResultType.done) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Row(
                                  children: [
                                    Icon(Icons.info_outline, color: Colors.white),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                          'Please install Excel, Google Sheets, or WPS Office app'),
                                    ),
                                  ],
                                ),
                                backgroundColor: Colors.orange,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error opening file: $e'),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        }
                      }
                    },
                  ),

                  const SizedBox(height: 12),

                  // Share file
                  _buildFileOption(
                    context: context,
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
                          if (context.mounted) {
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
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        debugPrint('Error sharing file: $e');
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error sharing file: $e'),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
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

  Widget _buildFileOption({
    required BuildContext context,
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
}
