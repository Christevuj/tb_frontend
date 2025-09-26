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
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: accent, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _affiliationCard(Map<String, dynamic> affiliation) {
    final schedules = affiliation["schedules"] as List<dynamic>? ?? [];
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.local_hospital, color: accent, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    affiliation["name"] ?? "",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
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
          'affiliationId': affiliationId, // This is what ghealthworkers.dart looks for
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
      appBar: AppBar(
        title: Text(
          "Review Information",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: accent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(14.0),
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
          Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Row(
                children: [
                  const Icon(Icons.lock, color: accent, size: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: "Password: ",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                        children: [
                          TextSpan(
                            text: widget.password,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _infoCard(Icons.medical_services, "Role", widget.role),
          const SizedBox(height: 24),

          // Role-specific Section
          Text(
            widget.role == 'Doctor'
                ? "Clinical Practice Details"
                : "Workplace Information",
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: accent,
            ),
          ),
          const SizedBox(height: 10),

          if (widget.role == 'Doctor' && widget.affiliations != null) ...[
            Text(
              "TB DOTS Facilities",
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            widget.affiliations!.isNotEmpty
                ? Column(
                    children: widget.affiliations!
                        .map((a) => _affiliationCard(a))
                        .toList(),
                  )
                : Text(
                    "No facilities added",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  ),
          ] else if (widget.role == 'Health Worker' &&
              widget.facility != null) ...[
            _infoCard(
                Icons.business, "TB DOTS Facility", widget.facility!["name"]),
            Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: accent),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Facility Address",
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 36),
                      child: Text(
                        widget.facility!["address"],
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          _isSubmitting
              ? const Center(child: CircularProgressIndicator(color: accent))
              : ElevatedButton.icon(
                  onPressed: _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.check_circle_outline,
                      color: Colors.white),
                  label: Text(
                    "Submit",
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}
