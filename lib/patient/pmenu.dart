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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, -2),
            )
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navBarItem(Icons.home, "Home", 0),
            _navBarItem(Icons.calendar_today, "Appointments", 1),
            _navBarItem(Icons.message_outlined, "Messages", 2),
            _navBarItem(Icons.account_circle, "Account", 3),
          ],
        ),
      ),
    );
  }

  Widget _navBarItem(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onNavTap(index),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 28,
              color: isSelected ? Colors.pinkAccent : Colors.grey,
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.pinkAccent : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
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
