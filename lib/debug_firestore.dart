import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreDebugPage extends StatefulWidget {
  const FirestoreDebugPage({Key? key}) : super(key: key);

  @override
  State<FirestoreDebugPage> createState() => _FirestoreDebugPageState();
}

class _FirestoreDebugPageState extends State<FirestoreDebugPage> {
  List<Map<String, dynamic>> pendingDocs = [];
  List<Map<String, dynamic>> approvedDocs = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFirestoreData();
  }

  Future<void> _loadFirestoreData() async {
    try {
      // Get sample documents from pending_patient_data
      final pendingSnapshot = await FirebaseFirestore.instance
          .collection('pending_patient_data')
          .limit(3)
          .get();

      // Get sample documents from approved_appointments
      final approvedSnapshot = await FirebaseFirestore.instance
          .collection('approved_appointments')
          .limit(3)
          .get();

      setState(() {
        pendingDocs = pendingSnapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList();
        approvedDocs = approvedSnapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList();
        isLoading = false;
      });

      // Print to debug console
      print('=== PENDING PATIENT DATA FIELDS ===');
      for (var doc in pendingDocs) {
        print('Document ID: ${doc['id']}');
        print('Fields: ${doc.keys.toList()}');
        print('---');
      }

      print('=== APPROVED APPOINTMENTS FIELDS ===');
      for (var doc in approvedDocs) {
        print('Document ID: ${doc['id']}');
        print('Fields: ${doc.keys.toList()}');
        print('---');
      }
    } catch (e) {
      print('Error loading Firestore data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firestore Debug'),
        backgroundColor: Colors.teal,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pending Patient Data Fields:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  ...pendingDocs.map((doc) => Card(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('ID: ${doc['id']}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 5),
                              Text(
                                  'Fields: ${doc.keys.where((key) => key != 'id').join(', ')}'),
                            ],
                          ),
                        ),
                      )),
                  const SizedBox(height: 20),
                  const Text(
                    'Approved Appointments Fields:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  ...approvedDocs.map((doc) => Card(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('ID: ${doc['id']}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 5),
                              Text(
                                  'Fields: ${doc.keys.where((key) => key != 'id').join(', ')}'),
                            ],
                          ),
                        ),
                      )),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _loadFirestoreData,
                    child: const Text('Refresh Data'),
                  ),
                ],
              ),
            ),
    );
  }
}
