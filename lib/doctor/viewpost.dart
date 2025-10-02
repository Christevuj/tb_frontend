import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';
import 'certificate.dart';

class Viewpostappointment extends StatelessWidget {
  final Map<String, dynamic> appointment;

  const Viewpostappointment({super.key, required this.appointment});

  @override
  Widget build(BuildContext context) {
    final date = appointment["date"] as DateTime?;

    // Widget to show doctor info, including async address fetch if needed
    Widget doctorInfoSection() {
      final doctorName = appointment["doctorData"]?["firstName"] != null &&
              appointment["doctorData"]?["lastName"] != null
          ? "${appointment["doctorData"]["firstName"]} ${appointment["doctorData"]["lastName"]}"
          : appointment["doctorName"] ?? "Unknown Doctor";

      final experience = appointment["doctorData"]?["experience"] != null
          ? "${appointment["doctorData"]["experience"]} years experience"
          : "Experience not specified";

      // Try to get address from appointment, else fetch from doctors collection
      final localAddress =
          appointment["doctorData"]?["address"] ?? appointment["facility"];
      final doctorUid =
          appointment["doctorUid"] ?? appointment["doctorData"]?["uid"];
      // If local address is missing or empty, always try to fetch from doctors collection
      if (localAddress == null || localAddress.toString().trim().isEmpty) {
        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
          future: doctorUid != null
              ? FirebaseFirestore.instance
                  .collection('doctors')
                  .doc(doctorUid)
                  .get()
              : Future<DocumentSnapshot<Map<String, dynamic>>?>.value(null),
          builder: (context, snapshot) {
            String address = "No address provided";
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle(title: "Doctor"),
                  InfoField(icon: Icons.person, text: doctorName),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: LinearProgressIndicator(),
                  ),
                  InfoField(icon: Icons.badge, text: experience),
                ],
              );
            }
            if (snapshot.hasData && snapshot.data != null) {
              final data = snapshot.data!.data();
              if (data != null &&
                  data["address"] != null &&
                  data["address"].toString().trim().isNotEmpty) {
                address = data["address"];
              }
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle(title: "Doctor"),
                InfoField(icon: Icons.person, text: doctorName),
                InfoField(icon: Icons.location_on, text: address),
                InfoField(icon: Icons.badge, text: experience),
              ],
            );
          },
        );
      } else {
        // If local address is present, show it
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle(title: "Doctor"),
            InfoField(icon: Icons.person, text: doctorName),
            InfoField(icon: Icons.location_on, text: localAddress),
            InfoField(icon: Icons.badge, text: experience),
          ],
        );
      }
    }

    return SingleChildScrollView(
      child: Material(
        color: Colors.white, // ✅ Solid white background
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min, // wrap content
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with close button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Post Appointment",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),

              // Patient Details
              const SectionTitle(title: "Patient Details"),
              InfoField(
                  icon: Icons.person,
                  text: appointment["patientName"] ?? "Unknown Patient"),
              InfoField(
                  icon: Icons.email,
                  text: appointment["patientEmail"] ?? "No email provided"),
              InfoField(
                  icon: Icons.phone,
                  text: appointment["patientPhone"] ?? "No phone provided"),
              InfoField(
                  icon: Icons.person_outline,
                  text: appointment["patientGender"] ?? "Not specified"),
              InfoField(
                  icon: Icons.calendar_today,
                  text: appointment["patientAge"]?.toString() ??
                      "Age not specified"),

              const SizedBox(height: 20),

              // Schedule (dynamic)
              const SectionTitle(title: "Schedule"),
              InfoField(
                  icon: Icons.calendar_today,
                  text: date != null
                      ? date.toLocal().toString().split(" ")[0]
                      : "-"),
              InfoField(
                  icon: Icons.access_time,
                  text: appointment["appointmentTime"] ?? "No time set"),

              const SizedBox(height: 20),

              // Doctor Info (with address fetch)
              doctorInfoSection(),

              const SizedBox(height: 20),

              // Meeting Link
              const SectionTitle(title: "Meeting Link"),
              InfoField(
                  icon: Icons.link,
                  text:
                      appointment["meetingLink"] ?? "No meeting link provided"),

              const SizedBox(height: 20),

              // E-Prescription
              const SectionTitle(title: "E-Prescription"),
              if (appointment["prescriptionData"] != null) ...[
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle,
                              color: Colors.green.shade600),
                          const SizedBox(width: 8),
                          const Text(
                            "Prescription Details",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (appointment["prescriptionData"]["medicines"] != null)
                        ...List.generate(
                          (appointment["prescriptionData"]["medicines"] as List)
                              .length,
                          (index) {
                            final medicine = appointment["prescriptionData"]
                                ["medicines"][index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("• ",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  Expanded(
                                    child: Text(
                                      "${medicine['name']} - ${medicine['dosage']} (${medicine['frequency']})",
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      if (appointment["prescriptionData"]["notes"] != null) ...[
                        const SizedBox(height: 8),
                        const Text(
                          "Additional Notes:",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          appointment["prescriptionData"]["notes"],
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // PDF Viewing Button
                if (appointment["prescriptionData"]["pdfPath"] != null) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _viewPrescriptionPdf(context, appointment),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('View Prescription PDF'),
                    ),
                  ),
                ],
              ] else ...[
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange.shade600),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          "No prescription data available for this appointment",
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Treatment Progress
              const SectionTitle(title: "Treatment Progress"),
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  children: [
                    // Step 1: Meeting Completed
                    Row(
                      children: [
                        Icon(
                          appointment["meetingCompleted"] == true
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: appointment["meetingCompleted"] == true
                              ? Colors.green
                              : Colors.grey,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Meeting Completed",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: appointment["meetingCompleted"] == true
                                      ? Colors.green
                                      : Colors.grey,
                                ),
                              ),
                              Text(
                                "Doctor consultation and e-prescription provided",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: appointment["meetingCompleted"] == true
                                      ? Colors.green.shade700
                                      : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Step 2: Certificate Sent
                    Row(
                      children: [
                        Icon(
                          appointment["certificateSent"] == true
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: appointment["certificateSent"] == true
                              ? Colors.green
                              : Colors.grey,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Certificate Sent to Patient",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: appointment["certificateSent"] == true
                                      ? Colors.green
                                      : Colors.grey,
                                ),
                              ),
                              Text(
                                "Treatment completion certificate delivered",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: appointment["certificateSent"] == true
                                      ? Colors.green.shade700
                                      : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Step 3: Treatment Completed
                    Row(
                      children: [
                        Icon(
                          appointment["treatmentCompleted"] == true
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: appointment["treatmentCompleted"] == true
                              ? Colors.green
                              : Colors.grey,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Treatment Fully Completed",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      appointment["treatmentCompleted"] == true
                                          ? Colors.green
                                          : Colors.grey,
                                ),
                              ),
                              Text(
                                "Patient has completed full TB treatment program",
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      appointment["treatmentCompleted"] == true
                                          ? Colors.green.shade700
                                          : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Buttons Section
              if (appointment["meetingCompleted"] == true &&
                  appointment["certificateSent"] == true) ...[
                // Certificate has been sent - show view button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _viewCertificatePdf(context, appointment),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('View Certificate PDF',
                        style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      "Certificate Sent to Patient ✓",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ),
              ] else ...[
                // Original single button for when certificate not sent
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: appointment["meetingCompleted"] == true &&
                            appointment["certificateSent"] != true
                        ? () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    Certificate(appointment: appointment),
                              ),
                            )
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: appointment["meetingCompleted"] == true
                          ? (appointment["certificateSent"] == true
                              ? Colors.green
                              : Colors.red)
                          : Colors.grey,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      appointment["meetingCompleted"] == true
                          ? (appointment["certificateSent"] == true
                              ? "Certificate Sent to Patient"
                              : "Send Certificate to Patient")
                          : "Complete Treatment First",
                      style: const TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }

  void _showCertificate(
      BuildContext context, Map<String, dynamic> appointment) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.blue.shade50, Colors.white],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
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

                // Certificate Content
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blue.shade200, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Center(
                        child: Text(
                          "TB Treatment Completion Certificate",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "This is to certify that:",
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          appointment["patientName"] ?? "Unknown Patient",
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Has successfully completed the TB treatment program under the supervision of:",
                        style: TextStyle(fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          appointment["doctorData"]?["firstName"] != null &&
                                  appointment["doctorData"]?["lastName"] != null
                              ? "Dr. ${appointment["doctorData"]["firstName"]} ${appointment["doctorData"]["lastName"]}"
                              : appointment["doctorName"] ?? "Unknown Doctor",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          appointment["doctorData"]?["address"] ??
                              appointment["facility"] ??
                              "Unknown Facility",
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Date Completed:",
                                  style: TextStyle(fontSize: 12)),
                              Text(
                                DateTime.now().toString().split(' ')[0],
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text("Certificate ID:",
                                  style: TextStyle(fontSize: 12)),
                              Text(
                                "TB-${appointment["id"]?.toString().substring(0, 8) ?? "XXXXXXXX"}",
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                      ),
                      child: const Text("Close",
                          style: TextStyle(color: Colors.white)),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        // Generate PDF certificate and send to patient
                        await _generateAndSendCertificate(appointment, context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                      ),
                      child: const Text("Generate & Send Certificate",
                          style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Generate PDF certificate and send to patient
  Future<void> _generateAndSendCertificate(
      Map<String, dynamic> appointment, BuildContext context) async {
    try {
      final doctorName = appointment["doctorData"]?["firstName"] != null &&
              appointment["doctorData"]?["lastName"] != null
          ? "Dr. ${appointment["doctorData"]["firstName"]} ${appointment["doctorData"]["lastName"]}"
          : appointment["doctorName"] ?? "Unknown Doctor";

      final facilityName = appointment["doctorData"]?["address"] ??
          appointment["facility"] ??
          "Unknown Facility";

      final patientName = appointment["patientName"] ?? "Unknown Patient";
      final completionDate = DateTime.now().toString().split(' ')[0];
      final certificateId =
          "TB-${appointment["id"]?.toString().substring(0, 8) ?? "XXXXXXXX"}";

      // Generate PDF
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'TB TREATMENT COMPLETION CERTIFICATE',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 10),
                      pw.Container(
                        height: 3,
                        width: 300,
                        color: PdfColors.blue,
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 40),

                // Certificate content
                pw.Text(
                  'This is to certify that:',
                  style: pw.TextStyle(fontSize: 16),
                ),

                pw.SizedBox(height: 20),

                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.blue, width: 2),
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      patientName.toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue,
                      ),
                    ),
                  ),
                ),

                pw.SizedBox(height: 30),

                pw.Text(
                  'Has successfully completed the Tuberculosis (TB) treatment program under the professional supervision of:',
                  style: pw.TextStyle(fontSize: 14),
                ),

                pw.SizedBox(height: 20),

                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Supervising Doctor:',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 12),
                      ),
                      pw.Text(doctorName, style: pw.TextStyle(fontSize: 14)),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'Healthcare Facility:',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 12),
                      ),
                      pw.Text(facilityName, style: pw.TextStyle(fontSize: 14)),
                    ],
                  ),
                ),

                pw.SizedBox(height: 30),

                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Date of Completion:',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, fontSize: 12),
                        ),
                        pw.Text(completionDate,
                            style: pw.TextStyle(fontSize: 14)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Certificate ID:',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, fontSize: 12),
                        ),
                        pw.Text(certificateId,
                            style: pw.TextStyle(fontSize: 14)),
                      ],
                    ),
                  ],
                ),

                pw.Spacer(),

                // Footer
                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue50,
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'This certificate confirms the successful completion of the prescribed TB treatment regimen as per WHO guidelines.',
                        style: pw.TextStyle(
                            fontSize: 10, fontStyle: pw.FontStyle.italic),
                        textAlign: pw.TextAlign.center,
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'Generated on ${DateTime.now().toString().split(' ')[0]} via TB-ISITA Digital Health Platform',
                        style: pw.TextStyle(fontSize: 8),
                        textAlign: pw.TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );

      // Save PDF to device storage
      final directory = await getApplicationDocumentsDirectory();
      final file = File(
          '${directory.path}/TB_Certificate_${patientName.replaceAll(' ', '_')}_$certificateId.pdf');
      await file.writeAsBytes(await pdf.save());

      // Certificate text for notification
      final certificateText = """
TB Treatment Completion Certificate

This is to certify that:
$patientName

Has successfully completed the TB treatment program under the supervision of:
$doctorName
$facilityName

Date Completed: $completionDate
Certificate ID: $certificateId
""";

      // Create patient notification for certificate
      await FirebaseFirestore.instance.collection('patient_notifications').add({
        'patientUid': appointment['patientUid'],
        'appointmentId': appointment['id'],
        'type': 'certificate_ready',
        'title': 'Treatment Completion Certificate',
        'message':
            'Your TB treatment completion certificate is ready for download.',
        'certificateText': certificateText,
        'pdfPath': file.path,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'doctorName': doctorName,
        'facilityName': facilityName,
      });

      // Update completed appointment to mark certificate as sent
      await FirebaseFirestore.instance
          .collection('completed_appointments')
          .where('appointmentId', isEqualTo: appointment['id'])
          .get()
          .then((querySnapshot) async {
        for (var doc in querySnapshot.docs) {
          await doc.reference.update({
            'certificateSent': true,
            'certificateSentAt': FieldValue.serverTimestamp(),
            'treatmentCompleted': true,
            'pdfPath': file.path,
          });
        }
      });

      Navigator.of(context).pop();

      // Show success message and option to share/view PDF
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Certificate Generated Successfully!'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                    'The TB treatment completion certificate has been generated and sent to the patient.'),
                const SizedBox(height: 16),
                Text('PDF saved to: ${file.path}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
              ElevatedButton(
                onPressed: () async {
                  // Open the generated PDF
                  await Printing.sharePdf(
                    bytes: await pdf.save(),
                    filename:
                        'TB_Certificate_${patientName.replaceAll(' ', '_')}_$certificateId.pdf',
                  );
                },
                child: const Text('Share PDF'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error generating certificate: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Static method to view prescription PDF
  static void _viewPrescriptionPdf(
      BuildContext context, Map<String, dynamic> appointmentData) async {
    try {
      // First check the prescriptions collection for PDF data
      final prescriptionSnapshot = await FirebaseFirestore.instance
          .collection('prescriptions')
          .where('appointmentId', isEqualTo: appointmentData['appointmentId'])
          .get();

      if (prescriptionSnapshot.docs.isNotEmpty) {
        final prescriptionData = prescriptionSnapshot.docs.first.data();

        // Check for Cloudinary URL first
        if (prescriptionData['pdfUrl'] != null &&
            prescriptionData['pdfUrl'].toString().isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Opening cloud PDF - implement web view or download'),
              backgroundColor: Colors.orange,
            ),
          );
          // TODO: Implement cloud PDF viewing
          return;
        }

        // Check for local PDF path
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
                  filename: 'Prescription.pdf',
                ),
              ),
            );
            return;
          }
        }
      }

      // Fallback to old prescription data structure
      final prescriptionData = appointmentData["prescriptionData"];
      if (prescriptionData != null && prescriptionData['pdfPath'] != null) {
        final file = File(prescriptionData['pdfPath']);
        if (await file.exists()) {
          final pdfBytes = await file.readAsBytes();
          // Show in-app PDF viewer
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => _PdfViewerScreen(
                pdfBytes: pdfBytes,
                title: 'Prescription PDF',
                filename: 'Prescription.pdf',
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
            content: Text('PDF version not available.'),
            backgroundColor: Colors.blue,
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

  // Static method to view certificate PDF
  static void _viewCertificatePdf(
      BuildContext context, Map<String, dynamic> appointmentData) async {
    try {
      // Query the certificates collection for this appointment
      final certificateSnapshot = await FirebaseFirestore.instance
          .collection('certificates')
          .where('appointmentId',
              isEqualTo:
                  appointmentData['appointmentId'] ?? appointmentData['id'])
          .get();

      if (certificateSnapshot.docs.isNotEmpty) {
        final certificateData = certificateSnapshot.docs.first.data();

        // Check for local PDF path first (most likely to exist)
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
                ),
              ),
            );
            return;
          }
        }

        // Check for Cloudinary URL
        if (certificateData['pdfUrl'] != null &&
            certificateData['pdfUrl'].toString().isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Cloud certificate viewing - implement web view or download'),
              backgroundColor: Colors.orange,
            ),
          );
          // TODO: Implement cloud PDF viewing for certificates
          return;
        }
      }

      // No certificate found
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Certificate PDF not found. It may have been moved or deleted.'),
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

// 🔹 Section Title Widget
class SectionTitle extends StatelessWidget {
  final String title;
  const SectionTitle({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// 🔹 Info Field Widget with thin black border and shadow
class InfoField extends StatelessWidget {
  final IconData icon;
  final String text;
  const InfoField({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white, // ✅ Solid white background
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12, width: 0.8),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}

class _PdfViewerScreen extends StatelessWidget {
  final Uint8List pdfBytes;
  final String title;
  final String filename;

  const _PdfViewerScreen({
    required this.pdfBytes,
    required this.title,
    required this.filename,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.teal,
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
