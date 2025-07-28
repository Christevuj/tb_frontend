import 'package:flutter/material.dart';
import 'package:tb_frontend/guest/glanding_page.dart';
import 'package:tb_frontend/guest/gconsultant.dart';
import 'package:tb_frontend/guest/gappointment.dart';
import 'package:tb_frontend/login_screen.dart'; 

class PatientDrawer extends StatelessWidget {
  final String currentRoute;

  const PatientDrawer({super.key, required this.currentRoute});

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
              destination: const Gappointment(),
              isActive: currentRoute == 'appointment',
            ),
            _buildDrawerItem(
              context,
              icon: Icons.calendar_today,
              label: 'My Appointment',
              destination: const Placeholder(),
              isActive: currentRoute == 'my_appointment',
            ),
            _buildDrawerItem(
              context,
              icon: Icons.assignment_turned_in_outlined,
              label: 'Post Appointment',
              destination: const Placeholder(),
              isActive: currentRoute == 'post_appointment',
            ),
            _buildDrawerItem(
              context,
              icon: Icons.message_outlined,
              label: 'Messages',
              destination: const Placeholder(),
              isActive: currentRoute == 'messages',
            ),
            _buildDrawerItem(
              context,
              icon: Icons.local_hospital_outlined,
              label: 'TB Dots Program',
              destination: const Placeholder(),
              isActive: currentRoute == 'tb_dots_program',
            ),
            _buildDrawerItem(
              context,
              icon: Icons.account_circle_outlined,
              label: 'My Account',
              destination: const Placeholder(),
              isActive: currentRoute == 'account',
            ),
            _buildDrawerItem(
              context,
              icon: Icons.apartment,
              label: 'TB Dots Facilities',
              destination: const Placeholder(),
              isActive: currentRoute == 'facilities',
            ),
            _buildDrawerItem(
              context,
              icon: Icons.info_outline,
              label: 'Terms & Conditions',
              destination: const Placeholder(),
              isActive: currentRoute == 'terms',
            ),
            const Spacer(),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Logout',
                style: TextStyle(
                  color: Colors.red,
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
