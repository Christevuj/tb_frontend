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

    // Get the first affiliation from the affiliations array
    String facilityName = '';
    String facilityAddress = '';

    if (data['affiliations'] != null &&
        data['affiliations'] is List &&
        (data['affiliations'] as List).isNotEmpty) {
      final firstAffiliation = data['affiliations'][0];
      if (firstAffiliation is Map<String, dynamic>) {
        facilityName = firstAffiliation['name'] ?? '';
        facilityAddress = firstAffiliation['address'] ?? '';
      }
    }

    return Doctor(
      id: doc.id,
      name: data['fullName'] ??
          data['name'] ??
          '', // Try fullName first, fallback to name
      specialization: data['specialization'] ?? '',
      experience: data['experience']?.toString() ?? '',
      facility: facilityName, // Get facility name from affiliations
      facilityAddress:
          facilityAddress, // Get facility address from affiliations
      imageUrl: data['imageUrl'] ?? 'assets/images/doc1.png',
      rating: (data['rating'] ?? 0.0).toDouble(),
      email: data['email'] ?? '',
    );
  }
}
