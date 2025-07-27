import 'package:flutter/material.dart';
import 'package:tb_frontend/guest/gmenu.dart'; // Make sure CustomDrawer is defined here
import 'package:tb_frontend/guest/gviewdoctor.dart';

class Gappointment extends StatelessWidget {
  const Gappointment({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const CustomDrawer(currentRoute: 'appointment'),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.pink),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
        title: const Text(
          'Book Appointment',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ListView(
          children: [
            const SizedBox(height: 10),

            // Search bar
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(30),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: "Search doctors",
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.search, color: Colors.pink),
                    onPressed: () {},
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            const Text("Favorite Doctors", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            const DoctorCard(
              image: 'assets/images/doc1.png',
              name: 'Dr. Zubaear Rahim',
              specialty: 'MD, Pulmonologist',
              location: 'Davao Doctors Hospital',
              rating: '4.5',
              isFavorite: true,
            ),
            const DoctorCard(
              image: 'assets/images/doc2.png',
              name: 'Dr. Arlyn Santos',
              specialty: 'MD, Pulmonologist',
              location: 'Chest Center',
              rating: '3.9',
              isFavorite: true,
            ),

            const SizedBox(height: 10),
            const Text("75 Available Doctors", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            const DoctorCard(
              image: 'assets/images/doc3.png',
              name: 'Dr. Miguel Rosales',
              specialty: 'MD, Pulmonologist',
              location: 'Talomo South Health Center',
              rating: '4.2',
              isFavorite: false,
            ),
            const DoctorCard(
              image: 'assets/images/doc2.png',
              name: 'Dr. Lianne Ortega',
              specialty: 'MD, Pulmonologist',
              location: 'Southern Philippines Medical Center',
              rating: '3.3',
              isFavorite: false,
            ),
            const DoctorCard(
              image: 'assets/images/doc1.png',
              name: 'Dr. Zubaear Rahim',
              specialty: 'MD, Pulmonologist',
              location: 'Talomo Central Health Center',
              rating: '4.5',
              isFavorite: true,
            ),
            const DoctorCard(
              image: 'assets/images/doc3.png',
              name: 'Dr. Carlos Buenafe',
              specialty: 'MD, Pulmonologist',
              location: 'Southern Philippines Medical Center',
              rating: '3.9',
              isFavorite: false,
            ),
          ],
        ),
      ),
    );
  }
}

class DoctorCard extends StatelessWidget {
  final String image;
  final String name;
  final String specialty;
  final String location;
  final String rating;
  final bool isFavorite;

  const DoctorCard({
    super.key,
    required this.image,
    required this.name,
    required this.specialty,
    required this.location,
    required this.rating,
    this.isFavorite = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const GViewDoctor()),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                image,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(specialty, style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 14, color: Colors.grey),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(location,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star, size: 14, color: Colors.white),
                      Text(rating, style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: Colors.pink,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
