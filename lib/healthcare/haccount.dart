import 'package:flutter/material.dart';
import 'package:tb_frontend/login_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;


class HAccount extends StatefulWidget {
  const HAccount({super.key});

  @override
  State<HAccount> createState() => _HAccountState();
}

class _HAccountState extends State<HAccount> {
  // Removed unused AuthService field

  String? firstName;
  String? lastName;
  String? email;
  String? licenseNumber;
  String? position;
  String? contactNumber;
  String? facilityName;
  String? facilityAddress;
  bool isLoading = true;

  final Set<String> expandedSections = {};

  @override
  void initState() {
    super.initState();
    _loadHealthWorkerDetails();
  }

  Future<void> _loadHealthWorkerDetails() async {
    final firebase_auth.User? authUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (authUser == null) return;
    final doc = await FirebaseFirestore.instance.collection('healthcare').doc(authUser.uid).get();
    final data = doc.data();
    if (mounted) {
      setState(() {
        firstName = data?['firstName'] ?? '';
        lastName = data?['lastName'] ?? '';
        email = data?['email'] ?? authUser.email ?? '';
        licenseNumber = data?['licenseNumber'] ?? '';
        position = data?['position'] ?? '';
        contactNumber = data?['contactNumber'] ?? '';
        facilityName = data?['facilityName'] ?? '';
        facilityAddress = data?['facilityAddress'] ?? '';
        isLoading = false;
      });
    }
  }

  bool get isGuest => firstName == null || lastName == null || email == null;

  void _toggleSection(String sectionId) {
    setState(() {
      if (expandedSections.contains(sectionId)) {
        expandedSections.remove(sectionId);
      } else {
        expandedSections.add(sectionId);
      }
    });
  }

