import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
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

  // Image file for ID upload
  File? _idImage;

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
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );

    if (image != null) {
      setState(() {
        _idImage = File(image.path);
      });
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

  void _submitBooking() {
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

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Booking submitted successfully!')),
    );
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
                      ? const Center(
                          child: Icon(Icons.camera_alt,
                              size: 40, color: Colors.grey),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(_idImage!, fit: BoxFit.cover),
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
