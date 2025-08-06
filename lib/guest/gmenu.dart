import 'package:flutter/material.dart';
import 'package:tb_frontend/guest/glanding_page.dart';
import 'package:tb_frontend/guest/gconsultant.dart';
import 'package:tb_frontend/guest/gappointment.dart';
import 'package:tb_frontend/login_screen.dart';
import 'package:tb_frontend/guest/gtbfacility.dart';

class CustomDrawer extends StatelessWidget {
  final String currentRoute;

  const CustomDrawer({super.key, required this.currentRoute});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            const CircleAvatar(
              radius: 40,
              backgroundImage: AssetImage('assets/images/marco_tan.jpg'),
            ),
            const SizedBox(height: 10),
            const Text(
              'Marco Tan',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            _buildDrawerItem(
              context,
              icon: Icons.home,
              label: 'Home',
              destination: const GlandingPage(),
              isActive: currentRoute == 'home',
              routeName: 'home',
            ),
            _buildDrawerItem(
              context,
              icon: Icons.smart_toy,
              label: 'AI Consultant',
              destination: const GConsultant(),
              isActive: currentRoute == 'consultant',
              routeName: 'consultant',
            ),
            _buildDrawerItem(
              context,
              icon: Icons.book_online_outlined,
              label: 'Book Appointment',
              destination: const Gappointment(),
              isActive: currentRoute == 'appointment',
              routeName: 'appointment',
            ),
            _buildDrawerItem(
              context,
              icon: Icons.apartment,
              label: 'TB Dots Facilities',
              destination: const GtbfacilityPage(),
              isActive: currentRoute == 'facilities',
              routeName: 'facilities',
            ),
            _buildDrawerItem(
              context,
              icon: Icons.info_outline,
              label: 'Terms & Conditions',
              destination: const Placeholder(),
              isActive: currentRoute == 'terms',
              routeName: 'terms',
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
    required Widget destination,
    required bool isActive,
    required String routeName,
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
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => destination),
            );
          } else {
            Navigator.pop(context); // Just close drawer
          }
        },
      ),
    );
  }
}
