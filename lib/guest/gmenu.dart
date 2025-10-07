import 'package:flutter/material.dart';
import 'package:tb_frontend/guest/glanding_page.dart';
import 'package:tb_frontend/guest/gappointment.dart';
import 'package:tb_frontend/guest/gmessages.dart';
import 'package:tb_frontend/guest/gaccount.dart';

class GuestMainWrapper extends StatefulWidget {
  final int initialIndex;
  const GuestMainWrapper({super.key, this.initialIndex = 0});

  @override
  State<GuestMainWrapper> createState() => _GuestMainWrapperState();
}

class _GuestMainWrapperState extends State<GuestMainWrapper> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const GlandingPage(),
    const Gappointment(),
    const Gmessages(),
    const Gaccount(),
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
              ),
    );
  }
}