  Future<void> _editField(String label, String currentValue, Function(String) onSave) async {
    final controller = TextEditingController(text: currentValue);
    final firebase_auth.User? authUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (authUser == null) return;

    await showDialog(
      context: context,
      builder: (context) {
        return Dialog(
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
                    Icon(Icons.edit, color: Colors.redAccent, size: 28),
                    const SizedBox(width: 10),
                    Text(
                      'Edit $label',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: controller,
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
                      style: TextButton.styleFrom(foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10)),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: () async {
                        final newValue = controller.text.trim();
                        if (newValue.isNotEmpty) {
                          await FirebaseFirestore.instance.collection('healthcare').doc(authUser.uid).update({
                            label == 'First Name' ? 'firstName' : label == 'Last Name' ? 'lastName' : label == 'License Number' ? 'licenseNumber' : label == 'Position' ? 'position' : label == 'Contact Number' ? 'contactNumber' : label == 'Facility Name' ? 'facilityName' : label == 'Facility Address' ? 'facilityAddress' : label.toLowerCase(): newValue
                          });
                          onSave(newValue);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label updated successfully!')));
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label cannot be empty.')));
                        }
                      },
                      child: const Text('Save'),
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

  Future<void> _removeAccount() async {
    final firebase_auth.User? authUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (authUser == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Account'),
        content: const Text('Are you sure you want to remove your account? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final email = authUser.email;
      if (email != null) {
        final passwordController = TextEditingController();
        final shouldProceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirm Password'),
            content: TextField(controller: passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'Enter your password')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
            ],
          ),
        );
        if (shouldProceed != true) return;
        final credential = firebase_auth.EmailAuthProvider.credential(email: email, password: passwordController.text.trim());
        await authUser.reauthenticateWithCredential(credential);
      }
      await FirebaseFirestore.instance.collection('healthcare').doc(authUser.uid).delete();
      await authUser.delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account successfully removed.')));
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const TBisitaLoginScreen()), (route) => false);
      }
    } on firebase_auth.FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.message}')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unexpected error: $e')));
    }
  }

  Future<void> _logout() async {
    await firebase_auth.FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const TBisitaLoginScreen()), (route) => false);
    }
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
        gradient: LinearGradient(colors: [Colors.white, Colors.grey.shade50], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.redAccent.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 6)),
        ],
      ),
      child: ExpansionTile(
        initiallyExpanded: isExpanded,
        onExpansionChanged: (_) => _toggleSection(sectionId),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(alignment: Alignment.center, height: 48, child: Icon(icon, color: Colors.redAccent, size: 28)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 2),
                  Text(description, style: const TextStyle(fontSize: 13, color: Colors.black54)),
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

  Widget _buildEditableField(String label, String value, {IconData? icon, VoidCallback? onEdit, bool obscure = false}) {
    return GestureDetector(
      onTap: onEdit,
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
            Expanded(child: Text(obscure ? "********" : value, style: const TextStyle(fontSize: 15))),
            if (onEdit != null) const Icon(Icons.edit, size: 18, color: Colors.redAccent),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [Color.fromARGB(255, 255, 255, 255), Color(0xFFFFEBEB)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  ),
                ),
                SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.redAccent,
                          child: isGuest
                              ? const Icon(Icons.person, size: 60, color: Colors.white)
                              : Text(
                                  firstName!.isNotEmpty ? firstName![0].toUpperCase() : "?",
                                  style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                        ),
                        const SizedBox(height: 16),
                        if (!isGuest)
                          Text("$firstName $lastName", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        if (!isGuest)
                          Text(email ?? "", style: const TextStyle(color: Colors.black54)),
                        if (isGuest)
                          const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: Text("You are currently using a guest account.\nPlease sign up to unlock full features.", textAlign: TextAlign.center, style: TextStyle(fontSize: 14)),
                          ),
                        const SizedBox(height: 20),
                        if (!isGuest) ...[
                          _buildSection(
                            title: "Personal Details",
                            description: "Manage your basic information and profile settings",
                            icon: Icons.person,
                            sectionId: "personal",
                            children: [
                              _buildEditableField("First Name", firstName ?? "", icon: Icons.person, onEdit: () {
                                _editField("First Name", firstName ?? "", (val) {
                                  setState(() => firstName = val);
                                });
                              }),
                              _buildEditableField("Last Name", lastName ?? "", icon: Icons.person_outline, onEdit: () {
                                _editField("Last Name", lastName ?? "", (val) {
                                  setState(() => lastName = val);
                                });
                              }),
                              _buildEditableField("Email", email ?? "", icon: Icons.email),
                            ],
                          ),
                          _buildSection(
                            title: "Professional Details",
                            description: "Manage your professional information",
                            icon: Icons.badge,
                            sectionId: "professional",
                            children: [
                              _buildEditableField("License Number", licenseNumber ?? "", icon: Icons.badge, onEdit: () {
                                _editField("License Number", licenseNumber ?? "", (val) {
                                  setState(() => licenseNumber = val);
                                });
                              }),
                              _buildEditableField("Position", position ?? "", icon: Icons.work, onEdit: () {
                                _editField("Position", position ?? "", (val) {
                                  setState(() => position = val);
                                });
                              }),
                              _buildEditableField("Contact Number", contactNumber ?? "", icon: Icons.phone, onEdit: () {
                                _editField("Contact Number", contactNumber ?? "", (val) {
                                  setState(() => contactNumber = val);
                                });
                              }),
                            ],
                          ),
                          _buildSection(
                            title: "Workplace Information",
                            description: "Your assigned facility",
                            icon: Icons.local_hospital,
                            sectionId: "facility",
                            children: [
                              _buildEditableField("Facility Name", facilityName ?? "", icon: Icons.local_hospital, onEdit: () {
                                _editField("Facility Name", facilityName ?? "", (val) {
                                  setState(() => facilityName = val);
                                });
                              }),
                              _buildEditableField("Facility Address", facilityAddress ?? "", icon: Icons.location_on, onEdit: () {
                                _editField("Facility Address", facilityAddress ?? "", (val) {
                                  setState(() => facilityAddress = val);
                                });
                              }),
                            ],
                          ),
                          _buildSection(
                            title: "Security & Privacy",
                            description: "Manage your password and account security settings",
                            icon: Icons.lock,
                            sectionId: "security",
                            children: [
                              _buildEditableField("Password", "********", icon: Icons.lock, obscure: true, onEdit: () {
                                // You can implement password change dialog here similar to Paccount
                              }),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [Colors.redAccent.withOpacity(0.1), Colors.white]),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: const [
                                    Icon(Icons.shield, color: Colors.redAccent),
                                    SizedBox(width: 8),
                                    Expanded(child: Text("Your account is secured. Last login: Today at 2:34 PM", style: TextStyle(fontSize: 13))),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          _buildSection(
                            title: "Account Action",
                            description: "Manage your account preferences and data",
                            icon: Icons.settings,
                            sectionId: "actions",
                            children: [
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24), side: const BorderSide(color: Colors.redAccent, width: 2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                                onPressed: _removeAccount,
                                child: const Text("Remove Account", style: TextStyle(color: Colors.redAccent)),
                              ),
                            ],
                          ),
                        ],
                        if (!isGuest) ...[
                          const SizedBox(height: 24),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                            onPressed: _logout,
                            child: const Text("Log Out", style: TextStyle(color: Colors.white)),
                          ),
                        ],
                        if (isGuest)
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const TBisitaLoginScreen()));
                            },
                            child: const Text("Sign Up", style: TextStyle(color: Colors.white)),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
