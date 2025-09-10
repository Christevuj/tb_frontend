import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../accounts/medical_staff_create.dart';
import './admin_login.dart' show AdminLogin;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Admin Dashboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.red,
        scaffoldBackgroundColor: Colors.white,
        textTheme: GoogleFonts.poppinsTextTheme(), // Use modern font
      ),
      home: const AdminDashboard(),
    );
  }
}

enum DashboardTab { dashboard, doctors, patients, healthWorkers }

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  bool _isHovered = false; // Sidebar hover state
  DashboardTab _selectedTab = DashboardTab.dashboard; // default

  // Navigate directly to medical staff creation page
  void _showAccountCreationDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MedicalStaffCreatePage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          // Sidebar
          MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              width: _isHovered ? 230 : 90,
              color: Colors.redAccent,
              child: Column(
                children: [
                  const SizedBox(height: 30),

                  // Logo at the top
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 60, end: _isHovered ? 80 : 60),
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                    builder: (context, size, child) {
                      return Icon(Icons.admin_panel_settings,
                          color: Colors.white, size: size);
                    },
                  ),

                  const SizedBox(height: 40),

                  // Sidebar buttons
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        _buildSidebarButton(
                          icon: Icons.dashboard,
                          label: "Dashboard",
                          tab: DashboardTab.dashboard,
                        ),
                        const SizedBox(height: 20),
                        _buildSidebarButton(
                          icon: Icons.local_hospital,
                          label: "Doctors",
                          tab: DashboardTab.doctors,
                        ),
                        const SizedBox(height: 20),
                        _buildSidebarButton(
                          icon: Icons.people,
                          label: "Patients",
                          tab: DashboardTab.patients,
                        ),
                        const SizedBox(height: 20),
                        _buildSidebarButton(
                          icon: Icons.health_and_safety,
                          label: "Health Workers",
                          tab: DashboardTab.healthWorkers,
                        ),
                      ],
                    ),
                  ),

                  // Logout Button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: InkWell(
                      onTap: () {
                        // Show confirmation dialog
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(
                              'Confirm Logout',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                color: Colors.redAccent,
                              ),
                            ),
                            content: Text(
                              'Are you sure you want to logout?',
                              style: GoogleFonts.poppins(),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text(
                                  'Cancel',
                                  style: GoogleFonts.poppins(
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () async {
                                  try {
                                    await FirebaseAuth.instance.signOut();
                                    if (context.mounted) {
                                      Navigator.of(context).pushAndRemoveUntil(
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const AdminLogin(),
                                        ),
                                        (route) => false,
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Error logging out: $e',
                                            style: GoogleFonts.poppins(),
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                },
                                child: Text(
                                  'Logout',
                                  style: GoogleFonts.poppins(
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.logout,
                                color: Colors.redAccent, size: 28),
                            if (_isHovered) const SizedBox(width: 8),
                            if (_isHovered)
                              Text(
                                "Logout",
                                style: GoogleFonts.poppins(
                                  color: Colors.redAccent,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Create Account Button at bottom
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: InkWell(
                      onTap: _showAccountCreationDialog,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add, color: Colors.redAccent, size: 28),
                            if (_isHovered) const SizedBox(width: 8),
                            if (_isHovered)
                              Text(
                                "Create Account",
                                style: GoogleFonts.poppins(
                                  color: Colors.redAccent,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
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
          ),

          // Main Content Area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: _buildSelectedContent(),
            ),
          ),
        ],
      ),
    );
  }

  // Sidebar button
  Widget _buildSidebarButton({
    required IconData icon,
    required String label,
    required DashboardTab tab,
  }) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedTab = tab;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 36, end: _isHovered ? 48 : 36),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            builder: (context, size, child) {
              return Icon(icon, color: Colors.white, size: size);
            },
          ),
          if (_isHovered)
            Expanded(
              child: AnimatedOpacity(
                opacity: _isHovered ? 1 : 0,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
                child: Padding(
                  padding: const EdgeInsets.only(left: 14),
                  child: Text(
                    label,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Content builder based on selected tab
  Widget _buildSelectedContent() {
    switch (_selectedTab) {
      case DashboardTab.doctors:
        return DashboardContent.buildDoctorsTable();
      case DashboardTab.patients:
        return DashboardContent.buildPatientsTable();
      case DashboardTab.healthWorkers:
        return DashboardContent.buildHealthWorkersTable();
      case DashboardTab.dashboard:
        return const DashboardContent();
    }
  }
}

// ---------- Dashboard Content ----------
class DashboardContent extends StatelessWidget {
  const DashboardContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "DASHBOARD",
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.redAccent,
          ),
        ),
        const SizedBox(height: 25),

        // Top Stat Cards
        Row(
          children: [
            Expanded(child: _buildStatCard("TOTAL", "120", "Applications")),
            const SizedBox(width: 14),
            Expanded(child: _buildStatCard("PATIENTS", "80", "Registered")),
            const SizedBox(width: 14),
            Expanded(child: _buildStatCard("DOCTORS", "10", "Active")),
            const SizedBox(width: 14),
            Expanded(child: _buildStatCard("TB DOTS", "30", "Workers")),
          ],
        ),
        const SizedBox(height: 25),

        // Doctors + Health Workers
        Expanded(
          child: Row(
            children: [
              Expanded(child: buildDoctorsTable()),
              const SizedBox(width: 30),
              Expanded(child: buildHealthWorkersTable()),
            ],
          ),
        ),
        const SizedBox(height: 25),

        // Patients Table
        Expanded(child: buildPatientsTable()),
      ],
    );
  }

  // Stat Card
  static Widget _buildStatCard(String title, String value, String subtitle) {
    return Card(
      color: Colors.redAccent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 5,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          children: [
            Text(title,
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, color: Colors.white)),
            const SizedBox(height: 12),
            Text(value,
                style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const SizedBox(height: 6),
            Text(subtitle,
                style:
                    GoogleFonts.poppins(fontSize: 14, color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  // ---------- Static Table Methods ----------
  static Widget buildDoctorsTable() {
    return _buildTableCard(
      title: "Doctors",
      minWidth: 600,
      headers: ["Name", "Specialization", "Applications", "Status"],
      rows: [
        ["Yasmin Adam", "Pulmonologist", "5", "Pending"],
        ["Ahmad Khalid", "Pharmacologist", "3", "Pending"],
        ["Asaad Osman", "Pulmonologist", "2", "Pending"],
      ],
    );
  }

  static Widget buildPatientsTable() {
    return _buildTableCard(
      title: "Patients",
      minWidth: 900,
      headers: [
        "Name",
        "TB Care Program",
        "Enrolled Facility",
        "Treatment Status",
        "Feedback"
      ],
      rows: [
        [
          "Yasmin Adam",
          "Enrolled",
          "Bago Aplaya Health Center",
          "Ongoing",
          "I like that I can track my progress online."
        ],
        ["Ahmad Khalid", "Not Enrolled", "-", "-", "-"],
        [
          "Amani Byte",
          "Enrolled",
          "Agdao Health Center",
          "Completed",
          "It helped me understand my symptoms better."
        ],
      ],
    );
  }

  static Widget buildHealthWorkersTable() {
    return _buildTableCard(
      title: "TB DOTS Health Workers",
      minWidth: 700,
      headers: ["Name", "Designation", "Facility", "Applications", "Status"],
      rows: [
        ["Fatima Noor", "Nurse", "Agdao Health Center", "4", "Pending"],
        ["Ahmad Rizwan", "Doctor", "Buhangin Center", "2", "Pending"],
        ["Amani Byte", "Nurse", "Calinan Health Center", "3", "Pending"],
      ],
    );
  }

  // Generic Table Card
  static Widget _buildTableCard({
    required String title,
    required List<String> headers,
    required List<List<String>> rows,
    double minWidth = 600,
  }) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: const Color.fromRGBO(255, 82, 82, 1))),
            const SizedBox(height: 14),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: minWidth),
                    child: Table(
                      border: TableBorder.all(
                        color: Colors.redAccent.withOpacity(0.3),
                        width: 1,
                      ),
                      columnWidths: {
                        for (int i = 0; i < headers.length; i++)
                          i: const FlexColumnWidth(),
                      },
                      children: [
                        // Header
                        TableRow(
                          decoration: BoxDecoration(
                            color: Colors.redAccent.shade100,
                          ),
                          children: headers
                              .map(
                                (h) => Padding(
                                  padding: const EdgeInsets.all(10.0),
                                  child: Center(
                                    child: Text(
                                      h,
                                      style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                          color: Colors.redAccent),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                        // Rows
                        ...rows.map(
                          (row) => TableRow(
                            decoration: BoxDecoration(
                              color: rows.indexOf(row) % 2 == 0
                                  ? Colors.grey.shade100
                                  : Colors.white,
                            ),
                            children: row
                                .map(
                                  (cell) => Padding(
                                    padding: const EdgeInsets.all(10.0),
                                    child: Center(
                                      child: Text(
                                        cell,
                                        style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w400),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
