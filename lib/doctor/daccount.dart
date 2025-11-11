import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../login_screen.dart';

class Daccount extends StatefulWidget {
  const Daccount({super.key});

  @override
  State<Daccount> createState() => _DaccountState();
}

class _DaccountState extends State<Daccount> {
  Map<String, dynamic>? doctorData;
  bool isLoading = true;
  Map<String, bool> editingFields = {};
  bool hasUnsavedChanges = false;

  final TextEditingController usernameController = TextEditingController();
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController licenseController = TextEditingController();
  final TextEditingController specializationController =
      TextEditingController();
  final TextEditingController experienceController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadDoctorData();
  }

  Future<void> _loadDoctorData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docSnapshot = await FirebaseFirestore.instance
        .collection('doctors')
        .doc(user.uid)
        .get();

    if (docSnapshot.exists) {
      setState(() {
        doctorData = docSnapshot.data();
        isLoading = false;
        // Initialize controllers
        usernameController.text = doctorData?['username'] ?? '';
        fullNameController.text = doctorData?['fullName'] ?? '';
        licenseController.text = doctorData?['license'] ?? '';
        specializationController.text = doctorData?['specialization'] ?? '';
        experienceController.text = doctorData?['experience'] ?? '';
        passwordController.text = '********'; // Initialize password field
      });
    } else {
      setState(() => isLoading = false);
    }
  }

  Future<void> _saveField(String fieldName, String value) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('doctors')
            .doc(user.uid)
            .update({fieldName: value});

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$fieldName updated successfully')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating $fieldName: $e')),
        );
      }
    }
  }

  // Firebase facilities will be loaded dynamically

  Widget _modernAffiliationCard(Map<String, dynamic> affiliation) {
    final schedules = affiliation["schedules"] as List<dynamic>? ?? [];
    
    // Helper function to format schedule display
    String _formatScheduleDisplay(List<dynamic> schedules) {
      if (schedules.isEmpty) return "No schedule set";
      
      // Group consecutive days
      Map<String, List<String>> dayGroups = {};
      
      for (var schedule in schedules) {
        String day = schedule["day"] ?? "";
        String timeRange = "${schedule["start"] ?? ""} - ${schedule["end"] ?? ""}";
        
        if (dayGroups.containsKey(timeRange)) {
          dayGroups[timeRange]!.add(day);
        } else {
          dayGroups[timeRange] = [day];
        }
      }
      
      List<String> formattedSchedules = [];
      dayGroups.forEach((timeRange, dayList) {
        if (dayList.length >= 5 && 
            dayList.contains('Monday') && dayList.contains('Friday')) {
          formattedSchedules.add("Monday to Friday\n$timeRange");
        } else {
          for (String day in dayList) {
            formattedSchedules.add("$day\n$timeRange");
          }
        }
      });
      
      return formattedSchedules.join('\n\n');
    }

    // Get working hours, break time, and session duration from first schedule
    String workingHours = schedules.isNotEmpty ? "${schedules[0]["start"] ?? ""} - ${schedules[0]["end"] ?? ""}" : "Not set";
    String breakTime = schedules.isNotEmpty ? "${schedules[0]["breakStart"] ?? ""} - ${schedules[0]["breakEnd"] ?? ""}" : "Not set";
    String sessionDuration = schedules.isNotEmpty ? "${schedules[0]["sessionDuration"] ?? ""}min" : "Not set";

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Facility name and edit button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      affiliation["name"] ?? "",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      affiliation["address"] ?? "",
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _editSchedule(affiliation),
                icon: const Icon(Icons.edit, color: Colors.redAccent),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.grey.shade100,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Schedule section
          _buildInfoSection("Schedule", _formatScheduleDisplay(schedules)),
          const SizedBox(height: 12),
          
          // Working hours section
          _buildInfoSection("Working Hours", workingHours),
          const SizedBox(height: 12),
          
          // Break time section
          _buildInfoSection("Break Time", breakTime),
          const SizedBox(height: 12),
          
          // Session duration section
          _buildInfoSection("Session Duration", sessionDuration),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          content,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: Colors.grey.shade700,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  // Circular profile image
  Widget _buildCircularImage({String? url, double radius = 60}) {
    if (url != null && url.isNotEmpty) {
      final imageWidget = CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(url),
        backgroundColor: Colors.grey.shade200,
      );
      return GestureDetector(
        onTap: () => showDialog(
          context: context,
          builder: (_) => Dialog(
            child: InteractiveViewer(
              child: Image.network(url,
                  height: radius * 2, width: radius * 2, fit: BoxFit.cover),
            ),
          ),
        ),
        child: imageWidget,
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey.shade200,
      child: const Icon(Icons.person, size: 60, color: Colors.grey),
    );
  }

  // Add this method to edit schedules
  Future<void> _editSchedule(Map<String, dynamic> affiliation) async {
    try {
      // Debug: Print the current schedules
      debugPrint('=== EDIT SCHEDULE DEBUG START ===');
      debugPrint('Full affiliation data: $affiliation');
      debugPrint('Current affiliation schedules: ${affiliation["schedules"]}');
      
      List<Map<String, String>> currentSchedules = [];
      
      // Safely convert schedules - preserve actual saved values
      if (affiliation["schedules"] != null) {
        for (var schedule in affiliation["schedules"]) {
          if (schedule is Map) {
            // Debug: Print each schedule being processed
            debugPrint('Processing schedule: $schedule');
            
            // Only use fallback values if the actual data is null or empty
            String start = schedule["start"]?.toString() ?? "";
            String end = schedule["end"]?.toString() ?? "";
            String breakStart = schedule["breakStart"]?.toString() ?? "";
            String breakEnd = schedule["breakEnd"]?.toString() ?? "";
            
            currentSchedules.add({
              "day": schedule["day"]?.toString() ?? "Monday",
              "start": start.isEmpty ? "9:00 AM" : start,
              "end": end.isEmpty ? "5:00 PM" : end,
              "breakStart": breakStart.isEmpty ? "12:00 PM" : breakStart,
              "breakEnd": breakEnd.isEmpty ? "1:00 PM" : breakEnd,
              "sessionDuration": schedule["sessionDuration"]?.toString() ?? "30",
              "isRange": schedule["isRange"]?.toString() ?? "false",
              "endDay": schedule["endDay"]?.toString() ?? "",
            });
            
            // Debug: Print what was added
            debugPrint('Added to currentSchedules: ${currentSchedules.last}');
          }
        }
      }
      
      // If no schedules exist, add a default one with reasonable values
      if (currentSchedules.isEmpty) {
        currentSchedules.add({
          "day": "Monday",
          "start": "9:00 AM",
          "end": "5:00 PM",
          "breakStart": "12:00 PM",
          "breakEnd": "1:00 PM",
          "sessionDuration": "30",
          "isRange": "false",
          "endDay": "",
        });
      }

      debugPrint('Final currentSchedules to pass to dialog: $currentSchedules');
      debugPrint('=== EDIT SCHEDULE DEBUG END ===');

      await showDialog(
        context: context,
        builder: (context) => _ScheduleEditDialog(
          affiliationName: affiliation["name"] ?? "",
          currentSchedules: currentSchedules,
          onSave: (newSchedules, facilityName, facilityAddr) async {
            // Update facility info if changed
            affiliation["name"] = facilityName;
            affiliation["address"] = facilityAddr;
            await _updateDoctorSchedule(affiliation, newSchedules);
          },
        ),
      );
    } catch (e) {
      debugPrint('Error in _editSchedule: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening schedule editor: $e')),
      );
    }
  }

  // Update schedule in Firestore
  Future<void> _updateDoctorSchedule(
      Map<String, dynamic> affiliation, 
      List<Map<String, String>> newSchedules) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Update local data
      affiliation["schedules"] = newSchedules;

      // Update in Firestore
      await FirebaseFirestore.instance
          .collection('doctors')
          .doc(user.uid)
          .update({
        'affiliations': doctorData!['affiliations'],
      });

      setState(() {
        // Refresh UI
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Schedule updated successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating schedule: $e')),
      );
    }
  }

  Future<void> _logout() async {
    // Show confirmation dialog
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
                      Icon(Icons.logout, color: Colors.white, size: 22),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Confirm Logout',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Are you sure you want to log out of your account?',
                        style: TextStyle(fontSize: 14, color: Colors.black87),
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
                              onPressed: () {
                                Navigator.of(dialogContext).pop(true);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Logout', style: TextStyle(color: Colors.white)),
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
    
    if (confirmed == true) {
      try {
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          // Navigate directly to login screen and remove all previous routes
          Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const TBisitaLoginScreen()),
            (_) => false, // This removes ALL routes from the stack
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error logging out: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : doctorData == null
              ? const Center(child: Text("No doctor data found"))
              : Stack(
                  children: [
                    // Background gradient
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color.fromARGB(255, 255, 255, 255),
                            Color(0xFFFFEBEB)
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                    SafeArea(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            const SizedBox(height: 20),
                            // Profile header
                            Center(
                              child: _buildCircularImage(
                                url: doctorData!['profileImageUrl'],
                                radius: 50,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              doctorData!['fullName'] ?? '',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              doctorData!['email'] ?? '',
                              style: const TextStyle(color: Colors.black54),
                            ),
                            const SizedBox(height: 20),
                            // Sections
                            _buildSection(
                              title: "Bio",
                              description:
                                  "These details will be visible to patients. Please ensure accuracy.",
                              icon: Icons.person,
                              sectionId: "bio",
                              children: [
                                _buildFieldWithDescription(
                                  label: "Full Name",
                                  value: fullNameController.text,
                                  icon: Icons.badge,
                                  description:
                                      "Your complete name as it will appear to patients.",
                                  controller: fullNameController,
                                  fieldKey: "fullName",
                                ),
                                _buildFieldWithDescription(
                                  label: "Medical License",
                                  value: licenseController.text,
                                  icon: Icons.card_membership,
                                  description:
                                      "Your official medical license number.",
                                  controller: licenseController,
                                  fieldKey: "license",
                                ),
                                _buildFieldWithDescription(
                                  label: "Specialization",
                                  value: specializationController.text,
                                  icon: Icons.local_hospital,
                                  description:
                                      "Your area of medical expertise (e.g., Pulmonology, Pediatrics).",
                                  controller: specializationController,
                                  fieldKey: "specialization",
                                ),
                                _buildFieldWithDescription(
                                  label: "Experience",
                                  value: experienceController.text,
                                  icon: Icons.work_history,
                                  description:
                                      "Years of professional experience or a brief summary.",
                                  controller: experienceController,
                                  fieldKey: "experience",
                                ),
                                const Padding(
                                  padding: EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    "Note: Bio details will appear on your public profile and are visible to patients.",
                                    style: TextStyle(
                                        fontSize: 13, color: Colors.redAccent),
                                  ),
                                ),
                              ],
                            ),
                            _buildSection(
                              title: "Account",
                              description: "Account credentials and security",
                              icon: Icons.lock,
                              sectionId: "account",
                              children: [
                                _buildEditableField(
                                  "Username",
                                  usernameController.text,
                                  icon: Icons.person,
                                  controller: usernameController,
                                  fieldKey: "username",
                                ),
                                _buildEditableField(
                                  "Email",
                                  doctorData!['email'] ?? '',
                                  icon: Icons.email,
                                  readOnly: true,
                                  controller: null,
                                  fieldKey: "email",
                                ),
                                _buildEditableField(
                                  "Password",
                                  passwordController.text,
                                  icon: Icons.lock,
                                  obscure: true,
                                  controller: passwordController,
                                  fieldKey: "password",
                                ),
                              ],
                            ),
                            _buildSection(
                              title: "Affiliations",
                              description: "Hospitals and organizations",
                              icon: Icons.business,
                              sectionId: "affiliations",
                              children: [
                                doctorData!['affiliations'] != null
                                    ? Column(
                                        children: (doctorData!['affiliations']
                                                as List<dynamic>)
                                            .map((a) => _modernAffiliationCard(a))
                                            .toList(),
                                      )
                                    : Container(
                                        padding: const EdgeInsets.all(24),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [Colors.grey.shade50, Colors.grey.shade100],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: Colors.grey.shade200),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade300,
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Icon(
                                                Icons.business_outlined,
                                                color: Colors.grey.shade600,
                                                size: 24,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    "No affiliations added",
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.grey.shade700,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    "Contact admin to add hospital affiliations",
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 12,
                                                      color: Colors.grey.shade500,
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
                            const SizedBox(height: 24),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14, horizontal: 24),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30)),
                              ),
                              onPressed: _logout,
                              child: const Text("Log Out",
                                  style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  // Editable field with description for Bio section
  Widget _buildFieldWithDescription({
    required String label,
    required String value,
    required IconData icon,
    required String description,
    required TextEditingController controller,
    required String fieldKey,
    bool obscure = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildEditableField(
          label,
          value,
          icon: icon,
          controller: controller,
          obscure: obscure,
          fieldKey: fieldKey,
        ),
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
          child: Text(
            description,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ),
      ],
    );
  }

  // Section Card (ExpansionTile)
  final Set<String> expandedSections = {};

  void _toggleSection(String sectionId) {
    setState(() {
      if (expandedSections.contains(sectionId)) {
        expandedSections.remove(sectionId);
      } else {
        expandedSections.add(sectionId);
      }
    });
  }

  Widget _buildSection({
    required String title,
    required String description,
    required IconData icon,
    required String sectionId,
    required List<Widget> children,
  }) {
    final isExpanded = expandedSections.contains(sectionId);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.grey.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.redAccent.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ExpansionTile(
        initiallyExpanded: isExpanded,
        onExpansionChanged: (_) => _toggleSection(sectionId),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              alignment: Alignment.center,
              height: 48,
              child: Icon(icon, color: Colors.redAccent, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.all(16),
        children: children,
      ),
    );
  }

  // Editable field (read-only for email)
  Widget _buildEditableField(
    String label,
    String value, {
    IconData? icon,
    TextEditingController? controller,
    bool obscure = false,
    bool readOnly = false,
    required String fieldKey,
  }) {
    return GestureDetector(
      onTap: readOnly
          ? null
          : () => _editField(label, value, controller, fieldKey, obscure),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            if (icon != null) Icon(icon, color: Colors.redAccent, size: 20),
            if (icon != null) const SizedBox(width: 12),
            Expanded(
              child: Text(
                obscure ? "********" : value,
                style: const TextStyle(fontSize: 15),
              ),
            ),
            if (!readOnly)
              const Icon(Icons.edit, size: 18, color: Colors.redAccent),
          ],
        ),
      ),
    );
  }

  Future<void> _editField(String label, String currentValue,
      TextEditingController? controller, String fieldKey, bool obscure) async {
    final currentPasswordController = TextEditingController(text: '********');
    final newPasswordController = TextEditingController();
    bool newPasswordVisible = true; // Changed to true - visible by default
    await showDialog(
      context: context,
      builder: (context) {
        if (label != "Password") {
          // Default dialog for other fields
          final editController = TextEditingController(text: currentValue);
          return StatefulBuilder(
            builder: (context, setState) => Dialog(
              backgroundColor: Colors.transparent,
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.edit,
                          color: Colors.redAccent,
                          size: 28,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Edit $label',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: editController,
                      decoration: InputDecoration(
                        labelText: label,
                        labelStyle: const TextStyle(color: Colors.redAccent),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Colors.redAccent, width: 1.2),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Colors.redAccent, width: 2),
                        ),
                        fillColor: Colors.grey.shade50,
                        filled: true,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 10),
                          ),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () async {
                            final newValue = editController.text.trim();
                            if (newValue.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text('$label cannot be empty.')),
                              );
                              return;
                            }
                            await _saveField(fieldKey, newValue);
                            if (controller != null) controller.text = newValue;
                            await _loadDoctorData();
                            Navigator.pop(context);
                            setState(() {});
                          },
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        } else {
          // Password dialog with validation
          bool hasMinLength = false;
          bool hasUppercase = false;
          bool hasLowercase = false;
          bool hasNumber = false;
          bool hasSpecialChar = false;
          
          return StatefulBuilder(
            builder: (context, setState) {
              void validatePassword(String password) {
                setState(() {
                  hasMinLength = password.length >= 8;
                  hasUppercase = password.contains(RegExp(r'[A-Z]'));
                  hasLowercase = password.contains(RegExp(r'[a-z]'));
                  hasNumber = password.contains(RegExp(r'[0-9]'));
                  hasSpecialChar = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
                });
              }
              
              bool isPasswordValid = hasMinLength && hasUppercase && hasLowercase && hasNumber && hasSpecialChar;
              
              Widget buildRequirement(String text, bool isMet) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        isMet ? Icons.check_circle : Icons.cancel,
                        color: isMet ? Colors.green : Colors.red,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          text,
                          style: TextStyle(
                            fontSize: 13,
                            color: isMet ? Colors.green.shade700 : Colors.grey.shade600,
                            fontWeight: isMet ? FontWeight.w500 : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }
              
              return Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.8,
                  ),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.lock, color: Colors.redAccent, size: 28),
                            const SizedBox(width: 10),
                            const Text(
                              'Edit Password',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        TextField(
                          controller: currentPasswordController,
                          enabled: false,
                          decoration: InputDecoration(
                            labelText: 'Current Password',
                            labelStyle: const TextStyle(color: Colors.redAccent),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: Colors.redAccent, width: 1.2),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: Colors.redAccent, width: 2),
                            ),
                            fillColor: Colors.grey.shade50,
                            filled: true,
                          ),
                          obscureText: true,
                        ),
                        const SizedBox(height: 18),
                        TextField(
                          controller: newPasswordController,
                          onChanged: validatePassword,
                          decoration: InputDecoration(
                            labelText: 'New Password',
                            labelStyle: const TextStyle(color: Colors.redAccent),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: Colors.redAccent, width: 1.2),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: Colors.redAccent, width: 2),
                            ),
                            fillColor: Colors.grey.shade50,
                            filled: true,
                            suffixIcon: IconButton(
                              icon: Icon(
                                newPasswordVisible
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: Colors.redAccent,
                              ),
                              onPressed: () {
                                setState(() {
                                  newPasswordVisible = !newPasswordVisible;
                                });
                              },
                            ),
                          ),
                          obscureText: !newPasswordVisible,
                        ),
                        const SizedBox(height: 12),
                        
                        // Password strength indicator
                        if (newPasswordController.text.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      isPasswordValid ? Icons.check_circle : Icons.info_outline,
                                      color: isPasswordValid ? Colors.green : Colors.orange,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Password Requirements',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                buildRequirement('At least 8 characters', hasMinLength),
                                buildRequirement('Contains uppercase letter (A-Z)', hasUppercase),
                                buildRequirement('Contains lowercase letter (a-z)', hasLowercase),
                                buildRequirement('Contains number (0-9)', hasNumber),
                                buildRequirement('Contains special character (!@#\$%^&*)', hasSpecialChar),
                              ],
                            ),
                          ),
                        
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 10),
                              ),
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isPasswordValid ? Colors.redAccent : Colors.grey,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: !isPasswordValid ? null : () async {
                                final newPassword = newPasswordController.text.trim();
                                
                                // Show confirmation dialog
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  barrierColor: Colors.black.withOpacity(0.5),
                                  builder: (dialogContext) {
                                    final showPassword = ValueNotifier<bool>(true); // Changed to true - visible by default
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
                                                  Icon(Icons.security, color: Colors.white, size: 22),
                                                  SizedBox(width: 12),
                                                  Expanded(
                                                    child: Text(
                                                      'Confirm Password Change',
                                                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.all(18),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                                children: [
                                                  const Text(
                                                    'Are you sure you want to update your password?',
                                                    style: TextStyle(fontSize: 14, color: Colors.black87),
                                                  ),
                                                  const SizedBox(height: 12),
                                                  
                                                  // Password preview
                                                  Container(
                                                    padding: const EdgeInsets.all(12),
                                                    decoration: BoxDecoration(
                                                      color: Colors.grey.shade50,
                                                      borderRadius: BorderRadius.circular(12),
                                                      border: Border.all(color: Colors.grey.shade200),
                                                    ),
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text('New Password', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                                                        const SizedBox(height: 8),
                                                        Row(
                                                          children: [
                                                            Expanded(
                                                              child: ValueListenableBuilder<bool>(
                                                                valueListenable: showPassword,
                                                                builder: (context, show, _) {
                                                                  final passwordDisplay = show
                                                                      ? newPassword
                                                                      : List.filled(newPassword.length, '•').join();
                                                                  return Text(
                                                                    passwordDisplay,
                                                                    style: const TextStyle(letterSpacing: 1.2, fontWeight: FontWeight.w600),
                                                                  );
                                                                },
                                                              ),
                                                            ),
                                                            const SizedBox(width: 8),
                                                            InkWell(
                                                              onTap: () => showPassword.value = !showPassword.value,
                                                              borderRadius: BorderRadius.circular(8),
                                                              child: Padding(
                                                                padding: const EdgeInsets.all(6),
                                                                child: ValueListenableBuilder<bool>(
                                                                  valueListenable: showPassword,
                                                                  builder: (context, show, _) => Icon(
                                                                    show ? Icons.visibility : Icons.visibility_off,
                                                                    size: 20,
                                                                    color: Colors.grey.shade700,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
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
                                                          onPressed: () {
                                                            Navigator.of(dialogContext).pop(true);
                                                          },
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
                                
                                if (confirmed == true) {
                                  final user = FirebaseAuth.instance.currentUser;
                                  if (user != null) {
                                    try {
                                      await user.updatePassword(newPassword);
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Password updated successfully!'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    } catch (e) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Error: $e')),
                                      );
                                    }
                                  }
                                }
                              },
                              child: const Text('Save'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        }
      },
      barrierDismissible: false,
    );
  }
}

class _ScheduleEditDialog extends StatefulWidget {
  final String affiliationName;
  final List<Map<String, String>> currentSchedules;
  final Function(List<Map<String, String>>, String, String) onSave; // Updated to include facility info

  const _ScheduleEditDialog({
    required this.affiliationName,
    required this.currentSchedules,
    required this.onSave,
  });

  @override
  State<_ScheduleEditDialog> createState() => _ScheduleEditDialogState();
}

class _ScheduleEditDialogState extends State<_ScheduleEditDialog> {
  late List<Map<String, String>> schedules;
  final List<String> days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  
  // Facility management
  late String selectedFacility;
  late String facilityAddress;
  Map<String, String> facilities = {};
  bool isLoadingFacilities = true;

  @override
  void initState() {
    super.initState();
    
    // Debug: Print the received schedule data
    debugPrint('Dialog received schedules: ${widget.currentSchedules}');
    
    // Group consecutive days with same time settings into ranges
    schedules = _groupSchedulesIntoRanges(List.from(widget.currentSchedules));
    
    debugPrint('Dialog grouped schedules: $schedules');
    
    selectedFacility = widget.affiliationName;
    facilityAddress = 'Loading...';
    
    _loadFacilities();
    
    // Fix invalid day values but preserve all other saved data
    for (var schedule in schedules) {
      if (schedule["day"] != null && !days.contains(schedule["day"]) && !schedule["day"]!.contains(" to ")) {
        // If day is something invalid, default to Monday
        schedule["day"] = "Monday";
      }
      // Only set defaults for missing fields, don't override existing data
      schedule["isRange"] ??= "false";
      schedule["endDay"] ??= "";
      debugPrint('Schedule after validation: $schedule');
    }
  }

  // Group consecutive days with same schedule settings into ranges
  List<Map<String, String>> _groupSchedulesIntoRanges(List<Map<String, String>> inputSchedules) {
    if (inputSchedules.isEmpty) return inputSchedules;
    
    // Group schedules by their time settings (start, end, break times, session duration)
    Map<String, List<Map<String, String>>> timeGroups = {};
    
    for (var schedule in inputSchedules) {
      String timeKey = "${schedule["start"]}-${schedule["end"]}-${schedule["breakStart"]}-${schedule["breakEnd"]}-${schedule["sessionDuration"]}";
      
      if (timeGroups.containsKey(timeKey)) {
        timeGroups[timeKey]!.add(schedule);
      } else {
        timeGroups[timeKey] = [schedule];
      }
    }
    
    List<Map<String, String>> groupedSchedules = [];
    
    // Process each time group
    for (var timeGroup in timeGroups.values) {
      if (timeGroup.length == 1) {
        // Single day schedule
        groupedSchedules.add(timeGroup[0]);
      } else {
        // Multiple days with same time - check if they're consecutive
        List<String> dayNames = timeGroup.map((s) => s["day"] ?? "").toList();
        dayNames.sort((a, b) => days.indexOf(a).compareTo(days.indexOf(b)));
        
        // Check if days are consecutive Monday to Friday pattern
        if (dayNames.length >= 2) {
          int firstIndex = days.indexOf(dayNames.first);
          
          // Check if it's a consecutive range
          bool isConsecutive = true;
          for (int i = 0; i < dayNames.length; i++) {
            if (days.indexOf(dayNames[i]) != firstIndex + i) {
              isConsecutive = false;
              break;
            }
          }
          
          if (isConsecutive && dayNames.length >= 3) {
            // Create a range schedule
            var firstSchedule = timeGroup[0];
            groupedSchedules.add({
              "day": dayNames.first,
              "endDay": dayNames.last,
              "start": firstSchedule["start"] ?? "9:00 AM",
              "end": firstSchedule["end"] ?? "5:00 PM",
              "breakStart": firstSchedule["breakStart"] ?? "12:00 PM",
              "breakEnd": firstSchedule["breakEnd"] ?? "1:00 PM",
              "sessionDuration": firstSchedule["sessionDuration"] ?? "30",
              "isRange": "true",
            });
          } else {
            // Not consecutive, add as individual schedules
            groupedSchedules.addAll(timeGroup);
          }
        } else {
          // Less than 2 days, add as individual schedules
          groupedSchedules.addAll(timeGroup);
        }
      }
    }
    
    return groupedSchedules;
  }

  // Load facilities from Firebase
  Future<void> _loadFacilities() async {
    try {
      final facilitiesSnapshot = await FirebaseFirestore.instance
          .collection('facilities')
          .get();
      
      Map<String, String> loadedFacilities = {};
      for (var doc in facilitiesSnapshot.docs) {
        final data = doc.data();
        loadedFacilities[data['name'] ?? doc.id] = data['address'] ?? 'Address not available';
      }
      
      // If no facilities found in Firebase, add some default TB DOTS facilities
      if (loadedFacilities.isEmpty) {
        loadedFacilities = {
          'AGDAO': 'Agdao Public Market Corner Lapu-Lapu & C. Bangoy St., Agdao, Davao City',
          'BAGUIO': 'Baguio District Health Center, Davao City',
          'BUNAWAN': 'Bunawan District Health Center, Davao City',
          'CALINAN': 'P34, Aurora St., Calinan, Davao City',
          'DAVAO CHEST CENTER': 'Villa Abrille St., Brgy 30-C, Davao City',
          'DISTRICT A (TOMAS CLAUDIO HC)': 'Camus Ext., Corner Quirino Ave., Davao City',
          'DISTRICT B (EL RIO HC)': 'Garcia Heights, Bajada, Davao City',
          'DISTICT C (MINIFOREST HC)': 'Brgy 23-C, Quezon Boulevard, Davao City',
          'DISTRICT D (JACINTO HC)': 'Emilio Jacinto St., Davao City',
          'MARILOG (MARAHAN HC)': 'Sitio Marahan, Brgy. Marilog, Davao City',
          'PAQUIBATO (MALABOG HC)': 'Brgy Malabog, Davao City',
          'SASA': 'Bangoy Km 9, Sasa, Davao City',
          'TALOMO CENTRAL (GSIS HC)': 'GSIS Village, Matina, Davao City',
          'TALOMO NORTH (SIR HC)': 'Daang Patnubay St., SIR Ph-1, Sandawa, Davao City',
          'TALOMO SOUTH (PUAN HC)': 'Puan, Talomo, Davao City',
          'TORIL A': 'Agton St., Toril, Davao City',
          'TORIL B': 'Juan Dela Cruz St., Daliao, Toril, Davao City',
          'TUGBOK': 'Sampaguita St., Mintal, Tugbok District, Davao City',
          'WAAN': 'Waan District Health Center, Davao City'
        };
      }
      
      setState(() {
        facilities = loadedFacilities;
        isLoadingFacilities = false;
        
        // Check if current facility exists in loaded facilities
        if (facilities.containsKey(widget.affiliationName)) {
          selectedFacility = widget.affiliationName;
        } else if (facilities.isNotEmpty) {
          // Default to first facility if current one doesn't exist
          selectedFacility = facilities.keys.first;
        }
        facilityAddress = facilities[selectedFacility] ?? 'Address not available';
      });
    } catch (e) {
      // Fallback to default TB DOTS facilities if Firebase fails
      setState(() {
        isLoadingFacilities = false;
        facilities = {
          'AGDAO': 'Agdao Public Market Corner Lapu-Lapu & C. Bangoy St., Agdao, Davao City',
          'BAGUIO': 'Baguio District Health Center, Davao City',
          'BUNAWAN': 'Bunawan District Health Center, Davao City',
          'CALINAN': 'P34, Aurora St., Calinan, Davao City',
          'DAVAO CHEST CENTER': 'Villa Abrille St., Brgy 30-C, Davao City',
          'DISTRICT A (TOMAS CLAUDIO HC)': 'Camus Ext., Corner Quirino Ave., Davao City',
          'DISTRICT B (EL RIO HC)': 'Garcia Heights, Bajada, Davao City',
          'DISTICT C (MINIFOREST HC)': 'Brgy 23-C, Quezon Boulevard, Davao City',
          'DISTRICT D (JACINTO HC)': 'Emilio Jacinto St., Davao City',
          'MARILOG (MARAHAN HC)': 'Sitio Marahan, Brgy. Marilog, Davao City',
          'PAQUIBATO (MALABOG HC)': 'Brgy Malabog, Davao City',
          'SASA': 'Bangoy Km 9, Sasa, Davao City',
          'TALOMO CENTRAL (GSIS HC)': 'GSIS Village, Matina, Davao City',
          'TALOMO NORTH (SIR HC)': 'Daang Patnubay St., SIR Ph-1, Sandawa, Davao City',
          'TALOMO SOUTH (PUAN HC)': 'Puan, Talomo, Davao City',
        };
        selectedFacility = facilities.keys.first;
        facilityAddress = facilities[selectedFacility] ?? 'Address not available';
      });
    }
  }

  void _updateFacilityAddress(String facility) {
    setState(() {
      selectedFacility = facility;
      facilityAddress = facilities[facility] ?? 'Address not available';
    });
  }

  // Helper method to expand day ranges into individual days
  List<Map<String, String>> _expandScheduleRanges(List<Map<String, String>> inputSchedules) {
    List<Map<String, String>> expandedSchedules = [];
    
    for (var schedule in inputSchedules) {
      bool isRange = schedule["isRange"] == "true";
      
      if (isRange && schedule["endDay"] != null && schedule["endDay"]!.isNotEmpty) {
        // Handle range like "Monday to Friday"
        String startDay = schedule["day"] ?? "Monday";
        String endDay = schedule["endDay"]!;
        
        int startIndex = days.indexOf(startDay);
        int endIndex = days.indexOf(endDay);
        
        if (startIndex != -1 && endIndex != -1 && startIndex <= endIndex) {
          // Create individual schedules for each day in range
          for (int i = startIndex; i <= endIndex; i++) {
            expandedSchedules.add({
              "day": days[i],
              "start": schedule["start"] ?? "9:00 AM",
              "end": schedule["end"] ?? "5:00 PM",
              "breakStart": schedule["breakStart"] ?? "12:00 PM",
              "breakEnd": schedule["breakEnd"] ?? "1:00 PM",
              "sessionDuration": schedule["sessionDuration"] ?? "30",
            });
          }
        }
      } else {
        // Single day schedule
        expandedSchedules.add({
          "day": schedule["day"] ?? "Monday",
          "start": schedule["start"] ?? "9:00 AM",
          "end": schedule["end"] ?? "5:00 PM",
          "breakStart": schedule["breakStart"] ?? "12:00 PM",
          "breakEnd": schedule["breakEnd"] ?? "1:00 PM",
          "sessionDuration": schedule["sessionDuration"] ?? "30",
        });
      }
    }
    
    return expandedSchedules;
  }

  // Helper method to build time picker with hour, minute, and AM/PM dropdowns
  Widget _buildTimePicker(String currentTime, Function(String) onTimeChanged) {
    // Parse current time or use default format 00:00 AM
    final parts = currentTime.split(' ');
    final timePart = parts[0];
    final period = parts.length > 1 ? parts[1] : 'AM';
    final timeParts = timePart.split(':');
    final hour = timeParts[0];
    final minute = timeParts.length > 1 ? timeParts[1] : '00';

    return Row(
      children: [
        // Hour text field
        Expanded(
          flex: 2,
          child: TextFormField(
            initialValue: hour.padLeft(2, '0'),
            decoration: InputDecoration(
              labelText: 'Hour',
              labelStyle: GoogleFonts.poppins(fontSize: 11),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Colors.redAccent),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              isDense: true,
            ),
            style: GoogleFonts.poppins(fontSize: 13),
            keyboardType: TextInputType.number,
            maxLength: 2,
            buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
            onChanged: (value) {
              if (value.isNotEmpty && int.tryParse(value) != null) {
                final paddedValue = value.padLeft(2, '0');
                onTimeChanged('$paddedValue:$minute $period');
              }
            },
          ),
        ),
        const SizedBox(width: 2),
        Text(':', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(width: 2),
        // Minute text field
        Expanded(
          flex: 2,
          child: TextFormField(
            initialValue: minute.padLeft(2, '0'),
            decoration: InputDecoration(
              labelText: 'Min',
              labelStyle: GoogleFonts.poppins(fontSize: 11),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Colors.redAccent),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              isDense: true,
            ),
            style: GoogleFonts.poppins(fontSize: 13),
            keyboardType: TextInputType.number,
            maxLength: 2,
            buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
            onChanged: (value) {
              if (value.isNotEmpty && int.tryParse(value) != null) {
                final paddedValue = value.padLeft(2, '0');
                onTimeChanged('$hour:$paddedValue $period');
              }
            },
          ),
        ),
        const SizedBox(width: 6),
        // AM/PM dropdown
        Expanded(
          flex: 3,
          child: DropdownButtonFormField<String>(
            value: period,
            decoration: InputDecoration(
              labelText: 'AM/PM',
              labelStyle: GoogleFonts.poppins(fontSize: 11),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Colors.redAccent),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              isDense: true,
            ),
            items: ['AM', 'PM'].map((p) => DropdownMenuItem(
              value: p,
              child: Text(p, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
            )).toList(),
            onChanged: (value) {
              onTimeChanged('$hour:$minute $value');
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.95,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Colors.grey.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.redAccent.withOpacity(0.1),
              blurRadius: 30,
              offset: const Offset(0, 10),
              spreadRadius: 5,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Modern Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.redAccent.withOpacity(0.1),
                    Colors.redAccent.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
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
                      gradient: LinearGradient(
                        colors: [Colors.redAccent, Colors.redAccent.shade400],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.redAccent.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.edit_calendar_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Edit Schedule',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade800,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Content Area
            Flexible(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [

                    
                    Expanded(
                      child: ListView.builder(
                        itemCount: schedules.length + 1, // +1 for facility container
                        itemBuilder: (context, index) {
                          // First item is the facility container
                          if (index == 0) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade200),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Header
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.redAccent.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            'Facility Information',
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.redAccent,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    
                                    // Facility Dropdown
                                    isLoadingFacilities
                                        ? Container(
                                            padding: const EdgeInsets.all(16),
                                            child: Row(
                                              children: [
                                                const SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child: CircularProgressIndicator(strokeWidth: 2),
                                                ),
                                                const SizedBox(width: 12),
                                                Text(
                                                  'Loading facilities...',
                                                  style: GoogleFonts.poppins(fontSize: 11),
                                                ),
                                              ],
                                            ),
                                          )
                                        : facilities.isEmpty
                                            ? Container(
                                                padding: const EdgeInsets.all(16),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(10),
                                                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.warning, color: Colors.orange, size: 16),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Text(
                                                        'No facilities available. Please contact administrator.',
                                                        style: GoogleFonts.poppins(fontSize: 11, color: Colors.orange.shade700),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              )
                                            : DropdownButtonFormField<String>(
                                                value: facilities.containsKey(selectedFacility) ? selectedFacility : (facilities.isNotEmpty ? facilities.keys.first : null),
                                                decoration: InputDecoration(
                                                  labelText: 'Select Facility',
                                                  labelStyle: GoogleFonts.poppins(fontSize: 11),
                                                  border: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(10),
                                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                                  ),
                                                  focusedBorder: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(10),
                                                    borderSide: const BorderSide(color: Colors.redAccent),
                                                  ),
                                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                  isDense: true,
                                                  filled: true,
                                                  fillColor: Colors.white,
                                                ),
                                                items: facilities.keys.map((facility) => DropdownMenuItem(
                                                  value: facility,
                                                  child: Text(
                                                    facility,
                                                    style: GoogleFonts.poppins(fontSize: 11),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                )).toList(),
                                                onChanged: facilities.isNotEmpty ? (value) {
                                                  if (value != null) {
                                                    _updateFacilityAddress(value);
                                                  }
                                                } : null,
                                                isExpanded: true,
                                              ),
                                    const SizedBox(height: 12),
                                    
                                    // Address Display
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Address',
                                            style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.blue.shade700,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            facilityAddress,
                                            style: GoogleFonts.poppins(
                                              fontSize: 11,
                                              color: Colors.grey.shade600,
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
                          
                          // Schedule containers (adjust index by -1)
                          final schedule = schedules[index - 1];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header with day and delete button
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.redAccent.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          'Schedule ${index}', // Start from 1 since index-1 is the actual schedule index, but we want to display starting from 1
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.redAccent,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(8),
                                          onTap: () {
                                            setState(() {
                                              schedules.removeAt(index - 1);
                                            });
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.all(8),
                                            child: Icon(
                                              Icons.delete_rounded,
                                              color: Colors.red.shade400,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  
                                  // Day Range Toggle
                                  Row(
                                    children: [
                                      Expanded(
                                        child: CheckboxListTile(
                                          title: Text(
                                            'Day Range',
                                            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
                                          ),
                                          subtitle: Text(
                                            'Apply to multiple consecutive days',
                                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                                          ),
                                          value: schedule["isRange"] == "true",
                                          onChanged: (value) {
                                            setState(() {
                                              schedules[index - 1]["isRange"] = value.toString();
                                              if (!value!) {
                                                schedules[index - 1]["endDay"] = "";
                                              }
                                            });
                                          },
                                          controlAffinity: ListTileControlAffinity.leading,
                                          contentPadding: EdgeInsets.zero,
                                          dense: true,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  
                                  // Day Selection Section
                                  if (schedule["isRange"] == "true") ...[
                                    // Starts and Ends labels
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Starts',
                                            style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Ends',
                                            style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    // Day dropdowns
                                    Row(
                                      children: [
                                        Expanded(
                                          flex: 1,
                                          child: DropdownButtonFormField<String>(
                                            value: days.contains(schedule["day"]) ? schedule["day"] : days.first,
                                            decoration: InputDecoration(
                                              labelText: 'Starts',
                                              labelStyle: GoogleFonts.poppins(fontSize: 10),
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(6),
                                                borderSide: BorderSide(color: Colors.grey.shade300),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(6),
                                                borderSide: const BorderSide(color: Colors.redAccent),
                                              ),
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                              isDense: true,
                                              filled: true,
                                              fillColor: Colors.white,
                                            ),
                                            items: days.map((day) => DropdownMenuItem(
                                              value: day,
                                              child: Text(day, style: GoogleFonts.poppins(fontSize: 11)),
                                            )).toList(),
                                            onChanged: (value) {
                                              setState(() {
                                                schedules[index - 1]["day"] = value ?? days.first;
                                              });
                                            },
                                            isExpanded: true,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          flex: 1,
                                          child: DropdownButtonFormField<String>(
                                            value: schedule["endDay"]?.isNotEmpty == true && days.contains(schedule["endDay"]) 
                                                ? schedule["endDay"] 
                                                : null,
                                            decoration: InputDecoration(
                                              labelText: 'Ends',
                                              labelStyle: GoogleFonts.poppins(fontSize: 10),
                                              hintText: 'Friday',
                                              hintStyle: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500),
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(6),
                                                borderSide: BorderSide(color: Colors.grey.shade300),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(6),
                                                borderSide: const BorderSide(color: Colors.redAccent),
                                              ),
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                              isDense: true,
                                              filled: true,
                                              fillColor: Colors.white,
                                            ),
                                            items: days.map((day) => DropdownMenuItem(
                                              value: day,
                                              child: Text(day, style: GoogleFonts.poppins(fontSize: 11)),
                                            )).toList(),
                                            onChanged: (value) {
                                              setState(() {
                                                schedules[index - 1]["endDay"] = value ?? "";
                                              });
                                            },
                                            isExpanded: true,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ] else ...[
                                    DropdownButtonFormField<String>(
                                      value: days.contains(schedule["day"]) ? schedule["day"] : days.first,
                                      decoration: InputDecoration(
                                        labelText: 'Day',
                                        labelStyle: GoogleFonts.poppins(fontSize: 11),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(6),
                                          borderSide: BorderSide(color: Colors.grey.shade300),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(6),
                                          borderSide: const BorderSide(color: Colors.redAccent),
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                        isDense: true,
                                        filled: true,
                                        fillColor: Colors.white,
                                      ),
                                      items: days.map((day) => DropdownMenuItem(
                                        value: day,
                                        child: Text(day, style: GoogleFonts.poppins(fontSize: 11)),
                                      )).toList(),
                                      onChanged: (value) {
                                        setState(() {
                                          schedules[index - 1]["day"] = value ?? days.first;
                                        });
                                      },
                                      isExpanded: true,
                                    ),
                                  ],
                                  const SizedBox(height: 16),
                                  
                                  // Working Hours Section  
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Working Hours',
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.blue.shade700,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        // Starts time
                                        Text(
                                          'Starts',
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        _buildTimePicker(
                                          schedule["start"] ?? "9:00 AM",
                                          (value) => schedules[index - 1]["start"] = value,
                                        ),
                                        const SizedBox(height: 10),
                                        // Ends time
                                        Text(
                                          'Ends',
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        _buildTimePicker(
                                          schedule["end"] ?? "5:00 PM",
                                          (value) => schedules[index - 1]["end"] = value,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  
                                  // Break Time Section
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Break Time',
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.orange.shade700,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        // Starts time
                                        Text(
                                          'Starts',
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        _buildTimePicker(
                                          schedule["breakStart"] ?? "12:00 PM",
                                          (value) => schedules[index - 1]["breakStart"] = value,
                                        ),
                                        const SizedBox(height: 10),
                                        // Ends time
                                        Text(
                                          'Ends',
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        _buildTimePicker(
                                          schedule["breakEnd"] ?? "1:00 PM",
                                          (value) => schedules[index - 1]["breakEnd"] = value,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  
                                  // Session Duration Section
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Session Duration',
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.green.shade700,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        DropdownButtonFormField<String>(
                                          value: schedule["sessionDuration"] ?? "30",
                                          decoration: InputDecoration(
                                            labelText: 'Duration per session',
                                            labelStyle: GoogleFonts.poppins(fontSize: 11),
                                            prefixIcon: const Icon(Icons.timer_outlined, size: 16),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(10),
                                              borderSide: BorderSide(color: Colors.grey.shade300),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(10),
                                              borderSide: const BorderSide(color: Colors.green),
                                            ),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            isDense: true,
                                          ),
                                          items: [
                                            DropdownMenuItem(value: "15", child: Text("15 minutes", style: GoogleFonts.poppins(fontSize: 11))),
                                            DropdownMenuItem(value: "30", child: Text("30 minutes", style: GoogleFonts.poppins(fontSize: 11))),
                                            DropdownMenuItem(value: "45", child: Text("45 minutes", style: GoogleFonts.poppins(fontSize: 11))),
                                            DropdownMenuItem(value: "60", child: Text("60 minutes", style: GoogleFonts.poppins(fontSize: 11))),
                                          ],
                                          onChanged: (value) {
                                            setState(() {
                                              schedules[index - 1]["sessionDuration"] = value ?? "30";
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ], // Main Column children closing bracket
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    
                    // Add Schedule Button
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(vertical: 16),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            schedules.add({
                              "day": "Monday",
                              "start": "9:00 AM",
                              "end": "5:00 PM",
                              "breakStart": "12:00 PM",
                              "breakEnd": "1:00 PM",
                              "sessionDuration": "30",
                              "isRange": "false",
                              "endDay": "",
                            });
                          });
                        },
                        icon: const Icon(Icons.add_rounded, color: Colors.white),
                        label: Text(
                          'Add New Schedule',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Action Buttons
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      // Expand day ranges before saving
                      final expandedSchedules = _expandScheduleRanges(schedules);
                      widget.onSave(expandedSchedules, selectedFacility, facilityAddress);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: Text(
                      'Save Changes',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
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
}
