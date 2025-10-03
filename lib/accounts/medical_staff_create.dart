import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/tb_dots_facilities.dart' show TBDotsFacility, tbDotsFacilities;
import './medical_staff_confirmation.dart';

class MedicalStaffCreatePage extends StatefulWidget {
  const MedicalStaffCreatePage({super.key});

  @override
  State<MedicalStaffCreatePage> createState() => _MedicalStaffCreatePageState();
}

class _MedicalStaffCreatePageState extends State<MedicalStaffCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _specializationController = TextEditingController();
  final _facilityController = TextEditingController();

  String _selectedRole = 'Doctor'; // Default role
  List<Map<String, dynamic>> affiliations = [];
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  void _showAddAffiliationDialog() {
    TBDotsFacility? selectedFacility;
    List<Map<String, String>> schedules = [];

    void addScheduleDialog(StateSetter setModalState) {
      final scheduleDayCtrl = TextEditingController();
      TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
      TimeOfDay endTime = const TimeOfDay(hour: 17, minute: 0);

      showDialog(
        context: context,
        builder: (_) {
          return StatefulBuilder(
            builder: (context, setScheduleState) {
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Text(
                  "Add Schedule",
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600, color: Colors.redAccent),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: scheduleDayCtrl,
                      decoration: const InputDecoration(
                        labelText: "Day",
                        prefixIcon:
                            Icon(Icons.calendar_today, color: Colors.redAccent),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Start"),
                              TimePickerSpinner(
                                time: startTime,
                                onTimeChange: (t) =>
                                    setScheduleState(() => startTime = t),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("End"),
                              TimePickerSpinner(
                                time: endTime,
                                onTimeChange: (t) =>
                                    setScheduleState(() => endTime = t),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel"),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent),
                    onPressed: () {
                      if (scheduleDayCtrl.text.isNotEmpty) {
                        setModalState(() {
                          schedules.add({
                            "day": scheduleDayCtrl.text,
                            "start": startTime.format(context),
                            "end": endTime.format(context),
                          });
                        });
                        Navigator.pop(context);
                      }
                    },
                    child: const Text("Add"),
                  )
                ],
              );
            },
          );
        },
      );
    }

    showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                "Add Hospital/Clinic",
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, color: Colors.redAccent),
              ),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StatefulBuilder(
                      builder: (context, setDropdownState) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            DropdownButtonFormField<TBDotsFacility>(
                              initialValue: selectedFacility,
                              decoration: const InputDecoration(
                                labelText: "Select TB DOTS Facility",
                                prefixIcon: Icon(Icons.local_hospital,
                                    color: Colors.redAccent),
                                border: OutlineInputBorder(),
                              ),
                              items: tbDotsFacilities.map((facility) {
                                return DropdownMenuItem<TBDotsFacility>(
                                  value: facility,
                                  child: Text(
                                    facility.name,
                                    style: GoogleFonts.poppins(fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (TBDotsFacility? value) {
                                setDropdownState(() {
                                  selectedFacility = value;
                                });
                              },
                            ),
                            if (selectedFacility != null) ...[
                              const SizedBox(height: 16),
                              Card(
                                child: ListTile(
                                  leading: const Icon(Icons.location_on,
                                      color: Colors.redAccent),
                                  title: Text(
                                    selectedFacility!.address,
                                    style: GoogleFonts.poppins(fontSize: 14),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Schedules",
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, color: Colors.redAccent),
                    ),
                    const SizedBox(height: 6),
                    schedules.isEmpty
                        ? Text("No schedules added",
                            style: GoogleFonts.poppins(color: Colors.grey))
                        : ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 400),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columnSpacing: 16,
                                headingRowHeight: 32,
                                dataRowMinHeight: 32,
                                dataRowMaxHeight: 40,
                                columns: const [
                                  DataColumn(label: Text("Day")),
                                  DataColumn(label: Text("Start")),
                                  DataColumn(label: Text("End")),
                                ],
                                rows: schedules
                                    .map<DataRow>(
                                      (s) => DataRow(cells: [
                                        DataCell(Text(s["day"]!)),
                                        DataCell(Text(s["start"]!)),
                                        DataCell(Text(s["end"]!)),
                                      ]),
                                    )
                                    .toList(),
                              ),
                            ),
                          ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent),
                      onPressed: () => addScheduleDialog(setModalState),
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text("Add Schedule",
                          style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent),
                  onPressed: () {
                    if (selectedFacility != null && schedules.isNotEmpty) {
                      setState(() {
                        affiliations.add({
                          "name": selectedFacility!.name,
                          "address": selectedFacility!.address,
                          "email": selectedFacility!.email,
                          "latitude": selectedFacility!.latitude,
                          "longitude": selectedFacility!.longitude,
                          "schedules": schedules,
                        });
                      });
                      Navigator.pop(context);
                    }
                  },
                  child: const Text("Add"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _specializationController.dispose();
    _facilityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Medical Staff Registration',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.redAccent,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Staff Registration',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              // Full Name Field
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your full name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Role Selection Dropdown
              DropdownButtonFormField<String>(
                initialValue: _selectedRole,
                decoration: InputDecoration(
                  labelText: 'Staff Role',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: ['Doctor', 'Health Worker'].map((String role) {
                  return DropdownMenuItem(
                    value: role,
                    child: Text(role),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedRole = newValue!;
                    // Clear affiliations when switching roles
                    affiliations.clear();
                  });
                },
              ),
              const SizedBox(height: 16),

              // Email Field
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an email';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Password Field
              TextFormField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Confirm Password Field
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: !_isConfirmPasswordVisible,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isConfirmPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                      });
                    },
                  ),
                ),
                validator: (value) {
                  if (value != _passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Health Worker Facility Selection
              if (_selectedRole == 'Health Worker') ...[
                const SizedBox(height: 16),
                Text(
                  "Select TB DOTS Facility",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.redAccent,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<TBDotsFacility>(
                          decoration: const InputDecoration(
                            labelText: "Select Facility",
                            prefixIcon: Icon(Icons.local_hospital,
                                color: Colors.redAccent),
                            border: OutlineInputBorder(),
                          ),
                          items: tbDotsFacilities.map((facility) {
                            return DropdownMenuItem<TBDotsFacility>(
                              value: facility,
                              child: Text(
                                facility.name,
                                style: GoogleFonts.poppins(fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (TBDotsFacility? value) {
                            if (value != null) {
                              setState(() {
                                affiliations.clear();
                                affiliations.add({
                                  "name": value.name,
                                  "address": value.address,
                                  "email": value.email,
                                  "latitude": value.latitude,
                                  "longitude": value.longitude,
                                });
                              });
                            }
                          },
                        ),
                        if (affiliations.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const Icon(Icons.location_on,
                                  size: 18, color: Colors.grey),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  affiliations[0]["address"],
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],

              // Affiliated Hospitals section for doctors only
              if (_selectedRole == 'Doctor') ...[
                const SizedBox(height: 20),
                Row(
                  children: [
                    Text(
                      "Affiliated Clinics/Hospitals",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: Colors.redAccent,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon:
                          const Icon(Icons.add_circle, color: Colors.redAccent),
                      onPressed: _showAddAffiliationDialog,
                    )
                  ],
                ),
                affiliations.isEmpty
                    ? Text(
                        "No affiliations added yet",
                        style: GoogleFonts.poppins(color: Colors.grey),
                      )
                    : Column(
                        children: affiliations.map((a) {
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 5),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.local_hospital,
                                          size: 18, color: Colors.redAccent),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          a["name"],
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on,
                                          size: 18, color: Colors.grey),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          a["address"],
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.access_time,
                                          size: 18, color: Colors.grey),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: (a["schedules"] as List)
                                              .map<Widget>(
                                                (s) => Text(
                                                  "${s["day"]}: ${s["start"]} - ${s["end"]}",
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 14,
                                                    color: Colors.grey[800],
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
              ],
              const SizedBox(height: 24),

              // Continue Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      bool isValid = true;
                      String? errorMessage;

                      if (_selectedRole == 'Doctor') {
                        if (affiliations.isEmpty) {
                          isValid = false;
                          errorMessage = 'Please add at least one affiliation';
                        } else {
                          // Check if all affiliations have schedules
                          for (var affiliation in affiliations) {
                            if (!affiliation.containsKey('schedules')) {
                              isValid = false;
                              affiliations
                                  .clear(); // Clear invalid affiliations
                              errorMessage =
                                  'Please add affiliations with schedules';
                              break;
                            }
                          }
                        }
                      } else {
                        // Health Worker validation
                        if (affiliations.isEmpty) {
                          isValid = false;
                          errorMessage =
                              'Please select your affiliated hospital';
                        }
                      }

                      if (!isValid) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(errorMessage!),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MedicalStaffConfirmationPage(
                            email: _emailController.text.trim(),
                            password: _passwordController.text.trim(),
                            fullName: _nameController.text.trim(),
                            role: _selectedRole,
                            specialization:
                                _specializationController.text.trim(),
                            affiliations:
                                _selectedRole == 'Doctor' ? affiliations : null,
                            facility: _selectedRole == 'Health Worker' &&
                                    affiliations.isNotEmpty
                                ? affiliations[0]
                                : null,
                          ),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Continue',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TimePickerSpinner extends StatelessWidget {
  final TimeOfDay time;
  final Function(TimeOfDay) onTimeChange;

  const TimePickerSpinner({
    super.key,
    required this.time,
    required this.onTimeChange,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = GoogleFonts.poppins(
      fontSize: 16,
      fontWeight: FontWeight.w500,
    );

    return Row(
      children: [
        DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod,
            style: textStyle,
            menuMaxHeight: 300,
            items: List.generate(12, (i) => i + 1)
                .map((h) => DropdownMenuItem(value: h, child: Text("$h")))
                .toList(),
            onChanged: (v) {
              if (v != null) {
                int hour = v % 12;
                if (time.period == DayPeriod.pm) hour += 12;
                onTimeChange(TimeOfDay(hour: hour, minute: time.minute));
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        Text(":", style: textStyle),
        const SizedBox(width: 8),
        DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: time.minute,
            style: textStyle,
            menuMaxHeight: 300,
            items: List.generate(60, (i) => i)
                .map((m) => DropdownMenuItem(
                    value: m, child: Text(m.toString().padLeft(2, "0"))))
                .toList(),
            onChanged: (v) {
              if (v != null) {
                onTimeChange(TimeOfDay(hour: time.hour, minute: v));
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: time.period == DayPeriod.am ? "AM" : "PM",
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            menuMaxHeight: 200,
            items: ["AM", "PM"]
                .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                .toList(),
            onChanged: (v) {
              if (v != null) {
                int hour = time.hour;
                if (v == "AM" && hour >= 12) hour -= 12;
                if (v == "PM" && hour < 12) hour += 12;
                onTimeChange(TimeOfDay(hour: hour, minute: time.minute));
              }
            },
          ),
        ),
      ],
    );
  }
}
