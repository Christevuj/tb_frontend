import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  // Facility management
  Map<String, String> facilities = {};
  bool isLoadingFacilities = true;

  @override
  void initState() {
    super.initState();
    _loadFacilities();
  }

  // Load facilities from Firebase
  Future<void> _loadFacilities() async {
    try {
      final facilitiesSnapshot =
          await FirebaseFirestore.instance.collection('facilities').get();

      Map<String, String> loadedFacilities = {};
      for (var doc in facilitiesSnapshot.docs) {
        final data = doc.data();
        loadedFacilities[data['name'] ?? doc.id] =
            data['address'] ?? 'Address not available';
      }

      // If no facilities found in Firebase, add some default TB DOTS facilities
      if (loadedFacilities.isEmpty) {
        loadedFacilities = {
          'AGDAO':
              'Agdao Public Market Corner Lapu-Lapu & C. Bangoy St., Agdao, Davao City',
          'BAGUIO': 'Baguio District Health Center, Davao City',
          'BUHANGIN (NHA BUHANGIN HC)': 'NHA Chapet St., Buhangin, Davao City',
          'BUNAWAN': 'Bunawan District Health Center, Davao City',
          'CALINAN': 'P34, Aurora St., Calinan, Davao City',
          'DAVAO CHEST CENTER': 'Villa Abrille St., Brgy 30-C, Davao City',
          'DISTRICT A (TOMAS CLAUDIO HC)':
              'Camus Ext., Corner Quirino Ave., Davao City',
          'DISTRICT B (EL RIO HC)': 'Garcia Heights, Bajada, Davao City',
          'DISTICT C (MINIFOREST HC)':
              'Brgy 23-C, Quezon Boulevard, Davao City',
          'DISTRICT D (JACINTO HC)': 'Emilio Jacinto St., Davao City',
          'MARILOG (MARAHAN HC)': 'Sitio Marahan, Brgy. Marilog, Davao City',
          'PAQUIBATO (MALABOG HC)': 'Brgy Malabog, Davao City',
          'SASA': 'Bangoy Km 9, Sasa, Davao City',
          'TALOMO CENTRAL (GSIS HC)': 'GSIS Village, Matina, Davao City',
          'TALOMO NORTH (SIR HC)':
              'Daang Patnubay St., SIR Ph-1, Sandawa, Davao City',
          'TALOMO SOUTH (PUAN HC)': 'Puan, Talomo, Davao City',
          'TORIL A': 'Agton St., Toril, Davao City',
          'TORIL B': 'Juan Dela Cruz St., Daliao, Toril, Davao City',
          'TUGBOK': 'Sampaguita St., Mintal, Tugbok District, Davao City',
        };

        // Seed these defaults into Firestore so other app lists (eg. pdoclist.dart) pick them up
        try {
          final batch = FirebaseFirestore.instance.batch();
          final col = FirebaseFirestore.instance.collection('facilities');
          loadedFacilities.forEach((name, address) {
            final docRef = col.doc();
            batch.set(docRef, {'name': name, 'address': address});
          });
          await batch.commit();
          debugPrint('Seeded default facilities into Firestore');
        } catch (e) {
          debugPrint('Error seeding facilities to Firestore: $e');
        }
      }

      if (mounted) {
        setState(() {
          facilities = loadedFacilities;
          isLoadingFacilities = false;
        });
      }
    } catch (e) {
      // Fallback to default TB DOTS facilities if Firebase fails
      if (mounted) {
        setState(() {
          isLoadingFacilities = false;
          facilities = {
            'AGDAO':
                'Agdao Public Market Corner Lapu-Lapu & C. Bangoy St., Agdao, Davao City',
            'BAGUIO': 'Baguio District Health Center, Davao City',
            'BUNAWAN': 'Bunawan District Health Center, Davao City',
            'CALINAN': 'P34, Aurora St., Calinan, Davao City',
            'DAVAO CHEST CENTER': 'Villa Abrille St., Brgy 30-C, Davao City',
            'DISTRICT A (TOMAS CLAUDIO HC)':
                'Camus Ext., Corner Quirino Ave., Davao City',
            'DISTRICT B (EL RIO HC)': 'Garcia Heights, Bajada, Davao City',
            'DISTICT C (MINIFOREST HC)':
                'Brgy 23-C, Quezon Boulevard, Davao City',
            'DISTRICT D (JACINTO HC)': 'Emilio Jacinto St., Davao City',
            'MARILOG (MARAHAN HC)': 'Sitio Marahan, Brgy. Marilog, Davao City',
            'PAQUIBATO (MALABOG HC)': 'Brgy Malabog, Davao City',
            'SASA': 'Bangoy Km 9, Sasa, Davao City',
            'TALOMO CENTRAL (GSIS HC)': 'GSIS Village, Matina, Davao City',
            'TALOMO NORTH (SIR HC)':
                'Daang Patnubay St., SIR Ph-1, Sandawa, Davao City',
            'TALOMO SOUTH (PUAN HC)': 'Puan, Talomo, Davao City',
          };
        });
      }
    }
  }

  void _showAddAffiliationDialog() {
    String? selectedFacility;
    String facilityAddress = '';

    // DEFAULT SCHEDULE: Monday to Friday, 9 AM - 5 PM, Break 11 AM - 12 PM, 30 min sessions
    List<Map<String, String>> schedules = [
      {
        "day": "Monday",
        "start": "9:00 AM",
        "end": "5:00 PM",
        "breakStart": "11:00 AM",
        "breakEnd": "12:00 PM",
        "sessionDuration": "30",
        "isRange": "true",
        "endDay": "Friday",
      }
    ];

    const List<String> days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];

    // Helper method to build time picker with hour, minute, and AM/PM dropdowns
    Widget buildTimePicker(String currentTime, Function(String) onTimeChanged,
        StateSetter setState) {
      // Parse current time or use default format 00:00 AM
      final parts = currentTime.split(' ');
      final timePart = parts[0];
      final period = parts.length > 1 ? parts[1] : 'AM';
      final timeParts = timePart.split(':');
      final hour = timeParts[0];
      final minute = timeParts.length > 1 ? timeParts[1] : '00';

      return Row(
        children: [
          // Hour text field
          Expanded(
            flex: 2,
            child: TextFormField(
              initialValue: hour.padLeft(2, '0'),
              decoration: InputDecoration(
                labelText: 'Hour',
                labelStyle: GoogleFonts.poppins(fontSize: 11),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Colors.redAccent),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                isDense: true,
              ),
              style: GoogleFonts.poppins(fontSize: 13),
              keyboardType: TextInputType.number,
              maxLength: 2,
              buildCounter: (context,
                      {required currentLength,
                      required isFocused,
                      maxLength}) =>
                  null,
              onChanged: (value) {
                if (value.isNotEmpty && int.tryParse(value) != null) {
                  final paddedValue = value.padLeft(2, '0');
                  setState(() {
                    onTimeChanged('$paddedValue:$minute $period');
                  });
                }
              },
            ),
          ),
          const SizedBox(width: 2),
          Text(':',
              style: GoogleFonts.poppins(
                  fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(width: 2),
          // Minute text field
          Expanded(
            flex: 2,
            child: TextFormField(
              initialValue: minute.padLeft(2, '0'),
              decoration: InputDecoration(
                labelText: 'Min',
                labelStyle: GoogleFonts.poppins(fontSize: 11),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Colors.redAccent),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                isDense: true,
              ),
              style: GoogleFonts.poppins(fontSize: 13),
              keyboardType: TextInputType.number,
              maxLength: 2,
              buildCounter: (context,
                      {required currentLength,
                      required isFocused,
                      maxLength}) =>
                  null,
              onChanged: (value) {
                if (value.isNotEmpty && int.tryParse(value) != null) {
                  final paddedValue = value.padLeft(2, '0');
                  setState(() {
                    onTimeChanged('$hour:$paddedValue $period');
                  });
                }
              },
            ),
          ),
          const SizedBox(width: 6),
          // AM/PM dropdown
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<String>(
              value: period,
              decoration: InputDecoration(
                labelText: 'AM/PM',
                labelStyle: GoogleFonts.poppins(fontSize: 11),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Colors.redAccent),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                isDense: true,
              ),
              items: ['AM', 'PM']
                  .map((p) => DropdownMenuItem(
                        value: p,
                        child: Text(p,
                            style: GoogleFonts.poppins(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  onTimeChanged('$hour:$minute $value');
                });
              },
            ),
          ),
        ],
      );
    }

    // Helper method to expand day ranges into individual days
    List<Map<String, String>> expandScheduleRanges(
        List<Map<String, String>> inputSchedules) {
      List<Map<String, String>> expandedSchedules = [];

      for (var schedule in inputSchedules) {
        bool isRange = schedule["isRange"] == "true";

        if (isRange &&
            schedule["endDay"] != null &&
            schedule["endDay"]!.isNotEmpty) {
          // Handle range like "Monday to Friday"
          String startDay = schedule["day"] ?? "Monday";
          String endDay = schedule["endDay"]!;

          int startIndex = days.indexOf(startDay);
          int endIndex = days.indexOf(endDay);

          if (startIndex != -1 && endIndex != -1 && startIndex <= endIndex) {
            // Create individual schedules for each day in range
            for (int i = startIndex; i <= endIndex; i++) {
              expandedSchedules.add({
                "day": days[i],
                "start": schedule["start"] ?? "9:00 AM",
                "end": schedule["end"] ?? "5:00 PM",
                "breakStart": schedule["breakStart"] ?? "11:00 AM",
                "breakEnd": schedule["breakEnd"] ?? "12:00 PM",
                "sessionDuration": schedule["sessionDuration"] ?? "30",
              });
            }
          }
        } else {
          // Single day schedule
          expandedSchedules.add({
            "day": schedule["day"] ?? "Monday",
            "start": schedule["start"] ?? "9:00 AM",
            "end": schedule["end"] ?? "5:00 PM",
            "breakStart": schedule["breakStart"] ?? "11:00 AM",
            "breakEnd": schedule["breakEnd"] ?? "12:00 PM",
            "sessionDuration": schedule["sessionDuration"] ?? "30",
          });
        }
      }

      return expandedSchedules;
    }

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 600),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.98),
                      Colors.white.withOpacity(0.95),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.5),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Modern Header
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.redAccent,
                            Colors.redAccent.shade700,
                          ],
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(24),
                          topRight: Radius.circular(24),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.local_hospital_rounded,
                                color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Add Hospital/Clinic",
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    fontSize: 18,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Text(
                                  "Configure facility and schedules",
                                  style: GoogleFonts.poppins(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded,
                                color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),

                    // Content
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // FACILITY SELECTION
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      'Facility Information',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.redAccent,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // Facility Dropdown
                                  isLoadingFacilities
                                      ? Container(
                                          padding: const EdgeInsets.all(16),
                                          child: Row(
                                            children: [
                                              const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2),
                                              ),
                                              const SizedBox(width: 12),
                                              Text(
                                                'Loading facilities...',
                                                style: GoogleFonts.poppins(
                                                    fontSize: 11),
                                              ),
                                            ],
                                          ),
                                        )
                                      : facilities.isEmpty
                                          ? Container(
                                              padding: const EdgeInsets.all(16),
                                              decoration: BoxDecoration(
                                                color: Colors.orange
                                                    .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                border: Border.all(
                                                    color: Colors.orange
                                                        .withOpacity(0.3)),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(Icons.warning,
                                                      color: Colors.orange,
                                                      size: 16),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Text(
                                                      'No facilities available. Please contact administrator.',
                                                      style:
                                                          GoogleFonts.poppins(
                                                              fontSize: 11,
                                                              color: Colors
                                                                  .orange
                                                                  .shade700),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                          : DropdownButtonFormField<String>(
                                              value: selectedFacility,
                                              decoration: InputDecoration(
                                                labelText:
                                                    'Select TB DOTS Facility',
                                                labelStyle: GoogleFonts.poppins(
                                                    fontSize: 11),
                                                prefixIcon: const Icon(
                                                    Icons.local_hospital,
                                                    color: Colors.redAccent),
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  borderSide: BorderSide(
                                                      color:
                                                          Colors.grey.shade300),
                                                ),
                                                focusedBorder:
                                                    OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  borderSide: const BorderSide(
                                                      color: Colors.redAccent),
                                                ),
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 12),
                                                isDense: true,
                                                filled: true,
                                                fillColor: Colors.white,
                                              ),
                                              items: facilities.keys
                                                  .map((facility) =>
                                                      DropdownMenuItem(
                                                        value: facility,
                                                        child: Text(
                                                          facility,
                                                          style: GoogleFonts
                                                              .poppins(
                                                                  fontSize: 14),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ))
                                                  .toList(),
                                              onChanged: (value) {
                                                setModalState(() {
                                                  selectedFacility = value;
                                                  facilityAddress = facilities[
                                                          value] ??
                                                      'Address not available';
                                                });
                                              },
                                              isExpanded: true,
                                            ),

                                  if (selectedFacility != null) ...[
                                    const SizedBox(height: 12),
                                    // Address Display
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                            color:
                                                Colors.blue.withOpacity(0.3)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Address',
                                            style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.blue.shade700,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            facilityAddress,
                                            style: GoogleFonts.poppins(
                                              fontSize: 11,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // SCHEDULES SECTION - Modern Design matching daccount.dart
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Work Schedules',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.redAccent,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Info banner about default schedule
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: Colors.blue.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline,
                                      color: Colors.blue.shade700, size: 20),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Default schedule: Monday-Friday, 9 AM - 5 PM\nDoctor can update these later',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: Colors.blue.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Schedule cards
                            ...schedules.asMap().entries.map((entry) {
                              final index = entry.key;
                              final schedule = entry.value;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      Border.all(color: Colors.grey.shade200),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withOpacity(0.1),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Header with schedule number and delete button
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.redAccent
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            child: Text(
                                              'Schedule ${index + 1}',
                                              style: GoogleFonts.poppins(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.redAccent,
                                              ),
                                            ),
                                          ),
                                          const Spacer(),
                                          Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              onTap: () {
                                                setModalState(() {
                                                  schedules.removeAt(index);
                                                });
                                              },
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(6),
                                                child: Icon(
                                                  Icons.delete_rounded,
                                                  color: Colors.red.shade400,
                                                  size: 18,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),

                                      // Day Range Toggle
                                      CheckboxListTile(
                                        title: Text(
                                          'Day Range',
                                          style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500),
                                        ),
                                        subtitle: Text(
                                          'Apply to multiple consecutive days',
                                          style: GoogleFonts.poppins(
                                              fontSize: 10,
                                              color: Colors.grey.shade600),
                                        ),
                                        value: schedule["isRange"] == "true",
                                        onChanged: (value) {
                                          setModalState(() {
                                            schedules[index]["isRange"] =
                                                value.toString();
                                            if (!value!) {
                                              schedules[index]["endDay"] = "";
                                            }
                                          });
                                        },
                                        controlAffinity:
                                            ListTileControlAffinity.leading,
                                        contentPadding: EdgeInsets.zero,
                                        dense: true,
                                      ),
                                      const SizedBox(height: 8),

                                      // Day Selection
                                      if (schedule["isRange"] == "true") ...[
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                'Starts',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.grey.shade700,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Ends',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.grey.shade700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: DropdownButtonFormField<
                                                  String>(
                                                value: days.contains(
                                                        schedule["day"])
                                                    ? schedule["day"]
                                                    : days.first,
                                                decoration: InputDecoration(
                                                  labelText: 'Start Day',
                                                  labelStyle:
                                                      GoogleFonts.poppins(
                                                          fontSize: 9),
                                                  border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6),
                                                  ),
                                                  contentPadding:
                                                      const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 6,
                                                          vertical: 4),
                                                  isDense: true,
                                                ),
                                                items: days
                                                    .map((day) =>
                                                        DropdownMenuItem(
                                                          value: day,
                                                          child: Text(
                                                              day.substring(
                                                                  0, 3),
                                                              style: GoogleFonts
                                                                  .poppins(
                                                                      fontSize:
                                                                          10)),
                                                        ))
                                                    .toList(),
                                                onChanged: (value) {
                                                  setModalState(() {
                                                    schedules[index]["day"] =
                                                        value ?? days.first;
                                                  });
                                                },
                                                isExpanded: true,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: DropdownButtonFormField<
                                                  String>(
                                                value: schedule["endDay"]
                                                                ?.isNotEmpty ==
                                                            true &&
                                                        days.contains(
                                                            schedule["endDay"])
                                                    ? schedule["endDay"]
                                                    : null,
                                                decoration: InputDecoration(
                                                  labelText: 'End Day',
                                                  labelStyle:
                                                      GoogleFonts.poppins(
                                                          fontSize: 9),
                                                  hintText: 'Friday',
                                                  border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6),
                                                  ),
                                                  contentPadding:
                                                      const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 6,
                                                          vertical: 4),
                                                  isDense: true,
                                                ),
                                                items: days
                                                    .map((day) =>
                                                        DropdownMenuItem(
                                                          value: day,
                                                          child: Text(
                                                              day.substring(
                                                                  0, 3),
                                                              style: GoogleFonts
                                                                  .poppins(
                                                                      fontSize:
                                                                          10)),
                                                        ))
                                                    .toList(),
                                                onChanged: (value) {
                                                  setModalState(() {
                                                    schedules[index]["endDay"] =
                                                        value ?? "";
                                                  });
                                                },
                                                isExpanded: true,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ] else ...[
                                        DropdownButtonFormField<String>(
                                          value: days.contains(schedule["day"])
                                              ? schedule["day"]
                                              : days.first,
                                          decoration: InputDecoration(
                                            labelText: 'Day',
                                            labelStyle: GoogleFonts.poppins(
                                                fontSize: 11),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 8, vertical: 6),
                                            isDense: true,
                                          ),
                                          items: days
                                              .map((day) => DropdownMenuItem(
                                                    value: day,
                                                    child: Text(day,
                                                        style:
                                                            GoogleFonts.poppins(
                                                                fontSize: 11)),
                                                  ))
                                              .toList(),
                                          onChanged: (value) {
                                            setModalState(() {
                                              schedules[index]["day"] =
                                                  value ?? days.first;
                                            });
                                          },
                                          isExpanded: true,
                                        ),
                                      ],
                                      const SizedBox(height: 12),

                                      // Working Hours Section
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color:
                                                  Colors.blue.withOpacity(0.3)),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Working Hours',
                                              style: GoogleFonts.poppins(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.blue.shade700,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text('Start',
                                                style: GoogleFonts.poppins(
                                                    fontSize: 10,
                                                    color:
                                                        Colors.grey.shade600)),
                                            const SizedBox(height: 4),
                                            buildTimePicker(
                                              schedule["start"] ?? "9:00 AM",
                                              (value) {
                                                schedules[index]["start"] =
                                                    value;
                                              },
                                              setModalState,
                                            ),
                                            const SizedBox(height: 8),
                                            Text('End',
                                                style: GoogleFonts.poppins(
                                                    fontSize: 10,
                                                    color:
                                                        Colors.grey.shade600)),
                                            const SizedBox(height: 4),
                                            buildTimePicker(
                                              schedule["end"] ?? "5:00 PM",
                                              (value) {
                                                schedules[index]["end"] = value;
                                              },
                                              setModalState,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 10),

                                      // Break Time Section
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color: Colors.orange
                                                  .withOpacity(0.3)),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Break Time',
                                              style: GoogleFonts.poppins(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.orange.shade700,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text('Start',
                                                style: GoogleFonts.poppins(
                                                    fontSize: 10,
                                                    color:
                                                        Colors.grey.shade600)),
                                            const SizedBox(height: 4),
                                            buildTimePicker(
                                              schedule["breakStart"] ??
                                                  "11:00 AM",
                                              (value) {
                                                schedules[index]["breakStart"] =
                                                    value;
                                              },
                                              setModalState,
                                            ),
                                            const SizedBox(height: 8),
                                            Text('End',
                                                style: GoogleFonts.poppins(
                                                    fontSize: 10,
                                                    color:
                                                        Colors.grey.shade600)),
                                            const SizedBox(height: 4),
                                            buildTimePicker(
                                              schedule["breakEnd"] ??
                                                  "12:00 PM",
                                              (value) {
                                                schedules[index]["breakEnd"] =
                                                    value;
                                              },
                                              setModalState,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 10),

                                      // Session Duration Section
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color: Colors.green
                                                  .withOpacity(0.3)),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Session Duration',
                                              style: GoogleFonts.poppins(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.green.shade700,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            DropdownButtonFormField<String>(
                                              value:
                                                  schedule["sessionDuration"] ??
                                                      "30",
                                              decoration: InputDecoration(
                                                labelText:
                                                    'Duration per session',
                                                labelStyle: GoogleFonts.poppins(
                                                    fontSize: 9),
                                                prefixIcon: const Icon(
                                                    Icons.timer_outlined,
                                                    size: 14),
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4),
                                                isDense: true,
                                              ),
                                              items: [
                                                DropdownMenuItem(
                                                    value: "15",
                                                    child: Text("15 min",
                                                        style:
                                                            GoogleFonts.poppins(
                                                                fontSize: 10))),
                                                DropdownMenuItem(
                                                    value: "30",
                                                    child: Text("30 min",
                                                        style:
                                                            GoogleFonts.poppins(
                                                                fontSize: 10))),
                                                DropdownMenuItem(
                                                    value: "45",
                                                    child: Text("45 min",
                                                        style:
                                                            GoogleFonts.poppins(
                                                                fontSize: 10))),
                                                DropdownMenuItem(
                                                    value: "60",
                                                    child: Text("60 min",
                                                        style:
                                                            GoogleFonts.poppins(
                                                                fontSize: 10))),
                                              ],
                                              onChanged: (value) {
                                                setModalState(() {
                                                  schedules[index]
                                                          ["sessionDuration"] =
                                                      value ?? "30";
                                                });
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),

                            const SizedBox(height: 12),

                            // Add Schedule Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: () {
                                  setModalState(() {
                                    schedules.add({
                                      "day": "Monday",
                                      "start": "9:00 AM",
                                      "end": "5:00 PM",
                                      "breakStart": "11:00 AM",
                                      "breakEnd": "12:00 PM",
                                      "sessionDuration": "30",
                                      "isRange": "false",
                                      "endDay": "",
                                    });
                                  });
                                },
                                icon: const Icon(Icons.add_rounded,
                                    color: Colors.white, size: 20),
                                label: Text(
                                  "Add Schedule",
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Action Buttons
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(24),
                          bottomRight: Radius.circular(24),
                        ),
                        border: Border(
                          top: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: Colors.grey.shade300, width: 1.5),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => Navigator.pop(context),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    child: Center(
                                      child: Text(
                                        "Cancel",
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade700,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.redAccent,
                                    Colors.redAccent.shade700
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.redAccent.withOpacity(0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () {
                                    if (selectedFacility == null) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Row(
                                            children: [
                                              const Icon(Icons.warning_rounded,
                                                  color: Colors.white,
                                                  size: 20),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  'Please select a facility',
                                                  style: GoogleFonts.poppins(
                                                      fontWeight:
                                                          FontWeight.w500),
                                                ),
                                              ),
                                            ],
                                          ),
                                          backgroundColor:
                                              Colors.redAccent.shade700,
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12)),
                                          margin: const EdgeInsets.all(16),
                                        ),
                                      );
                                      return;
                                    }
                                    if (schedules.isEmpty) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Row(
                                            children: [
                                              const Icon(Icons.warning_rounded,
                                                  color: Colors.white,
                                                  size: 20),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  'Please add at least one schedule',
                                                  style: GoogleFonts.poppins(
                                                      fontWeight:
                                                          FontWeight.w500),
                                                ),
                                              ),
                                            ],
                                          ),
                                          backgroundColor:
                                              Colors.redAccent.shade700,
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12)),
                                          margin: const EdgeInsets.all(16),
                                        ),
                                      );
                                      return;
                                    }

                                    // Expand day ranges before saving
                                    final expandedSchedules =
                                        expandScheduleRanges(schedules);

                                    setState(() {
                                      affiliations.add({
                                        "name": selectedFacility!,
                                        "address": facilityAddress,
                                        "email": "",
                                        "latitude": 0.0,
                                        "longitude": 0.0,
                                        "schedules": expandedSchedules,
                                      });
                                    });
                                    Navigator.pop(context);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.check_circle_rounded,
                                            color: Colors.white, size: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                          "Add Affiliation",
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.redAccent.shade100,
              Colors.red.shade50,
              Colors.white,
              Colors.blue.shade50,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Modern Header with Glassmorphism
              Container(
                margin: const EdgeInsets.all(16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.95),
                      Colors.white.withOpacity(0.85),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.5),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Back Button
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_rounded,
                            color: Colors.redAccent),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Title Section
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Medical Staff Registration',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.redAccent.shade700,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Create new healthcare professional account',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Decorative Icon
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.redAccent, Colors.redAccent.shade700],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.redAccent.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.medical_services_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),

              // Main Content Area
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),

                        // Personal Information Card
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withOpacity(0.95),
                                Colors.white.withOpacity(0.85),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.5),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Section Header
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.blue.shade400,
                                          Colors.blue.shade600
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.person_rounded,
                                        color: Colors.white, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Personal Information',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),

                              // Full Name Field
                              TextFormField(
                                controller: _nameController,
                                decoration: InputDecoration(
                                  labelText: 'Full Name',
                                  labelStyle: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                  prefixIcon: Icon(Icons.badge_rounded,
                                      color: Colors.blue.shade600, size: 20),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide:
                                        BorderSide(color: Colors.grey.shade200),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                        color: Colors.blue.shade400, width: 2),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: Colors.redAccent),
                                  ),
                                ),
                                style: GoogleFonts.poppins(fontSize: 14),
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
                                value: _selectedRole,
                                decoration: InputDecoration(
                                  labelText: 'Staff Role',
                                  labelStyle: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                  prefixIcon: Icon(Icons.work_rounded,
                                      color: Colors.blue.shade600, size: 20),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide:
                                        BorderSide(color: Colors.grey.shade200),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                        color: Colors.blue.shade400, width: 2),
                                  ),
                                ),
                                items: ['Doctor', 'Health Worker']
                                    .map((String role) {
                                  return DropdownMenuItem(
                                    value: role,
                                    child: Text(
                                      role,
                                      style: GoogleFonts.poppins(fontSize: 14),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (String? newValue) {
                                  setState(() {
                                    _selectedRole = newValue!;
                                    affiliations.clear();
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Account Security Card
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withOpacity(0.95),
                                Colors.white.withOpacity(0.85),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.5),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Section Header
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.purple.shade400,
                                          Colors.purple.shade600
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.security_rounded,
                                        color: Colors.white, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Account Security',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),

                              // Email Field
                              TextFormField(
                                controller: _emailController,
                                decoration: InputDecoration(
                                  labelText: 'Email Address',
                                  labelStyle: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                  prefixIcon: Icon(Icons.email_rounded,
                                      color: Colors.purple.shade600, size: 20),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide:
                                        BorderSide(color: Colors.grey.shade200),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                        color: Colors.purple.shade400,
                                        width: 2),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: Colors.redAccent),
                                  ),
                                ),
                                style: GoogleFonts.poppins(fontSize: 14),
                                keyboardType: TextInputType.emailAddress,
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
                                  labelStyle: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                  prefixIcon: Icon(Icons.lock_rounded,
                                      color: Colors.purple.shade600, size: 20),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide:
                                        BorderSide(color: Colors.grey.shade200),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                        color: Colors.purple.shade400,
                                        width: 2),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: Colors.redAccent),
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _isPasswordVisible
                                          ? Icons.visibility_rounded
                                          : Icons.visibility_off_rounded,
                                      color: Colors.grey.shade600,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _isPasswordVisible =
                                            !_isPasswordVisible;
                                      });
                                    },
                                  ),
                                ),
                                style: GoogleFonts.poppins(fontSize: 14),
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
                                  labelStyle: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                  prefixIcon: Icon(Icons.lock_outline_rounded,
                                      color: Colors.purple.shade600, size: 20),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide:
                                        BorderSide(color: Colors.grey.shade200),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                        color: Colors.purple.shade400,
                                        width: 2),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: Colors.redAccent),
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _isConfirmPasswordVisible
                                          ? Icons.visibility_rounded
                                          : Icons.visibility_off_rounded,
                                      color: Colors.grey.shade600,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _isConfirmPasswordVisible =
                                            !_isConfirmPasswordVisible;
                                      });
                                    },
                                  ),
                                ),
                                style: GoogleFonts.poppins(fontSize: 14),
                                validator: (value) {
                                  if (value != _passwordController.text) {
                                    return 'Passwords do not match';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        const SizedBox(height: 16),

                        // Health Worker Facility Selection
                        if (_selectedRole == 'Health Worker') ...[
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withOpacity(0.95),
                                  Colors.white.withOpacity(0.85),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.5),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Section Header
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.green.shade400,
                                            Colors.green.shade600
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                          Icons.local_hospital_rounded,
                                          color: Colors.white,
                                          size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'TB DOTS Facility',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),

                                DropdownButtonFormField<TBDotsFacility>(
                                  decoration: InputDecoration(
                                    labelText: "Select Your Facility",
                                    labelStyle: GoogleFonts.poppins(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                    ),
                                    prefixIcon: Icon(Icons.business_rounded,
                                        color: Colors.green.shade600, size: 20),
                                    filled: true,
                                    fillColor: Colors.grey.shade50,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                          color: Colors.grey.shade200),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                          color: Colors.green.shade400,
                                          width: 2),
                                    ),
                                  ),
                                  items: tbDotsFacilities.map((facility) {
                                    return DropdownMenuItem<TBDotsFacility>(
                                      value: facility,
                                      child: Text(
                                        facility.name,
                                        style:
                                            GoogleFonts.poppins(fontSize: 14),
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
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: Colors.green.withOpacity(0.3)),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.location_on_rounded,
                                            size: 20,
                                            color: Colors.green.shade700),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            affiliations[0]["address"],
                                            style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],

                        // Affiliated Hospitals section for doctors only
                        if (_selectedRole == 'Doctor') ...[
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withOpacity(0.95),
                                  Colors.white.withOpacity(0.85),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.5),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Section Header
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.orange.shade400,
                                            Colors.orange.shade600
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.apartment_rounded,
                                          color: Colors.white, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Affiliated Clinics/Hospitals',
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.grey.shade800,
                                        ),
                                      ),
                                    ),
                                    // Add Button
                                    Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.redAccent,
                                            Colors.redAccent.shade700
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.redAccent
                                                .withOpacity(0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          onTap: _showAddAffiliationDialog,
                                          child: const Padding(
                                            padding: EdgeInsets.all(8),
                                            child: Icon(Icons.add_rounded,
                                                color: Colors.white, size: 20),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Affiliations List
                                affiliations.isEmpty
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 32, horizontal: 16),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade50,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                              color: Colors.grey.shade200,
                                              style: BorderStyle.solid,
                                              width: 2),
                                        ),
                                        child: Column(
                                          children: [
                                            Icon(Icons.business_outlined,
                                                size: 48,
                                                color: Colors.grey.shade400),
                                            const SizedBox(height: 12),
                                            Text(
                                              "No affiliations added yet",
                                              style: GoogleFonts.poppins(
                                                color: Colors.grey.shade600,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              "Click + to add your first clinic/hospital",
                                              style: GoogleFonts.poppins(
                                                color: Colors.grey.shade500,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : Column(
                                        children: affiliations.map((a) {
                                          return Container(
                                            margin: const EdgeInsets.only(
                                                bottom: 12),
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [
                                                  Colors.orange.shade50,
                                                  Colors.orange.shade50
                                                      .withOpacity(0.5),
                                                ],
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                  color:
                                                      Colors.orange.shade200),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.orange
                                                      .withOpacity(0.1),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              6),
                                                      decoration: BoxDecoration(
                                                        color: Colors
                                                            .orange.shade100,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                      ),
                                                      child: Icon(
                                                          Icons
                                                              .local_hospital_rounded,
                                                          size: 16,
                                                          color: Colors
                                                              .orange.shade700),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: Text(
                                                        a["name"],
                                                        style:
                                                            GoogleFonts.poppins(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontSize: 15,
                                                          color: Colors
                                                              .grey.shade800,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 10),
                                                Row(
                                                  children: [
                                                    Icon(
                                                        Icons
                                                            .location_on_rounded,
                                                        size: 16,
                                                        color: Colors
                                                            .grey.shade600),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: Text(
                                                        a["address"],
                                                        style:
                                                            GoogleFonts.poppins(
                                                          fontSize: 12,
                                                          color: Colors
                                                              .grey.shade600,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 10),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.all(10),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Icon(
                                                              Icons
                                                                  .access_time_rounded,
                                                              size: 14,
                                                              color: Colors.blue
                                                                  .shade600),
                                                          const SizedBox(
                                                              width: 6),
                                                          Text(
                                                            'Schedules',
                                                            style: GoogleFonts
                                                                .poppins(
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: Colors.blue
                                                                  .shade700,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 6),
                                                      ...(a["schedules"]
                                                              as List)
                                                          .map<Widget>(
                                                        (s) => Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .only(
                                                                  left: 20,
                                                                  top: 4),
                                                          child: Text(
                                                            "${s["day"]}: ${s["start"]} - ${s["end"]}",
                                                            style: GoogleFonts
                                                                .poppins(
                                                              fontSize: 12,
                                                              color: Colors.grey
                                                                  .shade700,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),

                        const SizedBox(height: 24),

                        // Continue Button - Modern Gradient Design
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.redAccent,
                                Colors.redAccent.shade700,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.redAccent.withOpacity(0.4),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                if (_formKey.currentState!.validate()) {
                                  bool isValid = true;
                                  String? errorMessage;

                                  if (_selectedRole == 'Doctor') {
                                    if (affiliations.isEmpty) {
                                      isValid = false;
                                      errorMessage =
                                          'Please add at least one affiliation';
                                    } else {
                                      // Check if all affiliations have schedules
                                      for (var affiliation in affiliations) {
                                        if (!affiliation
                                            .containsKey('schedules')) {
                                          isValid = false;
                                          affiliations.clear();
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
                                        content: Row(
                                          children: [
                                            const Icon(Icons.error_outline,
                                                color: Colors.white),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                errorMessage!,
                                                style: GoogleFonts.poppins(
                                                    fontWeight:
                                                        FontWeight.w500),
                                              ),
                                            ),
                                          ],
                                        ),
                                        backgroundColor:
                                            Colors.redAccent.shade700,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                        margin: const EdgeInsets.all(16),
                                      ),
                                    );
                                    return;
                                  }
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          MedicalStaffConfirmationPage(
                                        email: _emailController.text.trim(),
                                        password:
                                            _passwordController.text.trim(),
                                        fullName: _nameController.text.trim(),
                                        role: _selectedRole,
                                        specialization:
                                            _specializationController.text
                                                .trim(),
                                        affiliations: _selectedRole == 'Doctor'
                                            ? affiliations
                                            : null,
                                        facility:
                                            _selectedRole == 'Health Worker' &&
                                                    affiliations.isNotEmpty
                                                ? affiliations[0]
                                                : null,
                                      ),
                                    ),
                                  );
                                }
                              },
                              child: Container(
                                width: double.infinity,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 18),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.arrow_forward_rounded,
                                        color: Colors.white, size: 22),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Continue to Confirmation',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
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
