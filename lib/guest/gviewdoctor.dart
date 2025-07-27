import 'package:flutter/material.dart';

class GViewDoctor extends StatelessWidget {
  const GViewDoctor({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Stack(
                children: [
                  Container(
                    height: 250,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF3D7F),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(30),
                        bottomRight: Radius.circular(30),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 20,
                    left: 10,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  Align(
                    alignment: Alignment.center,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'assets/images/doc1.png', // Replace with your image asset path
                          height: 180,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dr. Miguel Rosales',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                            SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.star, size: 16, color: Colors.black),
                                Icon(Icons.star, size: 16, color: Colors.black),
                                Icon(Icons.star, size: 16, color: Colors.black),
                                Icon(Icons.star, size: 16, color: Colors.black),
                              ],
                            ),
                            SizedBox(height: 4),
                            Text(
                              'MD, Pulmonologist',
                              style: TextStyle(fontSize: 14, color: Colors.black54),
                            ),
                            Text(
                              'Talomo South Health Center',
                              style: TextStyle(fontSize: 13, color: Colors.black45),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.pinkAccent,
                          ),
                          child: const Icon(Icons.favorite_border, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.pinkAccent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Column(
                              children: [
                                Text(
                                  'Patient',
                                  style: TextStyle(color: Colors.white),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  '500+',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFA726),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Column(
                              children: [
                                Text(
                                  'Experience',
                                  style: TextStyle(color: Colors.white),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  '08 Year +',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'About Doctor',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Dr. Miguel Rosales is a board-certified pulmonologist specializing in the diagnosis and treatment of respiratory conditions such as asthma, pneumonia, and tuberculosis. With extensive experience in pulmonary medicine, he is dedicated to providing comprehensive care to patients with lung-related health concerns.',
                      style: TextStyle(fontSize: 14, height: 1.4),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Location',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Talomo South Health Center (TB DOTS Clinic)\nLibby Road, Puan, Talomo District, Davao City',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        'assets/images/map1.png', // Replace with your image asset path
                        height: 180,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
