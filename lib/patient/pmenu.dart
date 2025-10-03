import 'package:flutter/material.dart';
import 'package:tb_frontend/patient/planding_page.dart';
import 'package:tb_frontend/patient/pmyappointment.dart';
// REMOVE pmessages import since we’re not using it anymore
import 'package:tb_frontend/patient/paccount.dart';
import 'package:tb_frontend/login_screen.dart';
import 'package:tb_frontend/patient/pmessages.dart';
// ✅ Import the new UserListScreen we created

// ------------------ MAIN WRAPPER WITH NAVBAR & DRAWER ------------------
class PatientMainWrapper extends StatefulWidget {
  final int initialIndex;
  const PatientMainWrapper({super.key, this.initialIndex = 0});

  @override
  State<PatientMainWrapper> createState() => _PatientMainWrapperState();
}

class _PatientMainWrapperState extends State<PatientMainWrapper> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const PlandingPage(),
    const PMyAppointmentScreen(),
    const Pmessages(), // ✅ replaced Pmessages with UserListScreen
    const Paccount(),
  ];

  final List<String> _routeNames = [
    'home',
    'appointments',
    'messages',
    'account',
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  void _onNavTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _onDrawerTap(int index) {
    Navigator.pop(context); // close drawer
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: CustomDrawer(
        currentRoute: _routeNames[_selectedIndex],
        onDrawerTap: _onDrawerTap,
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: _onNavTap,
            selectedItemColor: Colors.redAccent,
            unselectedItemColor: Colors.grey.shade400,
            selectedFontSize: 12,
            unselectedFontSize: 12,
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            elevation: 0,
            items: [
              BottomNavigationBarItem(
                icon: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: EdgeInsets.all(_selectedIndex == 0 ? 8.0 : 5.0),
                    decoration: BoxDecoration(
                      color: _selectedIndex == 0
                          ? Colors.redAccent.withOpacity(0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.home_rounded),
                  ),
                ),
                label: "Home",
              ),
              BottomNavigationBarItem(
                icon: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: EdgeInsets.all(_selectedIndex == 1 ? 8.0 : 5.0),
                    decoration: BoxDecoration(
                      color: _selectedIndex == 1
                          ? Colors.redAccent.withOpacity(0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.calendar_month_rounded),
                  ),
                ),
                label: "Appointments",
              ),
              BottomNavigationBarItem(
                icon: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: EdgeInsets.all(_selectedIndex == 2 ? 8.0 : 5.0),
                    decoration: BoxDecoration(
                      color: _selectedIndex == 2
                          ? Colors.redAccent.withOpacity(0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.chat_rounded),
                  ),
                ),
                label: "Messages",
              ),
              BottomNavigationBarItem(
                icon: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: EdgeInsets.all(_selectedIndex == 3 ? 8.0 : 5.0),
                    decoration: BoxDecoration(
                      color: _selectedIndex == 3
                          ? Colors.redAccent.withOpacity(0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.person_rounded),
                  ),
                ),
                label: "Account",
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------ DRAWER ------------------
class CustomDrawer extends StatelessWidget {
  final String currentRoute;
  final Function(int) onDrawerTap;

  const CustomDrawer({
    super.key,
    required this.currentRoute,
    required this.onDrawerTap,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            _buildDrawerItem(
              context,
              icon: Icons.home,
              label: 'Home',
              index: 0,
              isActive: currentRoute == 'home',
            ),
            _buildDrawerItem(
              context,
              icon: Icons.calendar_today,
              label: 'Appointments',
              index: 1,
              isActive: currentRoute == 'appointments',
            ),
            _buildDrawerItem(
              context,
              icon: Icons.message_outlined,
              label: 'Messages',
              index: 2,
              isActive: currentRoute == 'messages',
            ),
            _buildDrawerItem(
              context,
              icon: Icons.account_circle,
              label: 'Account',
              index: 3,
              isActive: currentRoute == 'account',
            ),
            const Spacer(),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Color(0xFFF44336)),
              title: const Text(
                'Logout',
                style: TextStyle(
                  color: Color(0xFFF44336),
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const TBisitaLoginScreen()),
                  (Route<dynamic> route) => false,
                );
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required int index,
    required bool isActive,
  }) {
    return Container(
      color: isActive ? const Color(0xFFFF4081) : Colors.transparent,
      child: ListTile(
        leading: Icon(icon, color: isActive ? Colors.white : Colors.black),
        title: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.black,
            fontWeight: FontWeight.w500,
          ),
        ),
        onTap: () {
          if (!isActive) {
            onDrawerTap(index);
          } else {
            Navigator.pop(context);
          }
        },
      ),
    );
  }
}
