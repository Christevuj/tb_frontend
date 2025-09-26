import 'package:cloud_firestore/cloud_firestore.dart';

class Doctor {
  final String id;
  final String name;
  final String specialization;
  final String experience;
  final String facility;
  final String facilityAddress;
  final String imageUrl;
  final double rating;
  final String email;

  Doctor({
    required this.id,
    required this.name,
    required this.specialization,
    required this.experience,
    required this.facility,
    required this.facilityAddress,
    required this.imageUrl,
    required this.rating,
    required this.email,
  });

  factory Doctor.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Doctor(
      id: doc.id,
      name: data['fullName'] ??
          data['name'] ??
          '', // Try fullName first, fallback to name
      specialization: data['specialization'] ?? '',
      experience: data['experience']?.toString() ?? '',
      facility: data['0']?['name'] ?? '', // Get facility name
      facilityAddress: data['0']?['address'] ?? '', // Get facility address
      imageUrl: data['imageUrl'] ?? 'assets/images/doc1.png',
      rating: (data['rating'] ?? 0.0).toDouble(),
      email: data['email'] ?? '',
    );
  }
}
