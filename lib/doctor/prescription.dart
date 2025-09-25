import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/rendering.dart';

class Prescription extends StatefulWidget {
  final Map<String, dynamic> appointment;
  
  const Prescription({super.key, required this.appointment});

  @override
  State<Prescription> createState() => _PrescriptionState();
}

class _PrescriptionState extends State<Prescription> {
  final TextEditingController _prescriptionController = TextEditingController();
  bool _isLoading = false;
  bool _hasExistingPrescription = false;
  Map<String, dynamic>? _doctorData;
  String? _doctorSignature;
  
  // Define theme color
  final Color _themeRed = const Color(0xFFF94F6D);

  @override
  void initState() {
    super.initState();
    _loadExistingPrescription();
    _loadDoctorData();
  }

  Future<void> _loadDoctorData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final docSnapshot = await FirebaseFirestore.instance
          .collection('doctors')
          .doc(user.uid)
          .get();
          
      if (docSnapshot.exists && mounted) {
        setState(() {
          _doctorData = docSnapshot.data();
        });
      }
      
      // Load doctor signature
      await _loadDoctorSignature();
    } catch (e) {
      debugPrint('Error loading doctor data: $e');
    }
  }
  
  Future<void> _loadDoctorSignature() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final signatureDoc = await FirebaseFirestore.instance
          .collection('doctor_signatures')
          .doc(user.uid)
          .get();
          
      if (signatureDoc.exists && mounted) {
        final data = signatureDoc.data()!;
        setState(() {
          if (data['signatureType'] == 'text') {
            _doctorSignature = 'text:${data['signatureText']}';
          } else if (data['signatureType'] == 'drawn') {
            _doctorSignature = data['signatureData'];
          } else {
            _doctorSignature = data['signatureUrl'];
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading doctor signature: $e');
    }
  }
  
  String _getDoctorFacilityName() {
    if (_doctorData == null) return 'Medical Center';
    
    // Get the first affiliation's name or fallback to a default
    if (_doctorData!['affiliations'] != null && 
        (_doctorData!['affiliations'] as List).isNotEmpty) {
      return _doctorData!['affiliations'][0]['name'] ?? 'Medical Center';
    }
    return 'Medical Center';
  }
  
  String _getDoctorInfo() {
    if (_doctorData == null) return 'Address loading...';
    
    String address = 'Address not available';
    
    // Get address from affiliations
    if (_doctorData!['affiliations'] != null && 
        (_doctorData!['affiliations'] as List).isNotEmpty) {
      address = _doctorData!['affiliations'][0]['address'] ?? 'Address not available';
    }
    
    return address;
  }
  
  String _getDoctorName() {
    if (_doctorData == null) return 'Doctor Name';
    return 'Dr. ${_doctorData!['fullName'] ?? 'Doctor'}';
  }
  
  String _getDoctorLicense() {
    if (_doctorData == null) return 'License No: N/A';
    return 'License No: ${_doctorData!['license'] ?? 'N/A'}';
  }
  
  void _showSignatureDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.7,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 5,
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Doctor\'s E-Signature',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Color(0xFF718096)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Current signature display (if exists)
                if (_doctorSignature != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Current Signature:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4A5568),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 80,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: _doctorSignature!.startsWith('text:')
                              ? Center(
                                  child: Text(
                                    _doctorSignature!.substring(5),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontStyle: FontStyle.italic,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF2D3748),
                                    ),
                                  ),
                                )
                              : _doctorSignature!.startsWith('data:image')
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.memory(
                                        base64Decode(_doctorSignature!.split(',')[1]),
                                        fit: BoxFit.contain,
                                      ),
                                    )
                                  : Image.network(
                                      _doctorSignature!,
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stackTrace) {
                                        return const Center(
                                          child: Text(
                                            'Signature not available',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF718096),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                
                // Action buttons
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Create/Draw signature button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _showDrawSignatureDialog();
                          },
                          icon: const Icon(Icons.draw, color: Colors.white),
                          label: Text(
                            _doctorSignature == null ? 'Create Signature' : 'Draw New Signature',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF94F6D),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Text signature button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _createTextSignature();
                          },
                          icon: const Icon(Icons.text_fields, color: Color(0xFFF94F6D)),
                          label: Text(
                            _doctorSignature == null ? 'Use Text Signature' : 'Change to Text',
                            style: const TextStyle(
                              color: Color(0xFFF94F6D),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(color: Color(0xFFF94F6D), width: 2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  void _showDrawSignatureDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.95,
            height: MediaQuery.of(context).size.height * 0.8,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: SignaturePadDialog(
              onSave: (signatureData) async {
                Navigator.of(context).pop();
                await _saveDrawnSignature(signatureData);
              },
              onCancel: () {
                Navigator.of(context).pop();
              },
            ),
          ),
        );
      },
    );
  }
  
  void _createTextSignature() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Text Signature',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'This will use your name as the signature text.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF718096),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Color(0xFF718096)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _saveTextSignature();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF94F6D),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Create',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Future<void> _saveDrawnSignature(String signatureData) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      // Save the drawn signature as base64 data
      await FirebaseFirestore.instance
          .collection('doctor_signatures')
          .doc(user.uid)
          .set({
        'signatureData': signatureData,
        'signatureType': 'drawn',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      setState(() {
        _doctorSignature = signatureData;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Signature saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving signature: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _saveTextSignature() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || _doctorData == null) return;
      
      String doctorName = _doctorData!['fullName'] ?? 'Doctor';
      
      // Save a text-based signature for now
      await FirebaseFirestore.instance
          .collection('doctor_signatures')
          .doc(user.uid)
          .set({
        'signatureText': 'Dr. $doctorName',
        'signatureType': 'text',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      setState(() {
        _doctorSignature = 'text:Dr. $doctorName';
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Text signature saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving signature: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadExistingPrescription() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('prescriptions')
          .where('appointmentId', isEqualTo: widget.appointment['appointmentId'])
          .get();

      if (snapshot.docs.isNotEmpty && mounted) {
        final prescriptionData = snapshot.docs.first.data();
        _prescriptionController.text = prescriptionData['prescriptionDetails'] ?? '';
        setState(() {
          _hasExistingPrescription = true;
        });
      }
    } catch (e) {
      debugPrint('Error loading existing prescription: $e');
    }
  }

  @override
  void dispose() {
    _prescriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Extract appointment data for display
    String patientName = widget.appointment['patientName'] ?? 'N/A';
    String patientAge = widget.appointment['patientAge']?.toString() ?? 'N/A';
    String patientGender = widget.appointment['patientGender'] ?? 'N/A';
    String patientAddress = widget.appointment['patientAddress'] ?? 'N/A';
    
    // Format current date (when prescription is opened)
    final currentDate = DateTime.now();
    String prescriptionDate = '${currentDate.day}/${currentDate.month}/${currentDate.year}';

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      // Explicitly set bottomNavigationBar to null to ensure no navigation bar is shown
      bottomNavigationBar: null,
      // Ensure the screen takes full screen space
      extendBodyBehindAppBar: true,
      // Remove app bar to use custom header
      appBar: null,
      body: Column(
        children: [
          // --- Custom Header ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Back Button
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade300,
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: Icon(Icons.arrow_back, color: _themeRed),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),

                Text(
                  "E-Prescription",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _themeRed,
                  ),
                ),

                const SizedBox(width: 48), // spacing balance
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.redAccent, width: 1),
                ),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Column(
                        children: [
                          Text(
                            _getDoctorFacilityName(),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getDoctorInfo(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 32, color: Colors.redAccent),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Name: $patientName'),
                              const SizedBox(height: 8),
                              Text('Address: $patientAddress'),
                              const SizedBox(height: 8),
                              Text('Age: $patientAge'),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Gender: $patientGender'),
                            const SizedBox(height: 8),
                            Text('Date: $prescriptionDate'),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Rx',
                      style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    // Prescription text field
                    Container(
                      height: 150,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextField(
                        controller: _prescriptionController,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        decoration: const InputDecoration(
                          hintText: 'Enter prescription details here...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (_doctorSignature != null) ...[
                          const Text("Doctor's e-Signature: "),
                          Container(
                            height: 30,
                            width: 120,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: _doctorSignature!.startsWith('text:')
                                ? Center(
                                    child: Text(
                                      _doctorSignature!.substring(5),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  )
                                : _doctorSignature!.startsWith('data:image')
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: Image.memory(
                                          base64Decode(_doctorSignature!.split(',')[1]),
                                          fit: BoxFit.contain,
                                        ),
                                      )
                                    : Image.network(
                                        _doctorSignature!,
                                        fit: BoxFit.contain,
                                        errorBuilder: (context, error, stackTrace) {
                                          return const Center(
                                            child: Text(
                                              'Signature',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                          );
                                        },
                                      ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 16, color: Colors.grey),
                            onPressed: _showSignatureDialog,
                          ),
                        ] else ...[
                          const Text("Doctor's e-Signature: ____________"),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 16, color: Colors.grey),
                            onPressed: _showSignatureDialog,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Doctor's name and license below signature
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _getDoctorName(),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _getDoctorLicense(),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color.fromARGB(255, 149, 149, 149),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF94F6D),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _isLoading ? null : _savePrescription,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          _hasExistingPrescription ? 'Update Prescription' : 'Save Prescription',
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Future<void> _savePrescription() async {
    if (_prescriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter prescription details'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_hasExistingPrescription) {
        // Update existing prescription
        final snapshot = await FirebaseFirestore.instance
            .collection('prescriptions')
            .where('appointmentId', isEqualTo: widget.appointment['appointmentId'])
            .get();
        
        if (snapshot.docs.isNotEmpty) {
          await snapshot.docs.first.reference.update({
            'prescriptionDetails': _prescriptionController.text.trim(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      } else {
        // Create new prescription
        await FirebaseFirestore.instance.collection('prescriptions').add({
          'appointmentId': widget.appointment['appointmentId'],
          'patientId': widget.appointment['patientId'],
          'doctorId': widget.appointment['doctorId'],
          'patientName': widget.appointment['patientName'],
          'prescriptionDetails': _prescriptionController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
          'appointmentDate': widget.appointment['appointmentDate'],
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_hasExistingPrescription 
              ? 'Prescription updated successfully!' 
              : 'Prescription saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving prescription: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

// Custom Signature Pad Widget
class SignaturePadDialog extends StatefulWidget {
  final Function(String) onSave;
  final VoidCallback onCancel;
  
  const SignaturePadDialog({
    super.key,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<SignaturePadDialog> createState() => _SignaturePadDialogState();
}

class _SignaturePadDialogState extends State<SignaturePadDialog> {
  final GlobalKey _signatureKey = GlobalKey();
  List<List<Offset?>> _paths = [];
  List<Offset?> _currentPath = [];
  bool _isDrawing = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Draw Your Signature',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3748),
              ),
            ),
            IconButton(
              onPressed: widget.onCancel,
              icon: const Icon(Icons.close, color: Color(0xFF718096)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Use your finger or stylus to draw your signature below',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF718096),
          ),
        ),
        const SizedBox(height: 20),
        
        // Signature Canvas
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: GestureDetector(
                onPanStart: (details) {
                  setState(() {
                    _isDrawing = true;
                    _currentPath = [];
                    RenderBox renderBox = context.findRenderObject() as RenderBox;
                    Offset localPosition = renderBox.globalToLocal(details.globalPosition);
                    _currentPath.add(localPosition);
                  });
                },
                onPanUpdate: (details) {
                  if (_isDrawing) {
                    setState(() {
                      RenderBox renderBox = context.findRenderObject() as RenderBox;
                      Offset localPosition = renderBox.globalToLocal(details.globalPosition);
                      _currentPath.add(localPosition);
                    });
                  }
                },
                onPanEnd: (details) {
                  setState(() {
                    _isDrawing = false;
                    _paths.add(List.from(_currentPath));
                    _currentPath = [];
                  });
                },
                child: RepaintBoundary(
                  key: _signatureKey,
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: Colors.white,
                    child: CustomPaint(
                      painter: SignaturePainter(
                        paths: _paths,
                        currentPath: _currentPath,
                      ),
                      size: Size.infinite,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Action buttons
        Row(
          children: [
            // Clear button
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _clearSignature,
                icon: const Icon(Icons.clear, color: Color(0xFF718096)),
                label: const Text(
                  'Clear',
                  style: TextStyle(color: Color(0xFF718096)),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            
            // Cancel button
            Expanded(
              child: OutlinedButton(
                onPressed: widget.onCancel,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Color(0xFF718096)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Color(0xFF718096)),
                ),
              ),
            ),
            const SizedBox(width: 16),
            
            // Save button
            Expanded(
              child: ElevatedButton(
                onPressed: _paths.isEmpty ? null : _saveSignature,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF94F6D),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: const Text(
                  'Save',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _clearSignature() {
    setState(() {
      _paths.clear();
      _currentPath.clear();
    });
  }

  Future<void> _saveSignature() async {
    try {
      // Get the RenderRepaintBoundary from the signature canvas
      RenderRepaintBoundary boundary = _signatureKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      
      // Convert to image
      ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData != null) {
        Uint8List uint8List = byteData.buffer.asUint8List();
        String base64String = base64Encode(uint8List);
        String signatureData = 'data:image/png;base64,$base64String';
        
        widget.onSave(signatureData);
      }
    } catch (e) {
      debugPrint('Error saving signature: $e');
    }
  }
}

// Custom Painter for drawing signature
class SignaturePainter extends CustomPainter {
  final List<List<Offset?>> paths;
  final List<Offset?> currentPath;

  SignaturePainter({
    required this.paths,
    required this.currentPath,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = const Color(0xFF2D3748)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // Draw completed paths
    for (List<Offset?> path in paths) {
      _drawPath(canvas, path, paint);
    }

    // Draw current path
    if (currentPath.isNotEmpty) {
      _drawPath(canvas, currentPath, paint);
    }
  }

  void _drawPath(Canvas canvas, List<Offset?> path, Paint paint) {
    if (path.length < 2) return;

    for (int i = 0; i < path.length - 1; i++) {
      if (path[i] != null && path[i + 1] != null) {
        canvas.drawLine(path[i]!, path[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
