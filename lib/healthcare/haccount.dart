import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../login_screen.dart';

class HAccount extends StatefulWidget {
  const HAccount({super.key});

  @override
  State<HAccount> createState() => _HAccountState();
}

class _HAccountState extends State<HAccount> {
  final _formKey = GlobalKey<FormState>();
  bool _isEditing = false;
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  String? _currentPassword;
  String? _newPassword;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _licenseController = TextEditingController();
  final TextEditingController _positionController = TextEditingController();
  final TextEditingController _contactNumberController =
      TextEditingController();
  Map<String, dynamic>? _facility;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _licenseController.dispose();
    _positionController.dispose();
    _contactNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      setState(() => _isLoading = true);
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('healthcare')
            .doc(user.uid)
            .get();

        if (doc.exists) {
          final data = doc.data();
          _nameController.text = data?['fullName'] ?? '';
          _emailController.text = data?['email'] ?? '';
          _licenseController.text = data?['licenseNumber'] ?? '';
          _positionController.text = data?['position'] ?? '';
          _contactNumberController.text = data?['contactNumber'] ?? '';

          // Load facility data
          if (data?['facility'] != null) {
            if (data!['facility'] is Map) {
              _facility = Map<String, dynamic>.from(data['facility']);
            } else if (data['facility'] is String) {
              // If facility is a reference ID, fetch the facility document
              final facilityDoc = await FirebaseFirestore.instance
                  .collection('facilities')
                  .doc(data['facility'])
                  .get();
              if (facilityDoc.exists) {
                _facility = facilityDoc.data();
              }
            }
          }
          setState(() {});
        }
      }
    } catch (e) {
      _showErrorSnackbar('Error loading user data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _handleLogout() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const TBisitaLoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      _showErrorSnackbar('Error logging out: $e');
    }
  }

  Widget _buildInfoCard({
    required String title,
    required String value,
    required IconData icon,
    bool isEditable = true,
    VoidCallback? onEdit,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Colors.redAccent),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        subtitle: Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: isEditable
            ? IconButton(
                icon: const Icon(Icons.edit, color: Colors.redAccent),
                onPressed: onEdit,
              )
            : null,
      ),
    );
  }

  // Track which field is being edited
  String? _editingField;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My Profile',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.redAccent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Personal Information',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.redAccent,
                ),
              ),
              const SizedBox(height: 16),
              if (_editingField == 'name')
                Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => setState(() => _editingField = null),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            if (_formKey.currentState!.validate()) {
                              final user = FirebaseAuth.instance.currentUser;
                              if (user != null) {
                                await FirebaseFirestore.instance
                                    .collection('healthcare')
                                    .doc(user.uid)
                                    .update({
                                  'fullName': _nameController.text.trim()
                                });
                                if (mounted) {
                                  setState(() => _editingField = null);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content:
                                            Text('Name updated successfully')),
                                  );
                                }
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent),
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  ],
                )
              else
                _buildInfoCard(
                  title: 'Full Name',
                  value: _nameController.text,
                  icon: Icons.person,
                  onEdit: () => setState(() => _editingField = 'name'),
                ),
              // Email field is not editable
              _buildInfoCard(
                title: 'Email',
                value: _emailController.text,
                icon: Icons.email,
                isEditable: false,
              ),
              if (_editingField == 'password')
                Column(
                  children: [
                    TextFormField(
                      obscureText: !_isPasswordVisible,
                      decoration: InputDecoration(
                        labelText: 'Current Password',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () => setState(
                              () => _isPasswordVisible = !_isPasswordVisible),
                        ),
                      ),
                      onChanged: (value) => _currentPassword = value,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      obscureText: !_isPasswordVisible,
                      decoration: const InputDecoration(
                        labelText: 'New Password',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) => _newPassword = value,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => setState(() => _editingField = null),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            if (_currentPassword != null &&
                                _newPassword != null) {
                              final user = FirebaseAuth.instance.currentUser;
                              if (user != null && user.email != null) {
                                try {
                                  final credential =
                                      EmailAuthProvider.credential(
                                    email: user.email!,
                                    password: _currentPassword!,
                                  );
                                  await user
                                      .reauthenticateWithCredential(credential);
                                  await user.updatePassword(_newPassword!);
                                  if (mounted) {
                                    setState(() => _editingField = null);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Password updated successfully')),
                                    );
                                  }
                                } catch (e) {
                                  _showErrorSnackbar(
                                      'Current password is incorrect');
                                }
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent),
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  ],
                )
              else
                _buildInfoCard(
                  title: 'Password',
                  value: '••••••••',
                  icon: Icons.lock,
                  onEdit: () => setState(() => _editingField = 'password'),
                ),
              _buildInfoCard(
                title: 'Role',
                value: 'Healthcare Worker',
                icon: Icons.work,
                isEditable: false,
              ),
              if (_isEditing) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        obscureText: !_isPasswordVisible,
                        decoration: InputDecoration(
                          labelText: 'Current Password',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() =>
                                  _isPasswordVisible = !_isPasswordVisible);
                            },
                          ),
                        ),
                        onChanged: (value) => _currentPassword = value,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  obscureText: !_isPasswordVisible,
                  decoration: const InputDecoration(
                    labelText: 'New Password',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => _newPassword = value,
                ),
              ],
              const SizedBox(height: 24),
              Text(
                'Professional Information',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.redAccent,
                ),
              ),
              const SizedBox(height: 16),
              if (_editingField == 'license')
                Column(
                  children: [
                    TextFormField(
                      controller: _licenseController,
                      decoration: const InputDecoration(
                        labelText: 'License Number',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your license number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => setState(() => _editingField = null),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            if (_formKey.currentState!.validate()) {
                              final user = FirebaseAuth.instance.currentUser;
                              if (user != null) {
                                await FirebaseFirestore.instance
                                    .collection('healthcare')
                                    .doc(user.uid)
                                    .update({
                                  'licenseNumber':
                                      _licenseController.text.trim()
                                });
                                if (mounted) {
                                  setState(() => _editingField = null);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'License number updated successfully')),
                                  );
                                }
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent),
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  ],
                )
              else
                _buildInfoCard(
                  title: 'License Number',
                  value: _licenseController.text,
                  icon: Icons.badge,
                  onEdit: () => setState(() => _editingField = 'license'),
                ),
              if (_editingField == 'position')
                Column(
                  children: [
                    TextFormField(
                      controller: _positionController,
                      decoration: const InputDecoration(
                        labelText: 'Position',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your position';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => setState(() => _editingField = null),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            if (_formKey.currentState!.validate()) {
                              final user = FirebaseAuth.instance.currentUser;
                              if (user != null) {
                                await FirebaseFirestore.instance
                                    .collection('healthcare')
                                    .doc(user.uid)
                                    .update({
                                  'position': _positionController.text.trim()
                                });
                                if (mounted) {
                                  setState(() => _editingField = null);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Position updated successfully')),
                                  );
                                }
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent),
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  ],
                )
              else
                _buildInfoCard(
                  title: 'Position',
                  value: _positionController.text,
                  icon: Icons.work,
                  onEdit: () => setState(() => _editingField = 'position'),
                ),
              if (_editingField == 'contact')
                Column(
                  children: [
                    TextFormField(
                      controller: _contactNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Contact Number',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your contact number';
                        }
                        return null;
                      },
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => setState(() => _editingField = null),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            if (_formKey.currentState!.validate()) {
                              final user = FirebaseAuth.instance.currentUser;
                              if (user != null) {
                                await FirebaseFirestore.instance
                                    .collection('healthcare')
                                    .doc(user.uid)
                                    .update({
                                  'contactNumber':
                                      _contactNumberController.text.trim()
                                });
                                if (mounted) {
                                  setState(() => _editingField = null);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Contact number updated successfully')),
                                  );
                                }
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent),
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  ],
                )
              else
                _buildInfoCard(
                  title: 'Contact Number',
                  value: _contactNumberController.text,
                  icon: Icons.phone,
                  onEdit: () => setState(() => _editingField = 'contact'),
                ),
              const SizedBox(height: 24),
              Text(
                'Workplace Information',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.redAccent,
                ),
              ),
              const SizedBox(height: 16),
              _buildInfoCard(
                title: 'TB DOTS Facility',
                value: _facility?['name'] ?? 'Not specified',
                icon: Icons.local_hospital,
                isEditable: false,
              ),
              _buildInfoCard(
                title: 'Facility Address',
                value: _facility?['address'] ?? 'Not specified',
                icon: Icons.location_on,
                isEditable: false,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: _handleLogout,
                  icon: const Icon(Icons.logout, color: Colors.white),
                  label: Text(
                    'Logout',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
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
}
