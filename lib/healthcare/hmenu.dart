import 'package:flutter/material.dart';
import './hlanding_page.dart';
import './happointment.dart';
import './haccount.dart' show HAccount;
import '../chat_screens/user_list_screen.dart';

class HealthMainWrapper extends StatefulWidget {
  final int initialIndex;
  const HealthMainWrapper({super.key, this.initialIndex = 0});

  @override
  State<HealthMainWrapper> createState() => _HealthMainWrapperState();
}

class _HealthMainWrapperState extends State<HealthMainWrapper> {
  int _selectedIndex = 0;

  static final List<Widget> _pages = [
    const Hlandingpage(), // Home page
    const Happointment(), // Appointments page
    const UserListScreen(), // Messages page
    const HAccount(), // Account settings page
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  void _onNavTap(int index) {
    setState(() {
      _selectedIndex = index % _pages.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        body: _pages[_selectedIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onNavTap,
          selectedItemColor: Colors.redAccent,
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: "Home",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.notifications),
              label: "Appointments",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_circle),
              label: "Account",
            ),
          ],
        ),
      ),
    );
  }
}
