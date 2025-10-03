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
import 'dhistory.dart';

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
            return _buildModernSection(
              title: "Healthcare Provider",
              icon: Icons.local_hospital,
              child: Column(
                children: [
                  ModernInfoCard(
                    icon: Icons.person,
                    title: "Doctor Name",
                    value: doctorName,
                    color: Colors.teal,
                  ),
                  const SizedBox(height: 8),
                  ModernInfoCard(
                    icon: Icons.location_on,
                    title: "Facility Address",
                    value: address,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 8),
                  ModernInfoCard(
                    icon: Icons.badge,
                    title: "Experience",
                    value: experience,
                    color: Colors.amber,
                  ),
                ],
              ),
            );
          },
        );
      } else {
        // If local address is present, show it
        return _buildModernSection(
          title: "Healthcare Provider",
          icon: Icons.local_hospital,
          child: Column(
            children: [
              ModernInfoCard(
                icon: Icons.person,
                title: "Doctor Name",
                value: doctorName,
                color: Colors.teal,
              ),
              const SizedBox(height: 8),
              ModernInfoCard(
                icon: Icons.location_on,
                title: "Facility Address",
                value: localAddress,
                color: Colors.red,
              ),
              const SizedBox(height: 8),
              ModernInfoCard(
                icon: Icons.badge,
                title: "Experience",
                value: experience,
                color: Colors.amber,
              ),
            ],
          ),
        );
      }
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.teal.shade50,
            Colors.white,
          ],
        ),
      ),
      child: SingleChildScrollView(
        child: Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 3,
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Modern Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.teal.shade600,
                      Colors.teal.shade400,
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.medical_information,
                        color: Colors.white,
                        size: 10,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Post Appointment Details",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.visible,
                            maxLines: 2,
                            softWrap: true,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Comprehensive appointment summary",
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                            overflow: TextOverflow.visible,
                            maxLines: 2,
                            softWrap: true,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 28),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Content Container
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

              // Patient Details Section
              _buildModernSection(
                title: "Patient Information",
                icon: Icons.person,
                child: Column(
                  children: [
                    ModernInfoCard(
                      icon: Icons.person,
                      title: "Full Name",
                      value: appointment["patientName"] ?? "Unknown Patient",
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 8),
                    ModernInfoCard(
                      icon: Icons.email,
                      title: "Email Address",
                      value: appointment["patientEmail"] ?? "No email provided",
                      color: Colors.orange,
                    ),
                    const SizedBox(height: 8),
                    ModernInfoCard(
                      icon: Icons.phone,
                      title: "Phone Number",
                      value: appointment["patientPhone"] ?? "No phone provided",
                      color: Colors.green,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ModernInfoCard(
                            icon: Icons.person_outline,
                            title: "Gender",
                            value: appointment["patientGender"] ?? "Not specified",
                            color: Colors.purple,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ModernInfoCard(
                            icon: Icons.cake,
                            title: "Age",
                            value: appointment["patientAge"]?.toString() ?? "Not specified",
                            color: Colors.pink,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Schedule Section
              _buildModernSection(
                title: "Appointment Schedule",
                icon: Icons.schedule,
                child: Row(
                  children: [
                    Expanded(
                      child: ModernInfoCard(
                        icon: Icons.calendar_today,
                        title: "Date",
                        value: date != null
                            ? date.toLocal().toString().split(" ")[0]
                            : "Not specified",
                        color: Colors.indigo,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ModernInfoCard(
                        icon: Icons.access_time,
                        title: "Time",
                        value: appointment["appointmentTime"] ?? "No time set",
                        color: Colors.cyan,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Doctor Info (with address fetch)
              doctorInfoSection(),

              const SizedBox(height: 16),

              // Meeting Link Section
              _buildModernSection(
                title: "Video Consultation",
                icon: Icons.video_call,
                child: ModernInfoCard(
                  icon: Icons.link,
                  title: "Meeting Link",
                  value: appointment["meetingLink"] ?? "No meeting link provided",
                  color: Colors.deepPurple,
                ),
              ),

              const SizedBox(height: 16),

              // E-Prescription Section
              _buildModernSection(
                title: "Electronic Prescription",
                icon: Icons.medical_services,
                child: appointment["prescriptionData"] != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (appointment["prescriptionData"]["medicines"] != null)
                            ...List.generate(
                              (appointment["prescriptionData"]["medicines"] as List)
                                  .length,
                              (index) {
                                final medicine = appointment["prescriptionData"]
                                    ["medicines"][index];
                                return Container(
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.green.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.medication, 
                                          color: Colors.green.shade600, size: 16),
                                      const SizedBox(width: 8),
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
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.note_alt, 
                                          color: Colors.blue.shade600, size: 16),
                                      const SizedBox(width: 8),
                                      const Text(
                                        "Additional Notes:",
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    appointment["prescriptionData"]["notes"],
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          // PDF Viewing Button
                          if (appointment["prescriptionData"]["pdfPath"] != null)
                            Center(
                              child: ElevatedButton.icon(
                                onPressed: () =>
                                    _viewPrescriptionPdf(context, appointment),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade600,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                icon: const Icon(Icons.picture_as_pdf, size: 18),
                                label: const Text('View Prescription PDF',
                                    style: TextStyle(fontSize: 14)),
                              ),
                            ),
                        ],
                      )
                    : Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
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
              ),

              const SizedBox(height: 16),

              // Treatment Progress Section
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.teal.shade50,
                      Colors.blue.shade50,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 2,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Progress Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.teal.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.timeline,
                              color: Colors.teal.shade700,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            "Patient Journey Timeline",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      // Step 1: Book Appointment
                      _buildModernProgressStep(
                        icon: Icons.calendar_month,
                        title: "Book an Appointment",
                        description: "Patient requested appointment with a Doctor",
                        isCompleted: true,
                        stepNumber: 1,
                        isLastStep: false,
                      ),
                      
                      // Step 2: Appointment Approved
                      _buildModernProgressStep(
                        icon: Icons.verified,
                        title: "Appointment Approved",
                        description: "Doctor confirmed and approved the appointment schedule",
                        isCompleted: true,
                        stepNumber: 2,
                        isLastStep: false,
                      ),
                      
                      // Step 3: Meeting Completed
                      _buildModernProgressStep(
                        icon: Icons.video_call,
                        title: "Meeting Completed",
                        description: "Doctor consultation and e-prescription provided",
                        isCompleted: appointment["meetingCompleted"] == true,
                        stepNumber: 3,
                        isLastStep: false,
                      ),
                      
                      // Step 4: Certificate Sent
                      _buildModernProgressStep(
                        icon: Icons.card_membership,
                        title: "Certificate Sent to Patient",
                        description: "Treatment completion certificate delivered",
                        isCompleted: appointment["certificateSent"] == true,
                        stepNumber: 4,
                        isLastStep: false,
                      ),
                      
                      // Step 5: Treatment Completed
                      _buildModernProgressStep(
                        icon: Icons.health_and_safety,
                        title: "Treatment Fully Completed",
                        description: "Patient has completed full TB treatment program",
                        isCompleted: appointment["treatmentCompleted"] == true,
                        stepNumber: 5,
                        isLastStep: true,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Action Buttons Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.grey.shade50,
                      Colors.white,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.admin_panel_settings, 
                             color: Colors.teal.shade600),
                        const SizedBox(width: 8),
                        const Text(
                          "Certificate Management",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Create/View Certificate Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: appointment["meetingCompleted"] == true
                            ? () {
                                if (appointment["certificateSent"] == true) {
                                  // View certificate if already created
                                  _viewCertificatePdf(context, appointment);
                                } else {
                                  // Create certificate if not created yet
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          Certificate(appointment: appointment),
                                    ),
                                  );
                                }
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: appointment["meetingCompleted"] == true
                              ? (appointment["certificateSent"] == true
                                  ? Colors.blue
                                  : Colors.teal)
                              : Colors.grey,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: Icon(
                          appointment["meetingCompleted"] == true
                              ? (appointment["certificateSent"] == true
                                  ? Icons.visibility
                                  : Icons.add_circle)
                              : Icons.lock,
                          color: Colors.white,
                        ),
                        label: Text(
                          appointment["meetingCompleted"] == true
                              ? (appointment["certificateSent"] == true
                                  ? "View Certificate"
                                  : "Create Certificate of Patient")
                              : "Complete Treatment First",
                          style: const TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 10),
                    
                    // Certificate Status Container (when certificate is sent)
                    if (appointment["certificateSent"] == true) ...[
                      SizedBox(
                        width: double.infinity,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade300),
                          ),
                          child: const Text(
                            "Certificate Sent to Patient ✓",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16, 
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    
                    // Done/Confirmation Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: appointment["certificateSent"] == true
                            ? () {
                                // Navigate to dhistory.dart with appointment data
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (context) => const Dhistory(),
                                  ),
                                );
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: appointment["certificateSent"] == true
                              ? Colors.green
                              : Colors.grey.shade300,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: Icon(
                          appointment["certificateSent"] == true
                              ? Icons.check_circle
                              : Icons.block,
                          color: appointment["certificateSent"] == true
                              ? Colors.white
                              : Colors.grey,
                        ),
                        label: Text(
                          "Done",
                          style: TextStyle(
                            fontSize: 16, 
                            color: appointment["certificateSent"] == true
                                ? Colors.white
                                : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernProgressStep({
    required IconData icon,
    required String title,
    required String description,
    required bool isCompleted,
    required int stepNumber,
    required bool isLastStep,
  }) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Step number and icon
            Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isCompleted 
                        ? Colors.green.shade500
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      if (isCompleted) 
                        BoxShadow(
                          color: Colors.green.withOpacity(0.3),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (isCompleted)
                        const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 20,
                        )
                      else
                        Text(
                          stepNumber.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
                if (!isLastStep)
                  Container(
                    width: 2,
                    height: 25,
                    color: isCompleted 
                        ? Colors.green.shade300
                        : Colors.grey.shade300,
                  ),
              ],
            ),
            const SizedBox(width: 16),
            // Content
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(bottom: 15),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isCompleted 
                      ? Colors.green.shade50
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isCompleted 
                        ? Colors.green.shade200
                        : Colors.grey.shade200,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isCompleted 
                              ? Colors.green.shade800
                              : Colors.grey.shade700,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 12,
                          color: isCompleted 
                              ? Colors.green.shade600
                              : Colors.grey.shade600,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModernSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.teal.shade700,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget ModernInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
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

// 🔹 Modern Section Title Widget
class SectionTitle extends StatelessWidget {
  final String title;
  const SectionTitle({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.teal.shade100,
            Colors.teal.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.teal.shade600,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.label,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.teal.shade800,
            ),
          ),
        ],
      ),
    );
  }
}

// 🔹 Modern Info Field Widget
class InfoField extends StatelessWidget {
  final IconData icon;
  final String text;
  const InfoField({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Colors.grey.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.teal.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon, 
              color: Colors.teal.shade700,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
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
