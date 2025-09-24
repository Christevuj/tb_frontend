import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'hlist.dart';

class HFacilityList extends StatelessWidget {
	const HFacilityList({super.key});

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: const Text('TB DOTS Facilities'),
				backgroundColor: Colors.redAccent,
			),
			body: StreamBuilder<QuerySnapshot>(
				stream: FirebaseFirestore.instance.collection('affiliation').snapshots(),
				builder: (context, snapshot) {
					if (snapshot.connectionState == ConnectionState.waiting) {
						return const Center(child: CircularProgressIndicator());
					}
					if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
						return const Center(child: Text('No facilities found.'));
					}
					final facilities = snapshot.data!.docs;
					return ListView.builder(
						itemCount: facilities.length,
						itemBuilder: (context, index) {
							final facility = facilities[index].data() as Map<String, dynamic>;
							final name = facility['name'] ?? 'Unknown Facility';
							final address = facility['address'] ?? '';
							return ListTile(
								leading: const Icon(Icons.local_hospital, color: Colors.redAccent),
								title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
								subtitle: Text(address),
								onTap: () {
									Navigator.push(
										context,
										MaterialPageRoute(
											builder: (_) => HList(facilityId: facilities[index].id, facilityName: name),
										),
									);
								},
							);
						},
					);
				},
			),
		);
	}
}
