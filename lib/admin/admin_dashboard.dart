import 'package:flutter/material.dart';

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
      ),
      home: const AdminDashboard(),
    );
  }
}

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  bool _isHovered = false; // Sidebar hover state

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          // Sidebar with smooth hover animation
          MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              width: _isHovered ? 220 : 90,
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

                  // Sidebar buttons CENTERED vertically
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildSidebarButton(
                          icon: Icons.home,
                          label: "Home",
                          page: const HomePage(),
                        ),
                        const SizedBox(height: 25),
                        _buildSidebarButton(
                          icon: Icons.person,
                          label: "Patients",
                          page: const PatientsPage(),
                        ),
                        const SizedBox(height: 25),
                        _buildSidebarButton(
                          icon: Icons.local_hospital,
                          label: "Doctors",
                          page: const DoctorsPage(),
                        ),
                        const SizedBox(height: 25),
                        _buildSidebarButton(
                          icon: Icons.settings,
                          label: "Settings",
                          page: const SettingsPage(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Main Content Area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "DASHBOARD",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Top Stat Cards
                  Row(
                    children: [
                      Expanded(
                          child:
                              _buildStatCard("TOTAL", "120", "Applications")),
                      const SizedBox(width: 10),
                      Expanded(
                          child:
                              _buildStatCard("PATIENTS", "80", "Registered")),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _buildStatCard("DOCTORS", "10", "Active")),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _buildStatCard("TB DOTS", "30", "Workers")),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Doctors + Health Workers
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: _buildTableCard(
                            title: "Doctors",
                            minWidth: 600,
                            headers: [
                              "Name",
                              "Specialization",
                              "Applications",
                              "Status"
                            ],
                            rows: [
                              ["Yasmin Adam", "Pulmonologist", "5", "Pending"],
                              [
                                "Ahmad Khalid",
                                "Pharmacologist",
                                "3",
                                "Pending"
                              ],
                              ["Asaad Osman", "Pulmonologist", "2", "Pending"],
                            ],
                          ),
                        ),
                        const SizedBox(width: 30),
                        Expanded(
                          flex: 1,
                          child: _buildTableCard(
                            title: "TB DOTS Health Workers",
                            minWidth: 700,
                            headers: [
                              "Name",
                              "Designation",
                              "Facility",
                              "Applications",
                              "Status"
                            ],
                            rows: [
                              [
                                "Fatima Noor",
                                "Nurse",
                                "Agdao Health Center",
                                "4",
                                "Pending"
                              ],
                              [
                                "Ahmad Rizwan",
                                "Doctor",
                                "Buhangin Center",
                                "2",
                                "Pending"
                              ],
                              [
                                "Amani Byte",
                                "Nurse",
                                "Calinan Health Center",
                                "3",
                                "Pending"
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Patients Table - Full Width
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildTableCard(
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
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Sidebar button widget with bigger icons
  Widget _buildSidebarButton(
      {required IconData icon, required String label, required Widget page}) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => page),
        );
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
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(
                    label,
                    style: const TextStyle(color: Colors.white, fontSize: 20),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Stat Card
  static Widget _buildStatCard(String title, String value, String subtitle) {
    return Card(
      color: Colors.redAccent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 10),
            Text(value,
                style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const SizedBox(height: 5),
            Text(subtitle, style: const TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  // Table Card
  static Widget _buildTableCard({
    required String title,
    required List<String> headers,
    required List<List<String>> rows,
    double minWidth = 600,
  }) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 5,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.redAccent)),
            const SizedBox(height: 10),
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
                                  padding: const EdgeInsets.all(8.0),
                                  child: Center(
                                    child: Text(
                                      h,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
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
                                    padding: const EdgeInsets.all(8.0),
                                    child: Center(
                                      child: Text(
                                        cell,
                                        style: const TextStyle(fontSize: 14),
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

// 👉 Dummy Pages
class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text("Home Page")));
  }
}

class PatientsPage extends StatelessWidget {
  const PatientsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text("Patients Page")));
  }
}

class DoctorsPage extends StatelessWidget {
  const DoctorsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text("Doctors Page")));
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text("Settings Page")));
  }
}
