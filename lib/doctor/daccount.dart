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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          "Doctor Profile",
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600, color: Colors.redAccent),
        ),
        iconTheme: const IconThemeData(color: Colors.redAccent),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            color: Colors.redAccent,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : doctorData == null
              ? const Center(child: Text("No doctor data found"))
              : ListView(
                  padding: const EdgeInsets.all(14.0),
                  children: [
                    // Circular profile image
                    Center(
                      child: _buildCircularImage(
                          url: doctorData!['profileImageUrl']),
                    ),
                    const SizedBox(height: 20),
                    _infoCard(Icons.person, "Username", usernameController),
                    _infoCard(Icons.email, "Email",
                        TextEditingController(text: doctorData!['email'] ?? ""),
                        readOnly: true),
                    _infoCard(Icons.lock, "Password", passwordController,
                        isPassword: true),
                    _infoCard(Icons.badge, "Full Name", fullNameController),
                    _infoCard(Icons.card_membership, "Medical License",
                        licenseController),
                    _infoCard(Icons.local_hospital, "Specialization",
                        specializationController),
                    _infoCard(
                        Icons.work_history, "Experience", experienceController),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.business, color: Colors.redAccent),
                        const SizedBox(width: 8),
                        Text(
                          "Affiliations",
                          style: GoogleFonts.poppins(
                              fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    doctorData!['affiliations'] != null
                        ? Column(
                            children:
                                (doctorData!['affiliations'] as List<dynamic>)
                                    .map((a) => _affiliationCard(a))
                                    .toList(),
                          )
                        : Text(
                            "No affiliations added",
                            style: GoogleFonts.poppins(
                                fontSize: 14, color: Colors.black54),
                          ),
                    const SizedBox(height: 16),
                  ],
                ),
    );
  }
}
