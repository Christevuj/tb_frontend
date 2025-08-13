import 'package:flutter/material.dart';
import 'package:tb_frontend/patient/pmenu.dart';
import 'package:tb_frontend/guest/gviewdoctor.dart';
import 'package:tb_frontend/guest/gappointment.dart';
import 'package:tb_frontend/guest/gconsultant.dart';
import 'package:tb_frontend/guest/gtbfacility.dart';

class PlandingPage extends StatefulWidget {
  const PlandingPage({super.key});

  @override
  State<PlandingPage> createState() => _PlandingPageState();
}

class _PlandingPageState extends State<PlandingPage> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      drawer: const PatientDrawer(currentRoute: ''),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.black),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text('Home', style: TextStyle(color: Colors.black)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const TextField(
                decoration: InputDecoration(
                  icon: Icon(Icons.search),
                  hintText: 'Mangita og Doctor',
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Quick Actions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _quickAction(context, Icons.smart_toy, 'AI\nConsultant',
                    const GConsultant()),
                _quickAction(context, Icons.calendar_today, 'Book\nAppointment',
                    const Gappointment()),
                _quickAction(context, Icons.local_hospital,
                    'TB DOTS\nFacilities', const GtbfacilityPage()),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Top Doctors',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const Gappointment()),
                    );
                  },
                  child: const Text(
                    'Tan-awa Tanan',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 440,
              child: ListView.builder(
                itemCount: 5,
                itemBuilder: (context, index) => _doctorCard(context),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              content: const Text('Create new request!'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                )
              ],
            ),
          );
        },
        backgroundColor: const Color(0xFFFF4C72),
        elevation: 4,
        child: const Icon(Icons.add, size: 32),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Container(
          height: 70,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left side
              Row(
                children: [
                  _navBarItem(
                      icon: Icons.home,
                      label: 'Home',
                      index: 0,
                      selectedIndex: _selectedIndex,
                      onTap: _onItemTapped),
                  const SizedBox(width: 70),
                  _navBarItem(
                      icon: Icons.chat_bubble_outline,
                      label: 'Chat',
                      index: 1,
                      selectedIndex: _selectedIndex,
                      onTap: _onItemTapped),
                ],
              ),
              // Right side
              Row(
                children: [
                  _navBarItem(
                      icon: Icons.favorite_border,
                      label: 'Favorites',
                      index: 3,
                      selectedIndex: _selectedIndex,
                      onTap: _onItemTapped),
                  const SizedBox(width: 70),
                  _navBarItem(
                      icon: Icons.person_outline,
                      label: 'Profile',
                      index: 4,
                      selectedIndex: _selectedIndex,
                      onTap: _onItemTapped),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _quickAction(
      BuildContext context, IconData icon, String label, Widget destination) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
            context, MaterialPageRoute(builder: (context) => destination));
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.redAccent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: Colors.black26, blurRadius: 4, offset: Offset(2, 2))
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 4),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  static Widget _doctorCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.grey.shade300,
              blurRadius: 6,
              offset: const Offset(2, 2))
        ],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'assets/images/doc1.png',
              height: 80,
              width: 80,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dr. Miguel Rosales',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 4),
                Text('MD, Pulmonologist',
                    style: TextStyle(color: Colors.black54, fontSize: 13)),
                Text('Talomo South Health Center',
                    style: TextStyle(color: Colors.black45, fontSize: 12)),
                SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.star, size: 16, color: Colors.orange),
                    Icon(Icons.star, size: 16, color: Colors.orange),
                    Icon(Icons.star, size: 16, color: Colors.orange),
                    Icon(Icons.star, size: 16, color: Colors.orange),
                    Icon(Icons.star_border, size: 16, color: Colors.orange),
                  ],
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => const GViewDoctor()));
            },
            child: const Text('TAN-AWA',
                style: TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _navBarItem({
    required IconData icon,
    required String label,
    required int index,
    required int selectedIndex,
    required Function(int) onTap,
  }) {
    final isSelected = selectedIndex == index;
    return GestureDetector(
      onTap: () => onTap(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 28, color: isSelected ? Colors.black : Colors.grey),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: isSelected ? Colors.black : Colors.grey)),
        ],
      ),
    );
  }
}
