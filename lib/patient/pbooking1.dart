// Core Flutter imports
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// Dart imports
import 'dart:async';
import 'dart:typed_data';
import 'dart:io' show File;
import 'dart:js' as js;
import 'dart:html' as html;
import 'dart:convert';

// Package imports
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Local imports
import 'package:tb_frontend/models/doctor.dart';

class Pbooking1 extends StatefulWidget {
  final Doctor doctor;

  const Pbooking1({
    super.key,
    required this.doctor,
  });

  @override
  State<Pbooking1> createState() => _Pbooking1State();
}

class _Pbooking1State extends State<Pbooking1> {
  // Controllers for patient details
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();

  // Dropdown selections
  String? _selectedGender;
  String? _selectedID;
  DateTime? _selectedDate;
  String? _selectedTime;

  // Image for ID upload
  XFile? _idImage;
  Uint8List? _webImage;

  // Sample data
  final List<String> _genders = ['Male', 'Female'];
  final List<String> _validIDs = [
    'PhilHealth ID',
    'SSS ID',
    'GSIS ID',
    'Driver\'s License',
    'PRC License',
    'UMID',
    'Voter\'s ID',
    'Barangay ID'
  ];

  final List<String> _timeSlots = [
    '08:00 AM',
    '09:00 AM',
    '10:00 AM',
    '11:00 AM',
    '01:00 PM',
    '02:00 PM',
    '03:00 PM',
    '04:00 PM',
  ];

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource
            .gallery, // Changed to gallery for better web compatibility
        imageQuality: 80,
      );

      if (image != null) {
        if (kIsWeb) {
          // For web platform
          final bytes = await image.readAsBytes();
          setState(() {
            _idImage = image;
            _webImage = bytes;
          });
        } else {
          // For mobile platforms
          setState(() {
            _idImage = image;
            _webImage = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickDate() async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );

    if (date != null) {
      setState(() {
        _selectedDate = date;
      });
    }
  }

  Future<void> _submitBooking() async {
    // Validate all fields
    if (_selectedDate == null ||
        _selectedTime == null ||
        _nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _ageController.text.isEmpty ||
        _selectedGender == null ||
        _selectedID == null ||
        _idImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields and upload ID')),
      );
      return;
    }

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        },
      );

      if (!kIsWeb) {
        throw Exception(
            'This feature is currently only supported on web platform');
      }

      debugPrint('Starting Cloudinary upload...');

      final completer = Completer<String>();

      try {
        // Create a FormData object
        final formData = html.FormData();

        // Convert XFile to Blob
        final bytes = await _idImage!.readAsBytes();
        final blob = html.Blob([bytes]);

        // Add the file to form data
        formData.appendBlob(
          'file',
          blob,
          _idImage!.name,
        );

        // Add upload preset
        formData.append('upload_preset', 'uploads');

        // Show upload progress in the loading dialog
        if (context.mounted) {
          Navigator.of(context).pop(); // Remove the simple loading indicator
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return Dialog(
                backgroundColor: Colors.white,
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 10),
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).primaryColor,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Uploading ID Image',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Please wait while we process your ID...',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              );
            },
          );
        }

        // Make the upload request
        final xhr = html.HttpRequest();
        xhr.open(
            'POST', 'https://api.cloudinary.com/v1_1/ddjraogpj/image/upload');

        xhr.upload.onProgress.listen((event) {
          if (event.lengthComputable) {
            if (event.total != null && event.loaded != null) {
              final percentComplete = (event.loaded! / event.total!) * 100;
              debugPrint(
                  'Upload progress: ${percentComplete.toStringAsFixed(2)}%');
            }
          }
        });

        xhr.onLoad.listen((event) {
          if (xhr.status == 200 && xhr.responseText != null) {
            final response = json.decode(xhr.responseText!);
            final secureUrl = response['secure_url'] as String;
            debugPrint('Upload successful: $secureUrl');
            completer.complete(secureUrl);
          } else {
            completer.completeError(
                'Upload failed: ${xhr.statusText ?? 'Unknown error'}');
          }
        });

        xhr.onError.listen((event) {
          completer.completeError(
              'Upload failed: ${xhr.statusText ?? 'Unknown error'}');
        });

        xhr.send(formData);
      } catch (e) {
        debugPrint('Error creating upload widget: $e');
        throw Exception('Failed to initialize image upload: $e');
      }

      // Wait for the upload to complete
      final idImageUrl = await completer.future;

      // Get current user's UID
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not logged in. Please log in and try again.');
      }

      // Create appointment data
      final appointmentData = {
        'patientUid': currentUser.uid, // Add the UID here
        'patientName': _nameController.text.trim(),
        'patientEmail': _emailController.text.trim(),
        'patientPhone': _phoneController.text.trim(),
        'patientAge': int.parse(_ageController.text),
        'patientGender': _selectedGender,
        'idType': _selectedID,
        'idImageUrl': idImageUrl,
        'appointmentDate': Timestamp.fromDate(_selectedDate!),
        'appointmentTime': _selectedTime,
        'status': 'pending',
        'doctorId': widget.doctor.id,
        'doctorName': widget.doctor.name,
        'doctorSpecialization': widget.doctor.specialization,
        'facility': widget.doctor.facility,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      debugPrint('Preparing to save appointment data: $appointmentData');

      // Save to Firestore with explicit collection creation
      final firestore = FirebaseFirestore.instance;
      final pendingCollection = firestore.collection('pending_patient_data');

      try {
        // First, try to create the collection by adding the first document
        await pendingCollection.add(appointmentData);
        debugPrint('Successfully created appointment in pending_patient_data');
      } catch (e) {
        debugPrint('Error creating appointment: $e');
        throw Exception('Failed to create appointment. Please try again.');
      }

      // Close loading dialog
      Navigator.of(context).pop();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Booking submitted successfully! Please wait for doctor\'s confirmation.'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate back
      Navigator.of(context).pop();
    } catch (e) {
      // Close loading dialog if it's showing
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e is Exception
                ? e.toString()
                : 'Error submitting booking. Please check your internet connection and try again.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // Custom Input Decoration
  Widget _customTextField(TextEditingController controller, String label,
      {TextInputType keyboardType = TextInputType.text}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        ),
      ),
    );
  }

  // Custom Dropdown
  Widget _customDropdown<T>(
      {required T? value,
      required String label,
      required List<T> items,
      required Function(T?) onChanged}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonFormField<T>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 0, vertical: 16),
        ),
        items: items
            .map((item) => DropdownMenuItem(
                  value: item,
                  child: Text(item.toString()),
                ))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F5),
      body: SingleChildScrollView(
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16), // ✅ Global margin
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 40, 0, 8),
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
                        icon: const Icon(Icons.arrow_back,
                            color: Color(0xE0F44336)),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const Text(
                      "Book Appointment",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xE0F44336),
                      ),
                    ),
                    const SizedBox(width: 48), // spacing balance
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // SELECT DATE
              const Center(
                child: Text(
                  'Select Date',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade300,
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _selectedDate == null
                            ? 'Select date'
                            : '${_selectedDate!.month}/${_selectedDate!.day}/${_selectedDate!.year}',
                      ),
                      const Icon(Icons.calendar_today, color: Colors.redAccent),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // SELECT TIME
              const Center(
                child: Text(
                  'Available Slots',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _timeSlots.map((time) {
                  final isSelected = _selectedTime == time;
                  return ChoiceChip(
                    label: Text(time),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() {
                        _selectedTime = time;
                      });
                    },
                    selectedColor: Colors.redAccent,
                    backgroundColor: Colors.grey.shade200,
                    labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // PATIENT DETAILS
              const Center(
                child: Text(
                  'Patient Details',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const SizedBox(height: 8),
              _customTextField(_nameController, 'Full Name'),
              const SizedBox(height: 12),
              _customTextField(_emailController, 'Email',
                  keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 12),
              _customTextField(_phoneController, 'Phone Number',
                  keyboardType: TextInputType.phone),
              const SizedBox(height: 12),
              _customDropdown<String>(
                value: _selectedGender,
                label: 'Gender',
                items: _genders,
                onChanged: (value) => setState(() => _selectedGender = value),
              ),
              const SizedBox(height: 12),
              _customTextField(_ageController, 'Age',
                  keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              _customDropdown<String>(
                value: _selectedID,
                label: 'Valid ID',
                items: _validIDs,
                onChanged: (value) => setState(() => _selectedID = value),
              ),
              const SizedBox(height: 20),

              // Upload ID
              const Center(
                child: Text(
                  'Upload Valid ID (Capture Photo)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade300,
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: _idImage == null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.add_photo_alternate,
                                  size: 40, color: Colors.grey),
                              const SizedBox(height: 8),
                              Text(
                                'Tap to Upload ID',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                      : Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: kIsWeb
                                  ? Image.memory(
                                      _webImage!,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return const Center(
                                          child: Text('Error loading image'),
                                        );
                                      },
                                    )
                                  : Image.file(
                                      File(_idImage!.path),
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return const Center(
                                          child: Text('Error loading image'),
                                        );
                                      },
                                    ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _idImage = null;
                                    _webImage = null;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 20),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitBooking,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Confirm Booking',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
