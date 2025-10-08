import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:printing/printing.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';

class PpatientNotifications extends StatefulWidget {
  const PpatientNotifications({super.key});

  @override
  State<PpatientNotifications> createState() => _PpatientNotificationsState();
}

class _PpatientNotificationsState extends State<PpatientNotifications> {
  String? _currentPatientId;

  @override
  void initState() {
    super.initState();
    _getCurrentPatient();
  }

  Future<void> _getCurrentPatient() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _currentPatientId = user.uid;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("My Appointments & Notifications"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: _currentPatientId == null
            ? const Center(child: CircularProgressIndicator())
            : StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('patient_notifications')
                    .where('patientUid', isEqualTo: _currentPatientId)
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Error: ${snapshot.error}'),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final notifications = snapshot.data?.docs ?? [];

                  if (notifications.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_none,
                              size: 80, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            "No notifications yet",
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final notification =
                          notifications[index].data() as Map<String, dynamic>;
                      final type = notification['type'] as String;
                      final isRead = notification['isRead'] as bool? ?? false;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        color: isRead ? Colors.white : Colors.blue.shade50,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: type == 'meeting_completed'
                                ? Colors.green
                                : Colors.blue,
                            child: Icon(
                              type == 'meeting_completed'
                                  ? Icons.medical_services
                                  : Icons.workspace_premium,
                              color: Colors.white,
                            ),
                          ),
                          title: Text(
                            notification['title'] ?? 'Notification',
                            style: TextStyle(
                              fontWeight:
                                  isRead ? FontWeight.normal : FontWeight.bold,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(notification['message'] ?? ''),
                              const SizedBox(height: 4),
                              Text(
                                'From: ${notification['doctorName'] ?? 'Doctor'}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          trailing: Icon(
                            isRead
                                ? Icons.mark_email_read
                                : Icons.mark_email_unread,
                            color: isRead ? Colors.grey : Colors.blue,
                          ),
                          onTap: () {
                            _showNotificationDetails(
                                notifications[index].id, notification);
                          },
                        ),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }

  void _showNotificationDetails(
      String notificationId, Map<String, dynamic> notification) async {
    // Mark notification as read
    if (notification['isRead'] != true) {
      await FirebaseFirestore.instance
          .collection('patient_notifications')
          .doc(notificationId)
          .update({'isRead': true});
    }

    if (context.mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    notification['title'] ?? 'Notification',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                notification['message'] ?? '',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              if (notification['type'] == 'meeting_completed') ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '📋 E-Prescription Available',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                          'Your e-prescription is ready for viewing and download.'),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () =>
                            _showPrescriptionFromCompleted(notification),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green),
                        child: const Text('View E-Prescription',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ],
              if (notification['type'] == 'certificate_ready' ||
                  notification['type'] == 'certificate_available') ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '🎉 Treatment Completion Certificate',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                          'Congratulations! Your TB treatment completion certificate is ready.'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                _showCertificate(notification);
                              },
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue),
                              child: const Text('View Certificate',
                                  style: TextStyle(color: Colors.white)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                _downloadCertificate(notification);
                              },
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green),
                              child: const Text('Download',
                                  style: TextStyle(color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      );
    }
  }

  void _showCertificate(Map<String, dynamic> notification) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [Colors.blue.shade50, Colors.white],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade600,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.verified, color: Colors.white, size: 28),
                    SizedBox(width: 8),
                    Text(
                      "CERTIFICATE OF COMPLETION",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue.shade200, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  notification['certificateText'] ?? 'Certificate content',
                  style: const TextStyle(fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    label: const Text("Close"),
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await _viewPdfCertificate(notification);
                    },
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text("View PDF"),
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await _downloadCertificate(notification);
                    },
                    icon: const Icon(Icons.download),
                    label: const Text("Download"),
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _viewPdfCertificate(Map<String, dynamic> notification) async {
    try {
      if (notification['pdfPath'] != null) {
        final file = File(notification['pdfPath']);
        if (await file.exists()) {
          final pdfBytes = await file.readAsBytes();
          // Show in-app PDF viewer
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => _CertificatePdfViewerScreen(
                pdfBytes: pdfBytes,
                title: 'TB Treatment Certificate',
                filename: 'TB_Certificate.pdf',
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
            content: Text('PDF version not available. Showing text version.'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error viewing certificate: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _downloadCertificate(Map<String, dynamic> notification) async {
    try {
      if (notification['pdfPath'] != null) {
        final file = File(notification['pdfPath']);
        if (await file.exists()) {
          final downloadsDir = await getApplicationDocumentsDirectory();
          final patientName = notification['patientName'] ?? 'Patient';
          final newPath =
              '${downloadsDir.path}/TB_Certificate_${patientName.replaceAll(' ', '_')}.pdf';
          final newFile = await file.copy(newPath);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Certificate downloaded to: ${newFile.path}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Certificate file not found.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('PDF not available. Text version copied to clipboard.'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error downloading certificate: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showPrescriptionFromCompleted(Map<String, dynamic> notification) async {
    try {
      // First check the prescriptions collection for PDF data
      final prescriptionSnapshot = await FirebaseFirestore.instance
          .collection('prescriptions')
          .where('appointmentId', isEqualTo: notification['appointmentId'])
          .get();

      if (prescriptionSnapshot.docs.isNotEmpty) {
        final prescriptionDoc = prescriptionSnapshot.docs.first.data();

        // Show PDF if available
        if (prescriptionDoc['pdfUrl'] != null &&
            prescriptionDoc['pdfUrl'].toString().isNotEmpty) {
          await _viewPrescriptionPdf(prescriptionDoc);
        } else if (prescriptionDoc['pdfPath'] != null) {
          await _viewLocalPrescriptionPdf(prescriptionDoc);
        } else {
          // Show text-based prescription details
          _showTextPrescriptionDetails(prescriptionDoc);
        }
        return;
      }

      // Fallback to completed_appointments collection for old data
      final completedSnapshot = await FirebaseFirestore.instance
          .collection('completed_appointments')
          .where('appointmentId', isEqualTo: notification['appointmentId'])
          .get();

      if (completedSnapshot.docs.isNotEmpty) {
        final completedAppointment = completedSnapshot.docs.first.data();
        final prescriptionData = completedAppointment['prescriptionData'];

        if (prescriptionData != null) {
          _showPrescriptionDetails(prescriptionData);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No prescription data available')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appointment not found')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading prescription: $e')),
      );
    }
  }

  Future<void> _viewPrescriptionPdf(
      Map<String, dynamic> prescriptionData) async {
    try {
      final pdfUrl = prescriptionData['pdfUrl'];
      if (pdfUrl != null && pdfUrl.toString().isNotEmpty) {
        // For cloud-stored PDFs, you can implement a web view or download functionality
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'PDF viewing from cloud URL - implement web view or download'),
            backgroundColor: Colors.orange,
          ),
        );
        // TODO: Implement cloud PDF viewing
        // For now, show text details as fallback
        _showTextPrescriptionDetails(prescriptionData);
      } else {
        _showTextPrescriptionDetails(prescriptionData);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error viewing PDF: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _viewLocalPrescriptionPdf(
      Map<String, dynamic> prescriptionData) async {
    try {
      final pdfPath = prescriptionData['pdfPath'];
      if (pdfPath != null) {
        final file = File(pdfPath);
        if (await file.exists()) {
          final pdfBytes = await file.readAsBytes();
          // Show in-app PDF viewer
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => _CertificatePdfViewerScreen(
                pdfBytes: pdfBytes,
                title: 'E-Prescription',
                filename: 'Prescription.pdf',
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PDF file not found. Showing text version.'),
              backgroundColor: Colors.orange,
            ),
          );
          _showTextPrescriptionDetails(prescriptionData);
        }
      } else {
        _showTextPrescriptionDetails(prescriptionData);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error viewing PDF: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  void _showTextPrescriptionDetails(Map<String, dynamic> prescriptionData) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.medical_services, color: Colors.green),
                  const SizedBox(width: 8),
                  const Text(
                    '💊 E-Prescription',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Prescription Details:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Text(
                  prescriptionData['prescriptionDetails'] ??
                      'No details available',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Prescription details viewed')),
                        );
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('OK'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPrescriptionDetails(Map<String, dynamic> prescriptionData) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '💊 E-Prescription',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 16),
              if (prescriptionData['medicines'] != null) ...[
                const Text(
                  'Prescribed Medicines:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                ...List.generate(
                  (prescriptionData['medicines'] as List).length,
                  (index) {
                    final medicine = prescriptionData['medicines'][index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            medicine['name'] ?? 'Medicine ${index + 1}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                              'Dosage: ${medicine['dosage'] ?? 'Not specified'}'),
                          Text(
                              'Frequency: ${medicine['frequency'] ?? 'Not specified'}'),
                        ],
                      ),
                    );
                  },
                ),
              ],
              if (prescriptionData['notes'] != null) ...[
                const SizedBox(height: 16),
                const Text(
                  'Additional Instructions:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Text(
                    prescriptionData['notes'],
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Prescription downloaded!')),
                    );
                  },
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text('Download Prescription',
                      style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CertificatePdfViewerScreen extends StatelessWidget {
  final Uint8List pdfBytes;
  final String title;
  final String filename;

  const _CertificatePdfViewerScreen({
    required this.pdfBytes,
    required this.title,
    required this.filename,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.red.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () async {
              await Printing.sharePdf(
                bytes: pdfBytes,
                filename: filename,
              );
            },
          ),
        ],
      ),
      body: PdfPreview(
        build: (format) => pdfBytes,
        allowPrinting: true,
        allowSharing: true,
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        actions: const [],
      ),
    );
  }
}
