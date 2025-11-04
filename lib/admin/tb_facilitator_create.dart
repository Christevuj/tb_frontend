import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';

class TBFacilitatorCreatePage extends StatefulWidget {
  const TBFacilitatorCreatePage({super.key});

  @override
  State<TBFacilitatorCreatePage> createState() =>
      _TBFacilitatorCreatePageState();
}

class _TBFacilitatorCreatePageState extends State<TBFacilitatorCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isSubmitting = false;

  // Facility management
  Map<String, String> facilities = {};
  bool isLoadingFacilities = true;
  String? selectedFacility;
  String selectedFacilityAddress = '';

  @override
  void initState() {
    super.initState();
    _loadFacilities();
  }

  // Load facilities from Firebase
  Future<void> _loadFacilities() async {
    try {
      final facilitiesSnapshot =
          await FirebaseFirestore.instance.collection('facilities').get();

      Map<String, String> loadedFacilities = {};
      for (var doc in facilitiesSnapshot.docs) {
        final data = doc.data();
        loadedFacilities[data['name'] ?? doc.id] =
            data['address'] ?? 'Address not available';
      }

      // If no facilities found in Firebase, add some default TB DOTS facilities
      if (loadedFacilities.isEmpty) {
        loadedFacilities = {
          'AGDAO':
              'Agdao Public Market Corner Lapu-Lapu & C. Bangoy St., Agdao, Davao City',
          'BAGUIO': 'Baguio District Health Center, Davao City',
          'BUHANGIN (NHA BUHANGIN HC)': 'NHA Chapet St., Buhangin, Davao City',
          'BUNAWAN': 'Bunawan District Health Center, Davao City',
          'CALINAN': 'P34, Aurora St., Calinan, Davao City',
          'DAVAO CHEST CENTER': 'Villa Abrille St., Brgy 30-C, Davao City',
          'DISTRICT A (TOMAS CLAUDIO HC)':
              'Camus Ext., Corner Quirino Ave., Davao City',
          'DISTRICT B (EL RIO HC)': 'Garcia Heights, Bajada, Davao City',
          'DISTICT C (MINIFOREST HC)':
              'Brgy 23-C, Quezon Boulevard, Davao City',
          'DISTRICT D (JACINTO HC)': 'Emilio Jacinto St., Davao City',
          'MARILOG (MARAHAN HC)': 'Sitio Marahan, Brgy. Marilog, Davao City',
          'PAQUIBATO (MALABOG HC)': 'Brgy Malabog, Davao City',
          'SASA': 'Bangoy Km 9, Sasa, Davao City',
          'TALOMO CENTRAL (GSIS HC)': 'GSIS Village, Matina, Davao City',
          'TALOMO NORTH (SIR HC)':
              'Daang Patnubay St., SIR Ph-1, Sandawa, Davao City',
          'TALOMO SOUTH (PUAN HC)': 'Puan, Talomo, Davao City',
          'TORIL A': 'Agton St., Toril, Davao City',
          'TORIL B': 'Juan Dela Cruz St., Daliao, Toril, Davao City',
          'TUGBOK': 'Sampaguita St., Mintal, Tugbok District, Davao City',
        };

        // Seed these defaults into Firestore
        try {
          final batch = FirebaseFirestore.instance.batch();
          final col = FirebaseFirestore.instance.collection('facilities');
          loadedFacilities.forEach((name, address) {
            final docRef = col.doc();
            batch.set(docRef, {'name': name, 'address': address});
          });
          await batch.commit();
          debugPrint('Seeded default facilities into Firestore');
        } catch (e) {
          debugPrint('Error seeding facilities to Firestore: $e');
        }
      }

      if (mounted) {
        setState(() {
          facilities = loadedFacilities;
          isLoadingFacilities = false;
        });
      }
    } catch (e) {
      // Fallback to default TB DOTS facilities if Firebase fails
      if (mounted) {
        setState(() {
          isLoadingFacilities = false;
          facilities = {
            'AGDAO':
                'Agdao Public Market Corner Lapu-Lapu & C. Bangoy St., Agdao, Davao City',
            'BAGUIO': 'Baguio District Health Center, Davao City',
            'BUNAWAN': 'Bunawan District Health Center, Davao City',
            'CALINAN': 'P34, Aurora St., Calinan, Davao City',
            'DAVAO CHEST CENTER': 'Villa Abrille St., Brgy 30-C, Davao City',
            'DISTRICT A (TOMAS CLAUDIO HC)':
                'Camus Ext., Corner Quirino Ave., Davao City',
            'DISTRICT B (EL RIO HC)': 'Garcia Heights, Bajada, Davao City',
            'DISTICT C (MINIFOREST HC)':
                'Brgy 23-C, Quezon Boulevard, Davao City',
            'DISTRICT D (JACINTO HC)': 'Emilio Jacinto St., Davao City',
            'MARILOG (MARAHAN HC)': 'Sitio Marahan, Brgy. Marilog, Davao City',
            'PAQUIBATO (MALABOG HC)': 'Brgy Malabog, Davao City',
            'SASA': 'Bangoy Km 9, Sasa, Davao City',
            'TALOMO CENTRAL (GSIS HC)': 'GSIS Village, Matina, Davao City',
            'TALOMO NORTH (SIR HC)':
                'Daang Patnubay St., SIR Ph-1, Sandawa, Davao City',
            'TALOMO SOUTH (PUAN HC)': 'Puan, Talomo, Davao City',
          };
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _createFacilitator() async {
    if (_formKey.currentState?.validate() != true) return;

    setState(() => _isSubmitting = true);

    try {
      // Create TB Facilitator account in Firebase Auth
      final error = await _authService.createUserByAdmin(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        role: 'admin',
        name: _emailController.text.trim(),
      );

      if (error != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        // Also add to admins collection with facility information
        await FirebaseFirestore.instance.collection('admins').add({
          'email': _emailController.text.trim(),
          'role': 'admin',
          'facility': selectedFacility != null
              ? {
                  'name': selectedFacility,
                  'address': selectedFacilityAddress,
                }
              : null,
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('TB Facilitator account created successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context); // Return to super admin page
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFEF4444), // Red accent
              Color(0xFFFEE2E2), // Light red
              Color(0xFFFFFFFF), // White
              Color(0xFFDCEEFB), // Light blue
            ],
            stops: [0.0, 0.3, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Glassmorphism Header
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.95),
                      Colors.white.withOpacity(0.85),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Back button
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back,
                            color: Color(0xFFEF4444)),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Title
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Create TB Facilitator',
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1F2937),
                            ),
                          ),
                          Text(
                            'Add a new TB Facilitator account',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Medical icon
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEF4444), Color(0xFFF87171)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.admin_panel_settings,
                          color: Colors.white, size: 28),
                    ),
                  ],
                ),
              ),

              // Form Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Account Security Card
                        _buildModernCard(
                          title: 'Account Information',
                          icon: Icons.security,
                          gradientColors: const [
                            Color(0xFF8B5CF6),
                            Color(0xFFA78BFA)
                          ],
                          child: Column(
                            children: [
                              // Email
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  labelText: 'Email Address',
                                  hintText: 'facilitator@example.com',
                                  prefixIcon: const Icon(Icons.email_outlined,
                                      color: Color(0xFF8B5CF6)),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide:
                                        BorderSide(color: Colors.grey.shade200),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: Color(0xFF8B5CF6), width: 2),
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Email is required';
                                  }
                                  if (!v.contains('@')) {
                                    return 'Invalid email format';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Password
                              TextFormField(
                                controller: _passwordController,
                                obscureText: !_isPasswordVisible,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  hintText: 'Minimum 6 characters',
                                  prefixIcon: const Icon(Icons.lock_outline,
                                      color: Color(0xFF8B5CF6)),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _isPasswordVisible
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      color: Colors.grey,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _isPasswordVisible =
                                            !_isPasswordVisible;
                                      });
                                    },
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide:
                                        BorderSide(color: Colors.grey.shade200),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: Color(0xFF8B5CF6), width: 2),
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Password is required';
                                  }
                                  if (v.length < 6) {
                                    return 'Password must be at least 6 characters';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Confirm Password
                              TextFormField(
                                controller: _confirmPasswordController,
                                obscureText: !_isConfirmPasswordVisible,
                                decoration: InputDecoration(
                                  labelText: 'Confirm Password',
                                  hintText: 'Re-enter your password',
                                  prefixIcon: const Icon(
                                      Icons.lock_outline_rounded,
                                      color: Color(0xFF8B5CF6)),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _isConfirmPasswordVisible
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      color: Colors.grey,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _isConfirmPasswordVisible =
                                            !_isConfirmPasswordVisible;
                                      });
                                    },
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide:
                                        BorderSide(color: Colors.grey.shade200),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: Color(0xFF8B5CF6), width: 2),
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Please confirm your password';
                                  }
                                  if (v != _passwordController.text) {
                                    return 'Passwords do not match';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Facility Selection Card
                        _buildModernCard(
                          title: 'Health Center Assignment',
                          icon: Icons.local_hospital,
                          gradientColors: const [
                            Color(0xFF10B981),
                            Color(0xFF34D399)
                          ],
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (isLoadingFacilities)
                                const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(20.0),
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                              else
                                DropdownButtonFormField<String>(
                                  value: selectedFacility,
                                  decoration: InputDecoration(
                                    labelText: 'Select Health Center',
                                    hintText: 'Choose a TB DOTS facility',
                                    prefixIcon: const Icon(
                                        Icons.business_outlined,
                                        color: Color(0xFF10B981)),
                                    filled: true,
                                    fillColor: Colors.grey.shade50,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                          color: Colors.grey.shade200),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: Color(0xFF10B981), width: 2),
                                    ),
                                  ),
                                  items: facilities.keys.map((String facility) {
                                    return DropdownMenuItem<String>(
                                      value: facility,
                                      child: Text(
                                        facility,
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (String? newValue) {
                                    setState(() {
                                      selectedFacility = newValue;
                                      selectedFacilityAddress =
                                          facilities[newValue] ?? '';
                                    });
                                  },
                                  validator: (v) {
                                    if (v == null || v.isEmpty) {
                                      return 'Please select a health center';
                                    }
                                    return null;
                                  },
                                ),
                              if (selectedFacilityAddress.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFF10B981)
                                          .withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.location_on,
                                        color: Color(0xFF10B981),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          selectedFacilityAddress,
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            color: const Color(0xFF374151),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Create Button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed:
                                _isSubmitting ? null : _createFacilitator,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEF4444),
                              foregroundColor: Colors.white,
                              elevation: 8,
                              shadowColor:
                                  const Color(0xFFEF4444).withOpacity(0.4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Create TB Facilitator Account',
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.arrow_forward_rounded),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
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

  Widget _buildModernCard({
    required String title,
    required IconData icon,
    required List<Color> gradientColors,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: gradientColors),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}
