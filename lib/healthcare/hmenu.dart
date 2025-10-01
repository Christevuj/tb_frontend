import 'package:flutter/material.dart';
import './hlanding_page.dart';
import './hmessages.dart';
import './haccount.dart' show HAccount;

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
    const Hmessages(), // My Care page
    HAccount(), // Account settings page
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex
        .clamp(0, _pages.length - 1)
        .toInt();
  }

  void _onNavTap(int index) {
    setState(() {
      _selectedIndex = index.clamp(0, _pages.length - 1).toInt();
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
          unselectedItemColor: Colors.grey.shade400,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          elevation: 8,
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
                      child: const Icon(Icons.medical_services_rounded),
                    ),
                  ),
                  label: "My Care",
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
                      child: const Icon(Icons.person_rounded),
                    ),
                  ),
                  label: "Account",
                ),
              ],
        ),
      ),
    );
  }
}
