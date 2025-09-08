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

  final List<Widget> _pages = const [
    GlandingPage(),
    Gappointment(),
    Gmessages(),
    Gaccount(),
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
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

  bool _isRootPage() {
    final navigator = _navigatorKeys[_selectedIndex].currentState;
    if (navigator == null) return true;
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
        // Only show bottom nav if we are at the root of the tab
        bottomNavigationBar: _isRootPage()
            ? BottomNavigationBar(
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
              )
            : null,
      ),
    );
  }
}
