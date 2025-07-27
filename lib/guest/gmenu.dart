import 'package:flutter/material.dart';
import 'package:tb_frontend/guest/glanding_page.dart';
import 'package:tb_frontend/guest/gconsultant.dart';
import 'package:tb_frontend/guest/gappointment.dart';
// Add more imports for other pages like gbook_appointment.dart, gtbdots.dart, etc.

class CustomDrawer extends StatelessWidget {
  final String currentRoute; // 👈 To highlight the active menu item

  const CustomDrawer({super.key, required this.currentRoute});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            const CircleAvatar(
              radius: 40,
              backgroundImage: AssetImage('assets/images/marco_tan.jpg'),
            ),
            const SizedBox(height: 10),
            const Text(
              'Marco Tan',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            _buildDrawerItem(
              context,
              icon: Icons.home,
              label: 'Home',
              destination: const GlandingPage(),
              isActive: currentRoute == 'home',
            ),
            _buildDrawerItem(
              context,
              icon: Icons.smart_toy,
              label: 'AI Consultant',
              destination: const GConsultant(),
              isActive: currentRoute == 'consultant',
            ),
            _buildDrawerItem(
              context,
              icon: Icons.book_online_outlined,
              label: 'Book Appointment',
              destination: const Gappointment(), // ✅ Now properly referenced
              isActive: currentRoute == 'appointment',
            ),
            _buildDrawerItem(
              context,
              icon: Icons.apartment,
              label: 'TB Dots Facilities',
              destination: const Placeholder(), // TODO: Replace
              isActive: currentRoute == 'facilities',
            ),
            _buildDrawerItem(
              context,
              icon: Icons.info_outline,
              label: 'Terms & conditions',
              destination: const Placeholder(), // TODO: Replace
              isActive: currentRoute == 'terms',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Widget destination,
    required bool isActive,
  }) {
    return Container(
      color: isActive ? Colors.pinkAccent : Colors.transparent,
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
          Navigator.pop(context);
          if (!isActive) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => destination),
            );
          }
        },
      ),
    );
  }
}
