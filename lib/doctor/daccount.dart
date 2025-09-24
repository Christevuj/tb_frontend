import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/dialog_utils.dart';
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

  Widget _infoCard(
      IconData icon, String label, TextEditingController controller,
      {bool readOnly = false, bool isPassword = false}) {
    final String fieldKey = label.toLowerCase().replaceAll(' ', '_');
    final bool isEditingField = editingFields[fieldKey] ?? false;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Row(
          children: [
            Icon(icon, color: Colors.redAccent, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: controller,
                readOnly: !isEditingField || readOnly,
                obscureText: isPassword &&
                    (obscurePassword ||
                        (!isEditingField && controller.text == '********')),
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
                onChanged: (value) {
                  setState(() {
                    hasUnsavedChanges = true;
                  });
                },
                decoration: InputDecoration(
                  labelText: label,
                  border: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: isEditingField
                          ? Colors.redAccent
                          : Colors.transparent,
                    ),
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: isEditingField
                          ? Colors.redAccent
                          : Colors.transparent,
                    ),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.redAccent,
                      width: 2,
                    ),
                  ),
                  suffixIcon: isPassword &&
                          (isEditingField || controller.text != '********')
                      ? IconButton(
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.grey.shade400,
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() {
                              obscurePassword = !obscurePassword;
                            });
                          },
                        )
                      : null,
                ),
              ),
            ),
            if (!readOnly)
              IconButton(
                icon: Icon(
                  isEditingField ? Icons.save : Icons.edit,
                  color:
                      isEditingField ? Colors.redAccent : Colors.grey.shade400,
                  size: 20,
                ),
                onPressed: () async {
                  if (isEditingField) {
                    // Save changes
                    if (isPassword) {
                      if (controller.text.isNotEmpty) {
                        try {
                          final user = FirebaseAuth.instance.currentUser;
                          if (user != null && user.email != null) {
                            // Get current password for re-authentication
                            final currentPassword =
                                await DialogUtils.showPasswordConfirmDialog(
                                    context);

                            if (currentPassword != null &&
                                currentPassword.isNotEmpty) {
                              // Create credentials with current password
                              final credential = EmailAuthProvider.credential(
                                email: user.email!,
                                password: currentPassword,
                              );

                              // Re-authenticate user
                              await user
                                  .reauthenticateWithCredential(credential);

                              // Update password
                              await user.updatePassword(controller.text);

                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('Password updated successfully'),
                                  ),
                                );
                              }
                            }
                          }
                        } on FirebaseAuthException catch (e) {
                          if (mounted) {
                            String errorMessage;
                            switch (e.code) {
                              case 'wrong-password':
                                errorMessage = 'Current password is incorrect';
                                break;
                              case 'weak-password':
                                errorMessage =
                                    'New password is too weak. Please use at least 6 characters';
                                break;
                              case 'requires-recent-login':
                                errorMessage =
                                    'Please log out and log in again before changing your password';
                                break;
                              default:
                                errorMessage =
                                    e.message ?? 'Error updating password';
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(errorMessage)),
                            );
                          }
                        }
                      }
                      // Always reset password field and state
                      setState(() {
                        controller.text = '********';
                        editingFields[fieldKey] = false;
                        obscurePassword = true;
                      });
                    } else {
                      // Save non-password field
                      await _saveField(fieldKey, controller.text);
                      setState(() {
                        editingFields[fieldKey] = false;
                      });
                    }
                  } else {
                    // Start editing
                    setState(() {
                      editingFields[fieldKey] = true;
                      if (isPassword) {
                        controller.text =
                            ''; // Clear password field for new input
                      }
                    });
                  }
                },
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
            // Name
            Row(
              children: [
                const Icon(Icons.local_hospital,
                    color: Colors.redAccent, size: 18),
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
            // Address
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
            const SizedBox(height: 6),
            // Schedules
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
        ),
      ),
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

  Future<void> _logout() async {
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
                          colors: [Color.fromARGB(255, 255, 255, 255), Color(0xFFFFEBEB)],
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
                              description: "These details will be visible to patients. Please ensure accuracy.",
                              icon: Icons.person,
                              sectionId: "bio",
                              children: [
                                _buildFieldWithDescription(
                                  label: "Full Name",
                                  value: fullNameController.text,
                                  icon: Icons.badge,
                                  description: "Your complete name as it will appear to patients.",
                                  controller: fullNameController,
                                  fieldKey: "fullName",
                                ),
                                _buildFieldWithDescription(
                                  label: "Medical License",
                                  value: licenseController.text,
                                  icon: Icons.card_membership,
                                  description: "Your official medical license number.",
                                  controller: licenseController,
                                  fieldKey: "license",
                                ),
                                _buildFieldWithDescription(
                                  label: "Specialization",
                                  value: specializationController.text,
                                  icon: Icons.local_hospital,
                                  description: "Your area of medical expertise (e.g., Pulmonology, Pediatrics).",
                                  controller: specializationController,
                                  fieldKey: "specialization",
                                ),
                                _buildFieldWithDescription(
                                  label: "Experience",
                                  value: experienceController.text,
                                  icon: Icons.work_history,
                                  description: "Years of professional experience or a brief summary.",
                                  controller: experienceController,
                                  fieldKey: "experience",
                                ),
                                const Padding(
                                  padding: EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    "Note: Bio details will appear on your public profile and are visible to patients.",
                                    style: TextStyle(fontSize: 13, color: Colors.redAccent),
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
                                        children: (doctorData!['affiliations'] as List<dynamic>)
                                            .map((a) => _affiliationCard(a))
                                            .toList(),
                                      )
                                    : const Text(
                                        "No affiliations added",
                                        style: TextStyle(fontSize: 14, color: Colors.black54),
                                      ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                              ),
                              onPressed: _logout,
                              child: const Text("Log Out", style: TextStyle(color: Colors.white)),
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
  Widget _buildEditableField(String label, String value, {
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

  Future<void> _editField(String label, String currentValue, TextEditingController? controller, String fieldKey, bool obscure) async {
  final currentPasswordController = TextEditingController(text: '********');
  final newPasswordController = TextEditingController();
  bool newPasswordVisible = false;
  await showDialog(
    context: context,
    builder: (context) {
      if (label != "Password") {
        // Default dialog for other fields
        final editController = TextEditingController(text: currentValue);
        bool passwordVisible = false;
        return StatefulBuilder(
          builder: (context, setState) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
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
                        borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.redAccent, width: 2),
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
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        ),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          final newValue = editController.text.trim();
                          if (newValue.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('$label cannot be empty.')),
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
        // Password dialog
        return StatefulBuilder(
          builder: (context, setState) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
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
                        borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.redAccent, width: 2),
                      ),
                      fillColor: Colors.grey.shade50,
                      filled: true,
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: newPasswordController,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      labelStyle: const TextStyle(color: Colors.redAccent),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.redAccent, width: 2),
                      ),
                      fillColor: Colors.grey.shade50,
                      filled: true,
                      suffixIcon: IconButton(
                        icon: Icon(
                          newPasswordVisible ? Icons.visibility : Icons.visibility_off,
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
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        ),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          final newPassword = newPasswordController.text.trim();
                          if (newPassword.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('New password cannot be empty.')),
                            );
                            return;
                          }
                          final user = FirebaseAuth.instance.currentUser;
                          if (user != null) {
                            try {
                              await user.updatePassword(newPassword);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Password updated successfully!')),
                              );
                              Navigator.pop(context);
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
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
      }
    },
    barrierDismissible: false,
  );
}
}
