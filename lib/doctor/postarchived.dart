import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tb_frontend/doctor/viewpost.dart';

class Postarchived extends StatefulWidget {
  const Postarchived({super.key});

  @override
  State<Postarchived> createState() => _PostarchivedState();
}

class _PostarchivedState extends State<Postarchived> {
  String? _currentUserId;
  bool _isSelectionMode = false;
  final Set<String> _selectedAppointments = {};

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ));
  }

  Future<void> _getCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _currentUserId = user.uid;
      });
    }
  }

  void _toggleSelectionMode(String appointmentId) {
    setState(() {
      if (!_isSelectionMode) {
        _isSelectionMode = true;
        _selectedAppointments.add(appointmentId);
      }
    });
  }

  void _toggleSelection(String appointmentId) {
    setState(() {
      if (_selectedAppointments.contains(appointmentId)) {
        _selectedAppointments.remove(appointmentId);
        if (_selectedAppointments.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedAppointments.add(appointmentId);
      }
    });
  }

  void _cancelSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedAppointments.clear();
    });
  }

  Future<void> _unarchiveSelectedAppointments() async {
    if (_selectedAppointments.isEmpty) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.unarchive_rounded, color: Colors.green, size: 24),
            ),
            const SizedBox(width: 12),
            const Text(
              'Unarchive',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to unarchive ${_selectedAppointments.length} appointment(s)?',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text(
              'Unarchive',
              style: TextStyle(color: Colors.white, fontSize: 15),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Show loading
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Text('Unarchiving ${_selectedAppointments.length} appointment(s)...'),
              ],
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Unarchive each selected appointment
      for (String appointmentId in _selectedAppointments) {
        await FirebaseFirestore.instance
            .collection('completed_appointments')
            .doc(appointmentId)
            .update({
          'archived': false,
          'unarchivedAt': FieldValue.serverTimestamp(),
        });
      }

      // Exit selection mode
      setState(() {
        _isSelectionMode = false;
        _selectedAppointments.clear();
      });

      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.check_circle, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Text('Appointments unarchived successfully'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error unarchiving appointments: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 🔹 Header
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 20, 0, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back Button or Cancel Button
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade300,
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: Icon(
                          _isSelectionMode ? Icons.close : Icons.arrow_back_ios,
                          color: const Color(0xE0F44336),
                        ),
                        onPressed: () {
                          if (_isSelectionMode) {
                            _cancelSelectionMode();
                          } else {
                            Navigator.pop(context);
                          }
                        },
                      ),
                    ),

                    // Title
                    Text(
                      _isSelectionMode 
                          ? "${_selectedAppointments.length} Selected"
                          : "Archived",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xE0F44336),
                      ),
                    ),

                    // Unarchive Button
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, animation) {
                        return ScaleTransition(scale: animation, child: child);
                      },
                      child: _isSelectionMode
                          ? Container(
                              key: const ValueKey('unarchive_button'),
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.green.withOpacity(0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.unarchive_rounded,
                                    color: Colors.white),
                                onPressed: _selectedAppointments.isNotEmpty
                                    ? _unarchiveSelectedAppointments
                                    : null,
                              ),
                            )
                          : const SizedBox(
                              key: ValueKey('empty_space'),
                              width: 48,
                              height: 48,
                            ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 🔹 List of Archived Appointments
              StreamBuilder<QuerySnapshot>(
                stream: _currentUserId != null
                    ? FirebaseFirestore.instance
                        .collection('completed_appointments')
                        .where('doctorId', isEqualTo: _currentUserId)
                        .where('archived', isEqualTo: true)
                        .snapshots()
                    : const Stream.empty(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final archivedAppointments = snapshot.data?.docs ?? [];

                  // Sort by archivedAt timestamp
                  archivedAppointments.sort((a, b) {
                    final aData = a.data() as Map<String, dynamic>;
                    final bData = b.data() as Map<String, dynamic>;

                    final aArchived = aData['archivedAt'] as Timestamp?;
                    final bArchived = bData['archivedAt'] as Timestamp?;

                    if (aArchived == null && bArchived == null) return 0;
                    if (aArchived == null) return 1;
                    if (bArchived == null) return -1;

                    // Sort descending (newest first)
                    return bArchived.compareTo(aArchived);
                  });

                  if (archivedAppointments.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.archive_outlined,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              "No Archived Appointments",
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Archived appointments will appear here",
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: archivedAppointments.length,
                    itemBuilder: (context, index) {
                      final doc = archivedAppointments[index];
                      final appointment = doc.data() as Map<String, dynamic>;
                      final appointmentId = doc.id;
                      final isSelected = _selectedAppointments.contains(appointmentId);

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: isSelected 
                                  ? Colors.green.withOpacity(0.3)
                                  : Colors.grey.withOpacity(0.1),
                              blurRadius: isSelected ? 12 : 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              if (_isSelectionMode) {
                                _toggleSelection(appointmentId);
                              } else {
                                _showArchivedAppointmentDetails({
                                  ...appointment,
                                  'id': appointmentId,
                                });
                              }
                            },
                            onLongPress: () {
                              if (!_isSelectionMode) {
                                _toggleSelectionMode(appointmentId);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: isSelected 
                                      ? Colors.green
                                      : Colors.transparent,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  // Checkbox (appears in selection mode)
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    width: _isSelectionMode ? 32 : 0,
                                    height: 32,
                                    margin: EdgeInsets.only(
                                      right: _isSelectionMode ? 12 : 0,
                                    ),
                                    child: _isSelectionMode
                                        ? Transform.scale(
                                            scale: 1.2,
                                            child: Checkbox(
                                              value: isSelected,
                                              onChanged: (value) {
                                                _toggleSelection(appointmentId);
                                              },
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              activeColor: Colors.green,
                                              side: BorderSide(
                                                color: Colors.grey.shade400,
                                                width: 2,
                                              ),
                                            ),
                                          )
                                        : null,
                                  ),
                                  
                                  // Avatar
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: appointment['treatmentCompleted'] == true
                                            ? [Colors.purple.shade400, Colors.purple.shade600]
                                            : [Colors.blue.shade400, Colors.blue.shade600],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: (appointment['treatmentCompleted'] == true
                                                  ? Colors.purple
                                                  : Colors.blue)
                                              .withOpacity(0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Text(
                                        appointment["patientName"]
                                                ?.substring(0, 1)
                                                .toUpperCase() ??
                                            "P",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20,
                                        ),
                                      ),
                                    ),
                                  ),
                                  
                                  const SizedBox(width: 16),
                                  
                                  // Content
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          appointment["patientName"] ?? "Unknown Patient",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: Color(0xFF1F2937),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: (appointment['treatmentCompleted'] == true
                                                    ? Colors.purple
                                                    : Colors.blue)
                                                .withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            appointment['treatmentCompleted'] == true
                                                ? "Treatment Completed"
                                                : "Completed with Prescription",
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: appointment['treatmentCompleted'] == true
                                                  ? Colors.purple
                                                  : Colors.blue,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  // Trailing icon
                                  if (!_isSelectionMode)
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        Icons.arrow_forward_ios_rounded,
                                        size: 16,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ Show archived appointment details
  void _showArchivedAppointmentDetails(
      Map<String, dynamic> appointment) async {
    // Use the original appointmentId from the completed appointment data
    final originalAppointmentId =
        appointment['appointmentId'] ?? appointment['id'];

    // Fetch prescription data for this appointment using the original appointmentId
    final prescriptionSnapshot = await FirebaseFirestore.instance
        .collection('prescriptions')
        .where('appointmentId', isEqualTo: originalAppointmentId)
        .get();

    Map<String, dynamic>? prescriptionData;
    if (prescriptionSnapshot.docs.isNotEmpty) {
      prescriptionData = prescriptionSnapshot.docs.first.data();
    }

    // Fetch doctor information from doctors collection
    Map<String, dynamic>? doctorData;
    if (appointment['doctorId'] != null) {
      try {
        final doctorDoc = await FirebaseFirestore.instance
            .collection('doctors')
            .doc(appointment['doctorId'])
            .get();

        if (doctorDoc.exists) {
          doctorData = doctorDoc.data();
        }
      } catch (e) {
        debugPrint('Error fetching doctor data: $e');
      }
    }

    if (context.mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Viewpostappointment(
            appointment: {
              ...appointment,
              'prescriptionData': prescriptionData,
              'doctorData': doctorData,
              'showCertificateButton': true,
              'isArchived': true,
              // Keep the correct document ID for operations
              'completedAppointmentDocId': appointment['id'],
              'id': appointment['appointmentId'] ?? appointment['id'],
            },
          ),
        ),
      );
    }
  }
}
