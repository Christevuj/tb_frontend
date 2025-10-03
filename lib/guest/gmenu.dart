import 'package:flutter/material.dart';
import 'package:tb_frontend/guest/glanding_page.dart';
import 'package:tb_frontend/guest/gappointment.dart';
import 'package:tb_frontend/guest/gmessages.dart';
import 'package:tb_frontend/guest/gaccount.dart';
import 'package:tb_frontend/login_screen.dart';

class GuestMainWrapper extends StatefulWidget {
  final int initialIndex;
  const GuestMainWrapper({super.key, this.initialIndex = 0});

  @override
  State<GuestMainWrapper> createState() => _GuestMainWrapperState();
}

class _GuestMainWrapperState extends State<GuestMainWrapper> {
  int _selectedIndex = 0;

  // One key per tab
  final List<GlobalKey<NavigatorState>> _navigatorKeys =
      List.generate(4, (_) => GlobalKey<NavigatorState>());

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;

    // Initialize pages with callback
    _pages = [
      GlandingPage(onSwitchTab: switchToTab),
      const Gappointment(),
      const Gmessages(),
      const Gaccount(),
    ];
  }

  // Public method to switch tabs
  void switchToTab(int index) {
    if (index >= 0 && index < _pages.length) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  void _onNavTap(int index) {
    if (_selectedIndex == index) {
      // Pop to first route if tapped again
      _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  bool _shouldShowBottomNavBar() {
    final navigator = _navigatorKeys[_selectedIndex].currentState;
    if (navigator == null) return true;

    // Only show bottom navbar when on the root pages of the 4 main tabs
    return !navigator.canPop();
  }

  // Add this method to handle navigation to login/signup
  void navigateToLogin(BuildContext context) {
    // This will clear the entire app navigation stack and push login screen
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const TBisitaLoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final navigator = _navigatorKeys[_selectedIndex].currentState;
        if (navigator == null) return true;
        if (navigator.canPop()) {
          navigator.pop();
          return false;
        }
        return true;
      },
      child: Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: List.generate(_pages.length, (index) {
            return Navigator(
              key: _navigatorKeys[index],
              onGenerateRoute: (settings) {
                return MaterialPageRoute(
                  builder: (_) => _pages[index],
                );
              },
            );
          }),
        ),
        bottomNavigationBar: _shouldShowBottomNavBar()
            ? Container(
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
                            padding:
                                EdgeInsets.all(_selectedIndex == 0 ? 8.0 : 5.0),
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
                            padding:
                                EdgeInsets.all(_selectedIndex == 1 ? 8.0 : 5.0),
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
                            padding:
                                EdgeInsets.all(_selectedIndex == 2 ? 8.0 : 5.0),
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
                            padding:
                                EdgeInsets.all(_selectedIndex == 3 ? 8.0 : 5.0),
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
              )
            : null,
      ),
    );
  }
}
