import 'package:cloud_firestore/cloud_firestore.dart';

/// Service to manage patient aliases for healthcare workers
/// Healthcare workers can give patients privacy-friendly names like "Patient 1", "Patient 2", etc.
class AliasService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get the alias that a healthcare worker uses for a specific patient
  /// Returns null if no alias exists yet
  Future<String?> getPatientAlias({
    required String healthcareId,
    required String patientId,
  }) async {
    try {
      final docId = '${healthcareId}_$patientId';
      final doc = await _firestore
          .collection('patient_aliases')
          .doc(docId)
          .get();

      if (doc.exists) {
        return doc.data()?['alias'] as String?;
      }
      return null;
    } catch (e) {
      print('Error getting patient alias: $e');
      return null;
    }
  }

  /// Auto-generate the next available patient number for a healthcare worker
  /// Returns "Patient 1", "Patient 2", etc.
  Future<String> _generateNextPatientNumber(String healthcareId) async {
    try {
      // Get all existing aliases for this healthcare worker
      final querySnapshot = await _firestore
          .collection('patient_aliases')
          .where('healthcareId', isEqualTo: healthcareId)
          .get();

      // Find the highest patient number
      int maxNumber = 0;
      for (var doc in querySnapshot.docs) {
        final alias = doc.data()['alias'] as String?;
        if (alias != null && alias.startsWith('Patient ')) {
          final numberStr = alias.replaceFirst('Patient ', '');
          final number = int.tryParse(numberStr);
          if (number != null && number > maxNumber) {
            maxNumber = number;
          }
        }
      }

      return 'Patient ${maxNumber + 1}';
    } catch (e) {
      print('Error generating patient number: $e');
      return 'Patient 1';
    }
  }

  /// Get or create an alias for a patient
  /// If no alias exists, automatically generates "Patient X"
  Future<String> getOrCreatePatientAlias({
    required String healthcareId,
    required String patientId,
  }) async {
    try {
      // Check if alias already exists
      final existingAlias = await getPatientAlias(
        healthcareId: healthcareId,
        patientId: patientId,
      );

      if (existingAlias != null) {
        return existingAlias;
      }

      // Generate new alias
      final newAlias = await _generateNextPatientNumber(healthcareId);

      // Save to Firestore
      final docId = '${healthcareId}_$patientId';
      await _firestore.collection('patient_aliases').doc(docId).set({
        'alias': newAlias,
        'healthcareId': healthcareId,
        'patientId': patientId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return newAlias;
    } catch (e) {
      print('Error creating patient alias: $e');
      return 'Patient';
    }
  }

  /// Update an existing patient alias (allows healthcare workers to rename patients)
  Future<bool> updatePatientAlias({
    required String healthcareId,
    required String patientId,
    required String newAlias,
  }) async {
    try {
      if (newAlias.trim().isEmpty) {
        print('❌ ALIAS_SERVICE - Empty alias provided');
        return false;
      }

      final docId = '${healthcareId}_$patientId';
      print('🔍 ALIAS_SERVICE - Updating alias');
      print('🔍 Healthcare ID: $healthcareId');
      print('🔍 Patient ID: $patientId');
      print('🔍 New Alias: ${newAlias.trim()}');
      print('🔍 Document ID: $docId');
      
      await _firestore.collection('patient_aliases').doc(docId).set({
        'alias': newAlias.trim(),
        'healthcareId': healthcareId,
        'patientId': patientId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('✅ ALIAS_SERVICE - Alias updated successfully!');
      return true;
    } catch (e) {
      print('❌ ALIAS_SERVICE - Error updating patient alias: $e');
      return false;
    }
  }

  /// Get all aliases for a healthcare worker
  Future<Map<String, String>> getAllAliasesForHealthcare(
      String healthcareId) async {
    try {
      final querySnapshot = await _firestore
          .collection('patient_aliases')
          .where('healthcareId', isEqualTo: healthcareId)
          .get();

      final aliases = <String, String>{};
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final patientId = data['patientId'] as String?;
        final alias = data['alias'] as String?;
        if (patientId != null && alias != null) {
          aliases[patientId] = alias;
        }
      }

      return aliases;
    } catch (e) {
      print('Error getting all aliases: $e');
      return {};
    }
  }

  /// Stream of a specific patient's alias (real-time updates)
  Stream<String?> streamPatientAlias({
    required String healthcareId,
    required String patientId,
  }) {
    final docId = '${healthcareId}_$patientId';
    print('🔍 ALIAS_SERVICE - Setting up stream for docId: $docId');
    print('🔍 ALIAS_SERVICE - Healthcare ID: $healthcareId');
    print('🔍 ALIAS_SERVICE - Patient ID: $patientId');
    print('🔍 ALIAS_SERVICE - Collection: patient_aliases');
    
    return _firestore
        .collection('patient_aliases')
        .doc(docId)
        .snapshots()
        .map((doc) {
      print('🔍 ALIAS_SERVICE - Document snapshot received');
      print('🔍 ALIAS_SERVICE - Doc exists: ${doc.exists}');
      
      if (doc.exists) {
        final alias = doc.data()?['alias'] as String?;
        print('🔍 ALIAS_SERVICE - Alias value: $alias');
        return alias;
      }
      print('🔍 ALIAS_SERVICE - No document found, returning null');
      return null;
    });
  }
}
