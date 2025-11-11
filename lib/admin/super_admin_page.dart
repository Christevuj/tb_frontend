import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tb_frontend/services/auth_service.dart';
import './admin_login.dart' show AdminLogin;
import './tb_facilitator_create.dart';

enum SuperAdminTab {
  dashboard,
  facilitators,
}

class SuperAdminPage extends StatefulWidget {
  const SuperAdminPage({super.key});

  @override
  State<SuperAdminPage> createState() => _SuperAdminPageState();
}

class _SuperAdminPageState extends State<SuperAdminPage> {
  SuperAdminTab _selectedTab = SuperAdminTab.dashboard;
  final AuthService _authService = AuthService();
  Map<String, String> _facilities = {};
  bool _isLoadingFacilities = true;
  String? _selectedFacility;
  String?
      _selectedView; // 'doctors', 'patients', 'healthworkers', or null for all
  
  // Cache for patient locations to avoid repeated queries
  final Map<String, String> _patientLocationCache = {};

  @override
  void initState() {
    super.initState();
    _loadFacilities();
  }

  Future<void> _loadFacilities() async {
    try {
      final facilitiesSnapshot =
          await FirebaseFirestore.instance.collection('facilities').get();
      final Map<String, String> loaded = {};
      for (var doc in facilitiesSnapshot.docs) {
        final data = doc.data();
        loaded[data['name'] ?? doc.id] =
            data['address'] ?? 'Address not available';
      }
      if (mounted) setState(() => _facilities = loaded);
    } catch (e) {
      // ignore errors here; dropdown will show empty
      print('Error loading facilities: $e');
    } finally {
      if (mounted) setState(() => _isLoadingFacilities = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 800;

        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          appBar: isMobile ? _buildMobileAppBar() : null,
          drawer: isMobile ? _buildMobileDrawer() : null,
          body: isMobile ? _buildMobileLayout() : _buildDesktopLayout(),
        );
      },
    );
  }

  AppBar _buildMobileAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black.withOpacity(0.05),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.admin_panel_settings_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            'Super Admin Dashboard',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1F2937),
              fontSize: 18,
            ),
          ),
        ],
      ),
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.menu_rounded, color: Color(0xFF1F2937)),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
    );
  }

  Widget _buildMobileDrawer() {
    return Drawer(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1F2937), Color(0xFF111827)],
          ),
        ),
        child: Column(
          children: [
            DrawerHeader(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.shield_rounded,
                      size: 50,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Super Admin Panel',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildMobileMenuItem(
                      icon: Icons.dashboard_rounded,
                      label: "Dashboard",
                      tab: SuperAdminTab.dashboard),
                  _buildMobileMenuItem(
                      icon: Icons.people_rounded,
                      label: "TB Facilitators",
                      tab: SuperAdminTab.facilitators),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEF4444).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TBFacilitatorCreatePage(),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 16.0, horizontal: 20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_circle_rounded,
                            color: Colors.white, size: 24),
                        const SizedBox(width: 12),
                        Text(
                          'Create TB Facilitator',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: InkWell(
                onTap: () async {
                  await _authService.signOut();
                  if (mounted) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                          builder: (context) => const AdminLogin()),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      vertical: 14.0, horizontal: 20.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.logout_rounded,
                          color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        'Logout',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileMenuItem(
      {required IconData icon,
      required String label,
      required SuperAdminTab tab}) {
    final isSelected = _selectedTab == tab;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon,
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.7)),
        title: Text(
          label,
          style: GoogleFonts.poppins(
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        onTap: () {
          setState(() => _selectedTab = tab);
          Navigator.pop(context);
        },
      ),
    );
  }

  Widget _buildMobileLayout() {
    switch (_selectedTab) {
      case SuperAdminTab.dashboard:
        return _buildDashboardView();
      case SuperAdminTab.facilitators:
        return const FacilitatorsView();
    }
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        _buildDesktopSidebar(),
        Expanded(
          child: _buildMobileLayout(),
        ),
      ],
    );
  }

  Widget _buildDesktopSidebar() {
    return Container(
      width: 280,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1F2937), Color(0xFF111827)],
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.shield_rounded,
              size: 60,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Super Admin Panel',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 40),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildDesktopMenuItem(
                    icon: Icons.dashboard_rounded,
                    label: "Dashboard",
                    tab: SuperAdminTab.dashboard),
                _buildDesktopMenuItem(
                    icon: Icons.people_rounded,
                    label: "TB Facilitators",
                    tab: SuperAdminTab.facilitators),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFEF4444).withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TBFacilitatorCreatePage(),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 16.0, horizontal: 20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_circle_rounded,
                          color: Colors.white, size: 24),
                      const SizedBox(width: 12),
                      Text(
                        'Create TB Facilitator',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: InkWell(
              onTap: () async {
                await _authService.signOut();
                if (mounted) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => const AdminLogin()),
                  );
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    vertical: 14.0, horizontal: 20.0),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.logout_rounded,
                        color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      'Logout',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopMenuItem(
      {required IconData icon,
      required String label,
      required SuperAdminTab tab}) {
    final isSelected = _selectedTab == tab;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon,
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.7)),
        title: Text(
          label,
          style: GoogleFonts.poppins(
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        onTap: () {
          setState(() => _selectedTab = tab);
        },
      ),
    );
  }

  Widget _buildDashboardView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dashboard Overview',
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 24),

          // Overview stats - clickable containers
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('admins').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final facilitatorCount = snapshot.data!.docs.length;

              return GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 2,
                children: [
                  _buildStatCard(
                    icon: Icons.people_rounded,
                    title: 'Total TB Facilitators',
                    value: facilitatorCount.toString(),
                    color: const Color(0xFFEF4444),
                  ),
                  _buildStatCard(
                    icon: Icons.shield_rounded,
                    title: 'Super Admins',
                    value: '1',
                    color: const Color(0xFF10B981),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 16),

          // Clickable view cards
          Row(
            children: [
              Expanded(
                child: _buildViewCard(
                  icon: Icons.local_hospital_rounded,
                  title: 'Doctors',
                  viewKey: 'doctors',
                  color: const Color(0xFF3B82F6),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildViewCard(
                  icon: Icons.personal_injury_rounded,
                  title: 'Patients',
                  viewKey: 'patients',
                  color: const Color(0xFF8B5CF6),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildViewCard(
                  icon: Icons.medical_services_rounded,
                  title: 'Health Workers',
                  viewKey: 'healthworkers',
                  color: const Color(0xFF10B981),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Facility filter
          Row(
            children: [
              const Icon(Icons.filter_list, color: Color(0xFF6B7280)),
              const SizedBox(width: 8),
              Expanded(
                child: _isLoadingFacilities
                    ? const LinearProgressIndicator()
                    : DropdownButtonFormField<String>(
                        value: _selectedFacility,
                        decoration: const InputDecoration(
                          labelText: 'Filter by Health Center',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                              value: null, child: Text('All locations')),
                          ..._facilities.keys.map((f) => DropdownMenuItem(
                                value: f,
                                child: Text(f),
                              ))
                        ],
                        onChanged: (v) {
                          setState(() => _selectedFacility = v);
                        },
                      ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Conditional table display based on selected view
          if (_selectedView == null || _selectedView == 'doctors') ...[
            Text('Doctors',
                style: GoogleFonts.poppins(
                    fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            _buildDoctorsTable(filteredFacility: _selectedFacility),
            const SizedBox(height: 20),
          ],

          if (_selectedView == null || _selectedView == 'patients') ...[
            Text('Patients',
                style: GoogleFonts.poppins(
                    fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            _buildPatientsTable(filteredFacility: _selectedFacility),
            const SizedBox(height: 20),
          ],

          if (_selectedView == null || _selectedView == 'healthworkers') ...[
            Text('Health Workers',
                style: GoogleFonts.poppins(
                    fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            _buildHealthWorkersTable(filteredFacility: _selectedFacility),
          ],
        ],
      ),
    );
  }

  // Build doctors table filtered by facility name
  Widget _buildDoctorsTable({String? filteredFacility}) {
    final query = FirebaseFirestore.instance.collection('doctors').limit(500);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs.where((doc) {
          if (filteredFacility == null || filteredFacility.isEmpty) return true;
          final data = doc.data() as Map<String, dynamic>;
          final affiliations = data['affiliations'] as List<dynamic>?;
          if (affiliations == null || affiliations.isEmpty) return false;
          return affiliations.any((a) {
            final name =
                a['name'] ?? a['facilityName'] ?? a['facility']?['name'];
            return name == filteredFacility;
          });
        }).toList();

        if (docs.isEmpty) return const Center(child: Text('No doctors found'));

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: [
              DataColumn(
                  label: Text('Name',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700))),
              DataColumn(
                  label: Text('Specialization',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700))),
              DataColumn(
                  label: Text('Location',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700))),
              DataColumn(
                  label: Text('Email',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700))),
            ],
            rows: docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;

              // Extract location from affiliations
              String location = 'N/A';
              final affiliations = data['affiliations'] as List<dynamic>?;
              if (affiliations != null && affiliations.isNotEmpty) {
                final firstAffiliation = affiliations[0];
                location = firstAffiliation['name'] ??
                    firstAffiliation['facilityName'] ??
                    firstAffiliation['facility']?['name'] ??
                    'N/A';
                // If multiple affiliations, show count
                if (affiliations.length > 1) {
                  location = '$location (+${affiliations.length - 1})';
                }
              }

              return DataRow(cells: [
                DataCell(Text(data['fullName'] ?? data['name'] ?? 'N/A')),
                DataCell(Text(data['specialization'] ?? 'N/A')),
                DataCell(Text(location)),
                DataCell(Text(data['email'] ?? 'N/A')),
              ]);
            }).toList(),
          ),
        );
      },
    );
  }

  // Build patients table filtered by facility (patient.facility.name)
  Widget _buildPatientsTable({String? filteredFacility}) {
    final query = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'patient')
        .limit(500);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());

        // Get all patient docs first (no filtering yet)
        final allDocs = snapshot.data!.docs;

        if (allDocs.isEmpty)
          return const Center(child: Text('No patients found'));

        // If no filter, show all patients
        if (filteredFacility == null || filteredFacility.isEmpty) {
          return _buildPatientDataTable(allDocs);
        }

        // If filter selected, we need to filter by doctor's location
        return FutureBuilder<List<DocumentSnapshot>>(
          future: _filterPatientsByDoctorLocation(allDocs, filteredFacility),
          builder: (context, filteredSnapshot) {
            if (filteredSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final filteredDocs = filteredSnapshot.data ?? [];

            if (filteredDocs.isEmpty) {
              return const Center(
                  child: Text('No patients found for this location'));
            }

            return _buildPatientDataTable(filteredDocs);
          },
        );
      },
    );
  }

  // Filter patients by their approved doctor's location
  Future<List<DocumentSnapshot>> _filterPatientsByDoctorLocation(
      List<DocumentSnapshot> patients, String facilityName) async {
    
    print('🔍 Filtering ${patients.length} patients for location: $facilityName');
    
    // Fetch all locations in parallel for better performance
    final locationFutures = patients.map((patient) => 
      _getPatientLocationFromDoctor(patient.id)
    ).toList();
    
    final locations = await Future.wait(locationFutures);
    
    // Filter patients whose location matches
    List<DocumentSnapshot> filtered = [];
    for (int i = 0; i < patients.length; i++) {
      if (locations[i] == facilityName) {
        filtered.add(patients[i]);
      }
    }

    print('✅ Filtered ${filtered.length} patients for location: $facilityName');
    return filtered;
  }

  // Build the actual DataTable widget
  Widget _buildPatientDataTable(List<DocumentSnapshot> docs) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          DataColumn(
              label: Text('Name',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700))),
          DataColumn(
              label: Text('Email',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700))),
          DataColumn(
              label: Text('Location',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700))),
          DataColumn(
              label: Text('Status',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700))),
        ],
        rows: docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['firstName'] != null && data['lastName'] != null)
              ? '${data['firstName']} ${data['lastName']}'
              : (data['name'] ?? 'N/A');

          return DataRow(cells: [
            DataCell(Text(name)),
            DataCell(Text(data['email'] ?? 'N/A')),
            DataCell(FutureBuilder<String>(
              future: _getPatientLocationFromDoctor(doc.id),
              builder: (context, locSnapshot) {
                if (locSnapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                }
                return Text(locSnapshot.data ?? 'N/A');
              },
            )),
            DataCell(Text(data['status'] ?? 'Pending')),
          ]);
        }).toList(),
      ),
    );
  }

  // Get patient location based on approved doctor's affiliation
  Future<String> _getPatientLocationFromDoctor(String patientId) async {
    // Check cache first
    if (_patientLocationCache.containsKey(patientId)) {
      print('💾 Using cached location for patient: $patientId');
      return _patientLocationCache[patientId]!;
    }

    try {
      print('🔍 Fetching location for patient: $patientId');

      // Find approved appointment for this patient
      // Try both patientUid and patientId as field names
      var appointmentsSnapshot = await FirebaseFirestore.instance
          .collection('approved_appointments')
          .where('patientUid', isEqualTo: patientId)
          .limit(1)
          .get();

      // Fallback to patientId if patientUid query returns nothing
      if (appointmentsSnapshot.docs.isEmpty) {
        print('🔄 Trying with patientId field...');
        appointmentsSnapshot = await FirebaseFirestore.instance
            .collection('approved_appointments')
            .where('patientId', isEqualTo: patientId)
            .limit(1)
            .get();
      }

      if (appointmentsSnapshot.docs.isEmpty) {
        print('❌ No approved appointments found for patient: $patientId');
        final result = 'No Approved Doctor';
        _patientLocationCache[patientId] = result; // Cache the result
        return result;
      }

      final appointment = appointmentsSnapshot.docs.first.data();
      print('📋 Found appointment: ${appointment.keys.join(", ")}');

      final doctorId = appointment['doctorId'] ?? appointment['doctorUid'];

      if (doctorId == null) {
        print('❌ No doctorId in appointment for patient: $patientId');
        final result = 'No Doctor Assigned';
        _patientLocationCache[patientId] = result; // Cache the result
        return result;
      }

      print('👨‍⚕️ Found approved doctor: $doctorId for patient: $patientId');

      // Get doctor's affiliation
      final doctorDoc = await FirebaseFirestore.instance
          .collection('doctors')
          .doc(doctorId)
          .get();

      if (!doctorDoc.exists) {
        print('❌ Doctor document not found: $doctorId');
        final result = 'Doctor Not Found';
        _patientLocationCache[patientId] = result; // Cache the result
        return result;
      }

      final doctorData = doctorDoc.data() as Map<String, dynamic>;
      final affiliations = doctorData['affiliations'] as List<dynamic>?;

      if (affiliations != null && affiliations.isNotEmpty) {
        final firstAffiliation = affiliations[0];
        final location = firstAffiliation['name'] ??
            firstAffiliation['facilityName'] ??
            firstAffiliation['facility']?['name'] ??
            'N/A';

        print('✅ Patient location from doctor: $location');
        _patientLocationCache[patientId] = location; // Cache the result
        return location;
      }

      print('❌ No affiliations found for doctor: $doctorId');
      final result = 'No Doctor Location';
      _patientLocationCache[patientId] = result; // Cache the result
      return result;
    } catch (e) {
      print('❌ Error fetching patient location: $e');
      final result = 'Error';
      _patientLocationCache[patientId] = result; // Cache the result
      return result;
    }
  }

  // Build health workers table and include view action
  Widget _buildHealthWorkersTable({String? filteredFacility}) {
    final query =
        FirebaseFirestore.instance.collection('healthcare').limit(500);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final role = (data['role'] as String?)?.toLowerCase();
          if (role == 'doctor')
            return false; // skip doctors in healthcare collection
          if (filteredFacility == null || filteredFacility.isEmpty) return true;
          final facility = data['facility'];
          if (facility is Map) return facility['name'] == filteredFacility;
          if (facility is String) return facility == filteredFacility;
          return false;
        }).toList();

        if (docs.isEmpty)
          return const Center(child: Text('No health workers found'));

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: [
              DataColumn(
                  label: Text('Name',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700))),
              DataColumn(
                  label: Text('Position',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700))),
              DataColumn(
                  label: Text('Location',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700))),
              DataColumn(
                  label: Text('Actions',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700))),
            ],
            rows: docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final name = data['fullName'] ?? data['name'] ?? 'N/A';
              final position = data['position'] ?? data['role'] ?? 'N/A';
              final location = (data['facility'] is Map)
                  ? data['facility']['name'] ?? 'N/A'
                  : (data['facility'] ?? 'N/A');
              return DataRow(cells: [
                DataCell(Text(name)),
                DataCell(Text(position)),
                DataCell(Text(location)),
                DataCell(Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.visibility,
                          color: Color(0xFFEF4444)),
                      onPressed: () => _showHealthWorkerInfo(doc),
                    ),
                  ],
                )),
              ]);
            }).toList(),
          ),
        );
      },
    );
  }

  void _showHealthWorkerInfo(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Health Worker Information',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: ${data['fullName'] ?? data['name'] ?? 'N/A'}'),
            const SizedBox(height: 8),
            Text('Email: ${data['email'] ?? 'N/A'}'),
            const SizedBox(height: 8),
            Text('Position: ${data['position'] ?? data['role'] ?? 'N/A'}'),
            const SizedBox(height: 8),
            Text(
                'Location: ${(data['facility'] is Map) ? data['facility']['name'] ?? 'N/A' : (data['facility'] ?? 'N/A')}'),
            const SizedBox(height: 8),
            Text(
                'Address: ${(data['facility'] is Map) ? data['facility']['address'] ?? 'N/A' : 'N/A'}'),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const Spacer(),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1F2937),
                ),
              ),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildViewCard({
    required IconData icon,
    required String title,
    required String viewKey,
    required Color color,
  }) {
    final isSelected = _selectedView == viewKey;

    return InkWell(
      onTap: () {
        setState(() {
          // Toggle: if already selected, deselect (show all), otherwise select this view
          _selectedView = isSelected ? null : viewKey;
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? color.withOpacity(0.2)
                  : Colors.black.withOpacity(0.05),
              blurRadius: isSelected ? 15 : 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(isSelected ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? color : const Color(0xFF1F2937),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// TB Facilitators View
class FacilitatorsView extends StatefulWidget {
  const FacilitatorsView({super.key});

  @override
  State<FacilitatorsView> createState() => _FacilitatorsViewState();
}

class _FacilitatorsViewState extends State<FacilitatorsView> {
  Map<String, String> facilities = {};
  bool isLoadingFacilities = true;

  @override
  void initState() {
    super.initState();
    _fetchLocalFacilities();
  }

  Future<void> _fetchLocalFacilities() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('facilities').get();
      final Map<String, String> loaded = {};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        loaded[data['name'] ?? doc.id] =
            data['address'] ?? 'Address not available';
      }
      if (mounted)
        setState(() {
          facilities = loaded;
          isLoadingFacilities = false;
        });
    } catch (_) {
      if (mounted) setState(() => isLoadingFacilities = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TB Facilitator Accounts',
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance.collection('admins').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Center(
                        child: Text('No TB Facilitator accounts found'));
                  }

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFEF4444),
                            child: Icon(
                              Icons.person,
                              color: Colors.white,
                            ),
                          ),
                          title: Text(
                            data['email'] ?? 'N/A',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600),
                          ),
                          subtitle: data['facility'] != null
                              ? Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on,
                                      size: 14,
                                      color: Color(0xFF10B981),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        data['facility']['name'] ?? 'N/A',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: const Color(0xFF6B7280),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : null,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit,
                                    color: Color(0xFF3B82F6)),
                                onPressed: () => _showEditDialog(doc),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete,
                                    color: Color(0xFFEF4444)),
                                onPressed: () => _confirmDelete(doc),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final emailController = TextEditingController(text: data['email'] ?? '');
    final formKey = GlobalKey<FormState>();

    String? selectedFacility = data['facility']?['name'];
    String selectedFacilityAddress = data['facility']?['address'] ?? '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            'Edit TB Facilitator',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (!v.contains('@')) return 'Invalid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  if (isLoadingFacilities)
                    const Padding(
                      padding: EdgeInsets.all(20.0),
                      child: CircularProgressIndicator(),
                    )
                  else
                    DropdownButtonFormField<String>(
                      value: selectedFacility,
                      decoration: const InputDecoration(
                        labelText: 'Health Center',
                        prefixIcon: Icon(Icons.local_hospital),
                      ),
                      items: facilities.keys.map((String facility) {
                        return DropdownMenuItem<String>(
                          value: facility,
                          child: Text(facility),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setDialogState(() {
                          selectedFacility = newValue;
                          selectedFacilityAddress = facilities[newValue] ?? '';
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
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF10B981).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: Color(0xFF10B981),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              selectedFacilityAddress,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
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
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState?.validate() != true) return;

                await FirebaseFirestore.instance
                    .collection('admins')
                    .doc(doc.id)
                    .update({
                  'email': emailController.text.trim(),
                  'facility': selectedFacility != null
                      ? {
                          'name': selectedFacility,
                          'address': selectedFacilityAddress,
                        }
                      : null,
                  'updatedAt': FieldValue.serverTimestamp(),
                });

                Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('TB Facilitator updated successfully')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete TB Facilitator'),
        content: Text('Are you sure you want to delete ${data['email']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('admins')
                  .doc(doc.id)
                  .delete();

              Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('TB Facilitator deleted successfully')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
