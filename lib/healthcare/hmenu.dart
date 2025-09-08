import 'package:flutter/material.dart';
import 'package:tb_frontend/healthcare/pages/hlanding_page.dart';
import 'package:tb_frontend/healthcare/pages/happointment.dart';
import 'package:tb_frontend/healthcare/pages/hmessages.dart';
import 'package:tb_frontend/healthcare/pages/haccount.dart';

class HealthMainWrapper extends StatefulWidget {
  final int initialIndex;
  const HealthMainWrapper({super.key, this.initialIndex = 0});

  @override
  State<HealthMainWrapper> createState() => _HealthMainWrapperState();
}

class _HealthMainWrapperState extends State<HealthMainWrapper> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    HLandingPage(),
    HAppointment(),
    HMessages(),
    HAccount(),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onNavTap,
        selectedItemColor: Colors.pinkAccent,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: "Appointments",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.message_outlined),
            label: "Messages",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle),
            label: "Account",
          ),
        ],
      ),
    );
  }
}
