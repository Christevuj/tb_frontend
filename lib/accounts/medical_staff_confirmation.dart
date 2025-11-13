import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MedicalStaffConfirmationPage extends StatefulWidget {
  final String email;
  final String password;
  final String fullName;
  final String role;
  final String specialization;
  final Map<String, dynamic>? facility;
  final List<Map<String, dynamic>>? affiliations;

  const MedicalStaffConfirmationPage({
    super.key,
    required this.email,
    required this.password,
    required this.fullName,
    required this.role,
    required this.specialization,
    this.facility,
    this.affiliations,
  });

  @override
  State<MedicalStaffConfirmationPage> createState() =>
      _MedicalStaffConfirmationPageState();
}

class _MedicalStaffConfirmationPageState
    extends State<MedicalStaffConfirmationPage> {
  bool _isSubmitting = false;
  static const accent = Color.fromRGBO(255, 82, 82, 1);

  Widget _infoCard(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.1),
              border: Border.all(color: accent.withOpacity(0.3), width: 1),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _affiliationCard(Map<String, dynamic> affiliation) {
    final schedules = affiliation["schedules"] as List<dynamic>? ?? [];
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.1),
                  border: Border.all(color: accent.withOpacity(0.3), width: 1),
                ),
                child:
                    const Icon(Icons.local_hospital, color: accent, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  affiliation["name"] ?? "",
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.grey, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  affiliation["address"] ?? "",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
              ),
            ],
          ),
          if (schedules.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.access_time, color: Colors.grey, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: schedules
                        .map(
                          (s) => Padding(
                            padding: const EdgeInsets.only(top: 2.0),
                            child: Text(
                              "${s["day"]} | ${s["start"]} - ${s["end"]}",
                              style: GoogleFonts.poppins(fontSize: 14),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleSubmit() async {
    setState(() => _isSubmitting = true);

    try {
      // Create Firebase Auth account
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
              email: widget.email, password: widget.password);

      final uid = userCredential.user!.uid;

      // Helper function to get facility ID from Firebase
      Future<String?> getFacilityId(String facilityName) async {
        try {
          final querySnapshot = await FirebaseFirestore.instance
              .collection('affiliation')
              .where('name', isEqualTo: facilityName)
              .limit(1)
              .get();

          if (querySnapshot.docs.isNotEmpty) {
            return querySnapshot.docs.first.id;
          }
        } catch (e) {
          print('Error getting facility ID: $e');
        }
        return null;
      }

      // Prepare user data as Map<String, dynamic>
      final Map<String, dynamic> baseData = {
        "email": widget.email,
        "fullName": widget.fullName,
        "role": widget.role,
        "specialization": widget.specialization,
        "createdAt": FieldValue.serverTimestamp(),
        "tempPassword": widget.password, // Store temporary password for email
      };

      // Add role-specific data
      if (widget.role == 'Doctor') {
        // Process affiliations to get the correct affiliationId
        List<Map<String, dynamic>> processedAffiliations = [];

        if (widget.affiliations != null) {
          for (var affiliation in widget.affiliations!) {
            final facilityId = await getFacilityId(affiliation['name']);
            processedAffiliations.add({
              ...affiliation,
              'affiliationId': facilityId, // Add the Firebase facility ID
            });
          }
        }

        await FirebaseFirestore.instance.collection("doctors").doc(uid).set({
          ...baseData,
          'affiliations': processedAffiliations,
        });
      } else {
        // Health Worker - get the affiliationId for the selected facility
        String? affiliationId;
        if (widget.facility != null) {
          affiliationId = await getFacilityId(widget.facility!['name']);
        }

        final Map<String, dynamic> facilityData = {
          ...baseData,
          'facility': widget.facility,
          'affiliationId':
              affiliationId, // This is what ghealthworkers.dart looks for
        };
        await FirebaseFirestore.instance
            .collection("healthcare")
            .doc(uid)
            .set(facilityData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "✅ ${widget.role} account created successfully!",
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "❌ Failed to create account: $e",
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.5),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: accent,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.3), width: 1),
                      ),
                      child: const Icon(
                        Icons.check_circle_outline,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Review Information',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.3), width: 1),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Basic Information Section
                    Text(
                      "Personal Information",
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: accent,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _infoCard(Icons.person, "Full Name", widget.fullName),
                    _infoCard(Icons.email, "Email", widget.email),
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.all(14.0),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        border:
                            Border.all(color: Colors.grey.shade300, width: 1),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: accent.withOpacity(0.1),
                              border: Border.all(
                                  color: accent.withOpacity(0.3), width: 1),
                            ),
                            child:
                                const Icon(Icons.lock, color: accent, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Password",
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.password,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    _infoCard(Icons.medical_services, "Role", widget.role),
                    const SizedBox(height: 24),
                    // Submit Button
                    _isSubmitting
                        ? const Center(
                            child: CircularProgressIndicator(color: accent))
                        : Container(
                            decoration: BoxDecoration(
                              color: accent,
                              border: Border.all(
                                color: const Color.fromRGBO(230, 74, 74, 1),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: accent.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _handleSubmit,
                                child: Container(
                                  width: double.infinity,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.check_circle_outline,
                                          color: Colors.white, size: 22),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Submit',
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ], // End of ListView children
                ), // End of ListView
              ), // End of Expanded
            ], // End of Column children
          ), // End of Column (Container child)
        ), // End of Container (Center child)
      ), // End of Center (Scaffold body)
    ); // End of Scaffold
  }
}
