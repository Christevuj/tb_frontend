import 'package:flutter/material.dart';
import 'package:tb_frontend/guest/gmenu.dart';
import 'package:tb_frontend/guest/gviewdoctor.dart';
import 'package:tb_frontend/guest/gappointment.dart';
import 'package:tb_frontend/guest/gconsultant.dart';
import 'package:tb_frontend/guest/gtbfacility.dart';

class GlandingPage extends StatelessWidget {
  const GlandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      drawer: const CustomDrawer(currentRoute: ''),
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
            // Search bar
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

            // Quick Actions
            const Text('Quick Actions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _quickAction(context, Icons.smart_toy, 'AI\nConsultant', const GConsultant()),
                _quickAction(context, Icons.calendar_today, 'Book\nAppointment', const Gappointment()),
                _quickAction(context, Icons.local_hospital, 'TB DOTS\nFacilities', const GtbfacilityPage ()),
              ],
            ),
            const SizedBox(height: 24),

            // Top Doctors
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Top Doctors',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const Gappointment()),
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

            // Doctor List
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
    );
  }

  // Quick Action Widget with navigation
  static Widget _quickAction(BuildContext context, IconData icon, String label, Widget destination) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => destination),
        );
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.redAccent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(2, 2)),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  // Doctor Card Widget
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
          // Doctor Image
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

          // Doctor Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dr. Miguel Rosales',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                const Text('MD, Pulmonologist',
                    style: TextStyle(color: Colors.black54, fontSize: 13)),
                const Text('Talomo South Health Center',
                    style: TextStyle(color: Colors.black45, fontSize: 12)),
                const SizedBox(height: 6),
                Row(
                  children: const [
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

          // View Button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const GViewDoctor()),
              );
            },
            child: const Text(
              'TAN-AWA',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
