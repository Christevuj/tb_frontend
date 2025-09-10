import 'package:flutter/material.dart';
import 'package:tb_frontend/doctor/dlanding_page.dart';
import 'package:tb_frontend/doctor/dappointment.dart';
// ❌ remove dmessages import
import 'package:tb_frontend/doctor/daccount.dart';

// ✅ import the shared UserListScreen
import 'package:tb_frontend/chat_screens/user_list_screen.dart';

class DoctorMainWrapper extends StatefulWidget {
  final int initialIndex;
  const DoctorMainWrapper({super.key, this.initialIndex = 0});

  @override
  State<DoctorMainWrapper> createState() => _DoctorMainWrapperState();
}

class _DoctorMainWrapperState extends State<DoctorMainWrapper> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    Dlandingpage(),
    Dappointment(),
    UserListScreen(), // ✅ replaced Dmessages with UserListScreen
    Daccount(),
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
      body: IndexedStack(
        index: _selectedIndex,
        children: List.generate(_pages.length, (index) {
          return Navigator(
            key: GlobalKey<NavigatorState>(), // ✅ separate stack per tab
            onGenerateRoute: (settings) {
              return MaterialPageRoute(
                builder: (_) => _pages[index],
              );
            },
          );
        }),
      ),
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
