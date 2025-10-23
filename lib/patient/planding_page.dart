import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:tb_frontend/patient/pdoclist.dart';
import 'package:tb_frontend/patient/pmyappointment.dart';
import 'package:tb_frontend/patient/appointment_status_card.dart';
import 'package:tb_frontend/guest/gconsultant.dart';
import 'package:tb_frontend/patient/ptbfacility.dart';

// ✅ Import YouTube player
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

// ✅ PDF viewer screen
import 'practical_pdf_viewer_screen.dart';

class PlandingPage extends StatefulWidget {
  const PlandingPage({super.key});

  @override
  State<PlandingPage> createState() => _PlandingPageState();
}

class _PlandingPageState extends State<PlandingPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  YoutubePlayerController? _youtubeController;
  bool _isLoading = true;
  // Notification state
  String? _currentPatientId;
  final Map<String, Map<String, dynamic>> _appointmentsById = {};
  final Map<String, String> _knownStatuses = {};
  final List<Map<String, dynamic>> _notificationItems = [];
  // track read state locally
  final List<StreamSubscription> _appointmentListeners = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _notificationsSub;

  @override
  void initState() {
    super.initState();
    _loadYoutubeUrl();
    // Clear all state to avoid duplicates when revisiting
    _appointmentsById.clear();
    _knownStatuses.clear();
    _notificationItems.clear();
    for (final sub in _appointmentListeners) {
      sub.cancel();
    }
    _appointmentListeners.clear();
    _notificationsSub?.cancel();
    _notificationsSub = null;
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _currentPatientId = user.uid;
    // Real-time listener for persisted notifications so UI updates automatically
    try {
      _notificationsSub = FirebaseFirestore.instance
          .collection('patient_notifications')
          .where('patientUid', isEqualTo: _currentPatientId)
          .orderBy('timestamp', descending: true)
          .snapshots()
          .listen((snapshot) {
        _notificationItems.clear();
        final Map<String, Map<String, dynamic>> latestByAppointment = {};
        for (final doc in snapshot.docs) {
          final data = doc.data();
          DateTime ts;
          final rawTs = data['timestamp'];
          if (rawTs is Timestamp) {
            ts = rawTs.toDate();
          } else if (rawTs is DateTime) {
            ts = rawTs;
          } else {
            ts = DateTime.now();
          }
          final appointmentId = data['appointmentId']?.toString() ?? '';
          if (appointmentId.isEmpty) continue;
          // Only keep the latest notification per appointmentId
          if (!latestByAppointment.containsKey(appointmentId) ||
              ts.isAfter(latestByAppointment[appointmentId]!['timestamp'])) {
            latestByAppointment[appointmentId] = {
              'docId': doc.id,
              'appointmentId': appointmentId,
              'status': data['status'],
              'read': data['read'] ?? false,
              'timestamp': ts,
              'title': data['title'],
              'subtitle': data['subtitle'],
            };
          }
        }
        _notificationItems.addAll(latestByAppointment.values);
      }, onError: (e) => debugPrint('Error listening notifications: $e'));
    } catch (e) {
      debugPrint('Error initializing notifications listener: $e');
    }
    // Start listeners for relevant appointment collections
    void attachListener(String collection) {
      final sub = FirebaseFirestore.instance
          .collection(collection)
          .where('patientUid', isEqualTo: _currentPatientId)
          .snapshots()
          .listen((snapshot) {
        for (var doc in snapshot.docs) {
          final data = {...doc.data()};
          data['appointmentId'] = doc.id;
          _processAppointmentChange(data);
        }
      }, onError: (e) => debugPrint('Listener error ($collection): $e'));
      _appointmentListeners.add(sub);
    }

    // Collections to watch (same ones used in pmyappointment)
    attachListener('pending_patient_data');
    attachListener('approved_appointments');
    attachListener('completed_appointments');
    attachListener('appointment_history');
    attachListener('rejected_appointments');
  }

  void _processAppointmentChange(Map<String, dynamic> appt) {
    final id = appt['appointmentId']?.toString() ?? appt['id']?.toString();
    if (id == null) return;
    final status = (appt['status'] ?? '').toString().toLowerCase();

    final previous = _knownStatuses[id];
    // New appointment
    if (previous == null) {
      _knownStatuses[id] = status;
      _appointmentsById[id] = appt;
      _addNotification(appt, 'new');
      return;
    }

    // Status changed
    if (previous != status) {
      _knownStatuses[id] = status;
      _appointmentsById[id] = appt;

      // Decide detailed reason based on new status for richer notifications
      if (status == 'consultation_finished') {
        // Consultation finished may imply e-prescription is available
        _addNotification(appt, 'consultation_finished');
      } else if (status == 'treatment_completed' ||
          status == 'with_certificate') {
        _addNotification(appt, 'treatment_completed');
      } else if (status == 'rejected' || status == 'not_approved') {
        _addNotification(appt, 'rejected');
      } else {
        _addNotification(appt, 'status_changed');
      }

      return;
    }

    // Otherwise keep stored
    _appointmentsById[id] = appt;
  }

  void _addNotification(Map<String, dynamic> appt, String reason) async {
    final apptId = appt['appointmentId'] ?? appt['id'] ?? '';
    var status = (appt['status'] ?? '').toString().toLowerCase();
    String title;
    String subtitle;

    // Prevent duplicate notification for same appointmentId and status in Firestore and local list
    if (_notificationItems
        .any((n) => n['appointmentId'] == apptId && n['status'] == status)) {
      // Already exists locally, do not add
      return;
    }
    try {
      final query = await FirebaseFirestore.instance
          .collection('patient_notifications')
          .where('patientUid', isEqualTo: _currentPatientId)
          .where('appointmentId', isEqualTo: apptId)
          .where('status', isEqualTo: status)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        // Already exists in Firestore, do not add
        return;
      }
    } catch (e) {
      debugPrint('Error checking for duplicate notification: $e');
      // If error, continue to try to add (fail-safe)
    }

    // Always show the most advanced status for this appointment
    String effectiveStatus = status;
    // Query for more advanced statuses
    final completedSnap = await FirebaseFirestore.instance
        .collection('completed_appointments')
        .where('appointmentId', isEqualTo: apptId)
        .limit(1)
        .get();
    final historySnap = await FirebaseFirestore.instance
        .collection('appointment_history')
        .where('appointmentId', isEqualTo: apptId)
        .limit(1)
        .get();
    if (historySnap.docs.isNotEmpty) {
      effectiveStatus = 'treatment_completed';
    } else if (completedSnap.docs.isNotEmpty) {
      // Check the actual status in completed_appointments
      final completedData = completedSnap.docs.first.data();
      final completedStatus =
          (completedData['status'] ?? '').toString().toLowerCase();
      if (completedStatus == 'consultation_finished' ||
          completedStatus == 'with_prescription') {
        effectiveStatus = 'consultation_finished';
      } else if (completedStatus == 'treatment_completed' ||
          completedStatus == 'with_certificate') {
        effectiveStatus = 'treatment_completed';
      } else {
        effectiveStatus = completedStatus;
      }
    }
    // If the effective status is more advanced than 'approved', do not show 'approved' notification
    if (status == 'approved' && effectiveStatus != 'approved') {
      // Instead, show the correct notification for the advanced status
      if (effectiveStatus == 'consultation_finished') {
        reason = 'consultation_finished';
      } else if (effectiveStatus == 'treatment_completed') {
        reason = 'treatment_completed';
      } else {
        // fallback to status_changed
        reason = 'status_changed';
      }
      status = effectiveStatus;
    }

    final doctorName = appt['doctorName'] ?? appt['doctor_name'] ?? 'Doctor';
    if (reason == 'new') {
      // Context-aware title for new appointment docs
      if (status == 'approved') {
        title = 'Appointment Confirmed';
        subtitle = 'Your appointment with Dr. $doctorName has been confirmed.';
      } else if (status == 'completed' || status == 'appointment_completed') {
        title = 'Appointment Completed';
        subtitle = 'Your appointment with Dr. $doctorName has been completed.';
      } else if (status == 'pending' || status.isEmpty) {
        title = 'Appointment Request Sent';
        subtitle =
            'Your appointment request with Dr. $doctorName has been submitted.';
      } else {
        title = 'New Appointment';
        subtitle = 'You have a new appointment with Dr. $doctorName.';
      }
    } else if (reason == 'consultation_finished') {
      title = 'Online Consultation Complete';
      // if prescription was added, mention it
      final hasPrescription = (appt['status'] ?? '').toString().toLowerCase() ==
              'with_prescription' ||
          (appt['hasPrescription'] == true);
      subtitle = hasPrescription
          ? 'Your online consultation with Dr. $doctorName is complete. E-Prescription is available.'
          : 'Your online consultation with Dr. $doctorName is complete.';
    } else if (reason == 'treatment_completed') {
      title = 'Certificate Received';
      subtitle =
          'Congratulations! You have received your Certificate of Completion from Dr. $doctorName.';
    } else if (reason == 'rejected') {
      title = 'Appointment Was Rejected';
      final rejectReason = appt['rejectReason'] ??
          appt['rejectionReason'] ??
          appt['reason'] ??
          '';
      subtitle = rejectReason != ''
          ? 'Your request appointment with Dr. $doctorName was rejected: $rejectReason'
          : 'Your request appointment with Dr. $doctorName was rejected.';
    } else {
      // status_changed or fallback
      switch (status) {
        case 'approved':
          title = 'Appointment Approved';
          break;
        case 'completed':
        case 'appointment_completed':
          title = 'Appointment Completed';
          break;
        case 'pending':
          title = 'Appointment Pending';
          break;
        case 'with_prescription':
          title = 'E-Prescription Ready';
          break;
        case 'with_certificate':
          title = 'Certificate Received';
          break;
        case 'consultation_finished':
          title = 'Online Consultation Complete';
          break;
        default:
          title = 'Appointment Update';
      }
      if (status == 'with_certificate' || status == 'treatment_completed') {
        subtitle =
            'Congratulations! You have received your Certificate of Completion from Dr. $doctorName.';
      } else if (status == 'consultation_finished') {
        subtitle = 'Your online consultation with Dr. $doctorName is complete.';
      } else if (status == 'completed' || status == 'appointment_completed') {
        subtitle = 'Your appointment with Dr. $doctorName has been completed.';
      } else {
        subtitle = 'Dr. $doctorName • ${status.toUpperCase()}';
      }
    }

    try {
      // Mark source so we know this notification originates from pmyappointment updates
      final docRef = await FirebaseFirestore.instance
          .collection('patient_notifications')
          .add({
        'patientUid': _currentPatientId,
        'appointmentId': apptId,
        'title': title,
        'subtitle': subtitle,
        'status': status,
        'timestamp': Timestamp.fromDate(DateTime.now()),
        'read': false,
        'source': 'pmyappointment',
      });

      _notificationItems.insert(0, {
        'docId': docRef.id,
        'appointmentId': apptId,
        'title': title,
        'subtitle': subtitle,
        'status': status,
        'timestamp': DateTime.now(),
        'read': false,
        'source': 'pmyappointment',
      });
      setState(() {});
    } catch (e) {
      debugPrint('Error creating notification: $e');
    }
  }

  Future<void> _loadYoutubeUrl() async {
    try {
      final doc = await _firestore.collection('settings').doc('youtube').get();
      final url = doc.data()?['url'] as String?;
      if (url != null) {
        final videoId = YoutubePlayer.convertUrlToId(url);
        if (videoId != null) {
          _youtubeController = YoutubePlayerController(
            initialVideoId: videoId,
            flags: const YoutubePlayerFlags(autoPlay: false, mute: false),
          );
        }
      }
    } catch (e) {
      debugPrint("⚠️ Failed to load YouTube URL: $e");
    }
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _youtubeController?.dispose();
    for (final sub in _appointmentListeners) {
      sub.cancel();
    }
    _notificationsSub?.cancel();
    super.dispose();
  }

  void _showImageDialog(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (BuildContext context) {
          return Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            body: Center(
              child: InteractiveViewer(
                panEnabled: true,
                boundaryMargin: const EdgeInsets.all(0),
                minScale: 0.5,
                maxScale: 5.0,
                child: SizedBox(
                  width: double.infinity,
                  height: double.infinity,
                  child: Image.asset(
                    'assets/images/guidelines.png',
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Only count unread notifications that originate from pmyappointment (new/updated containers)
    final int unreadCount = _notificationItems
        .where((n) => n['source'] == 'pmyappointment' && !(n['read'] == true))
        .length;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Image.asset("assets/images/tbisita_logo2.png",
                            height: 30, alignment: Alignment.centerLeft),
                        const Spacer(),
                        // Notification bell with badge (preserved)
                        GestureDetector(
                          onTap: () {
                            // Mark all notifications as read (collapse badge) and persist
                            for (var n in _notificationItems) {
                              n['read'] = true;
                              final docId = n['docId'];
                              if (docId != null) {
                                FirebaseFirestore.instance
                                    .collection('patient_notifications')
                                    .doc(docId)
                                    .update({'read': true}).catchError(
                                        (e) => debugPrint('Error marking read: $e'));
                              }
                            }
                            setState(() {});

                            // Open notifications modal
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              shape: const RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.vertical(top: Radius.circular(24)),
                              ),
                              builder: (ctx) {
                                return DraggableScrollableSheet(
                                  expand: false,
                                  initialChildSize: 0.6,
                                  minChildSize: 0.3,
                                  maxChildSize: 0.95,
                                  builder: (_, controller) {
                                    return Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.vertical(
                                            top: Radius.circular(24)),
                                      ),
                                      child: Column(
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 6,
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade300,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                          ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Notifications',
                                            style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold)),
                                        Text(
                                            '${_notificationItems.where((n) => !(n['read'] == true)).length} new',
                                            style: const TextStyle(
                                                color: Colors.grey)),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Expanded(
                                      child: _notificationItems.isEmpty
                                          ? Center(
                                              child: Text('No notifications',
                                                  style: TextStyle(
                                                      color: Colors
                                                          .grey.shade600)))
                                          : ListView.builder(
                                              controller: controller,
                                              itemCount:
                                                  _notificationItems.length,
                                              itemBuilder: (context, index) {
                                                final n =
                                                    _notificationItems[index];
                                                return Dismissible(
                                                  key: Key(n['docId'] ??
                                                      n['appointmentId'] ??
                                                      index.toString()),
                                                  direction: DismissDirection
                                                      .endToStart,
                                                  background: Container(
                                                    alignment:
                                                        Alignment.centerRight,
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 24),
                                                    color: Colors.redAccent,
                                                    child: const Icon(
                                                        Icons.delete,
                                                        color: Colors.white),
                                                  ),
                                                  onDismissed:
                                                      (direction) async {
                                                    final docId = n['docId'];
                                                    if (docId != null) {
                                                      try {
                                                        await FirebaseFirestore
                                                            .instance
                                                            .collection(
                                                                'patient_notifications')
                                                            .doc(docId)
                                                            .delete();
                                                      } catch (e) {
                                                        debugPrint(
                                                            'Error deleting notification: $e');
                                                      }
                                                    }
                                                    setState(() {
                                                      _notificationItems
                                                          .removeAt(index);
                                                    });
                                                  },
                                                  child: GestureDetector(
                                                    onTap: () async {
                                                      // mark this notification as read locally and in Firestore
                                                      setState(() {
                                                        n['read'] = true;
                                                      });
                                                      final docId = n['docId'];
                                                      if (docId != null) {
                                                        try {
                                                          await FirebaseFirestore
                                                              .instance
                                                              .collection(
                                                                  'patient_notifications')
                                                              .doc(docId)
                                                              .update({
                                                            'read': true
                                                          });
                                                        } catch (e) {
                                                          debugPrint(
                                                              'Error updating read flag: $e');
                                                        }
                                                      }
                                                      Navigator.of(ctx).pop();
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                            builder: (_) =>
                                                                const PMyAppointmentScreen()),
                                                      );
                                                    },
                                                    child:
                                                        AppointmentStatusCard(
                                                            status:
                                                                n['status']),
                                                  ),
                                                );
                                              },
                                            ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 6)
                            ],
                          ),
                          child: const Icon(Icons.notifications_none,
                              size: 28, color: Colors.black),
                        ),
                        if (unreadCount > 0)
                          Positioned(
                            right: -4,
                            top: -4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: Colors.white, width: 1.5),
                              ),
                              child: Text(
                                unreadCount > 99 ? '99+' : '$unreadCount',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        if (unreadCount == 0 && _notificationItems.isNotEmpty)
                          Positioned(
                            right: -4,
                            top: -4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey,
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: Colors.white, width: 1.5),
                              ),
                              child: Text(
                                '0',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ========== TB SYMPTOMS CHECKER SECTION ==========
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.red.shade50,
                      Colors.orange.shade50,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: Colors.redAccent.withOpacity(0.3), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent.withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Do You Have These Symptoms?',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'With the following signs and symptoms for ≥ 2 weeks:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _symptomItem(Icons.sick, 'Cough'),
                      const SizedBox(height: 8),
                      _symptomItem(Icons.thermostat, 'Unexplained fever'),
                      const SizedBox(height: 8),
                      _symptomItem(
                          Icons.trending_down, 'Unexplained weight loss'),
                      const SizedBox(height: 8),
                      _symptomItem(Icons.nights_stay, 'Night sweat'),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.redAccent.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.redAccent,
                              size: 24,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.black87,
                                  ),
                                  children: const [
                                    TextSpan(
                                      text: 'If yes, ',
                                      style: TextStyle(
                                          fontWeight: FontWeight.normal),
                                    ),
                                    TextSpan(
                                      text:
                                          'you might have Tuberculosis (TB). ',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    TextSpan(
                                      text:
                                          'Don\'t ignore the signs — get checked today!',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              const Text('Quick Actions',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _quickAction(context, Icons.smart_toy, 'AI\nConsultant',
                      const GConsultant()),
                  _quickAction(context, Icons.calendar_today,
                      'Book\nAppointment', const Pdoclist()),
                  _quickAction(context, Icons.local_hospital,
                      'Facility\nLocator', PtbfacilityPage()),
                ],
              ),
              const SizedBox(height: 24),
              const Text('TB DOTS Commercial',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _isLoading
                          ? Container(
                              height: 200,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(16)),
                              ),
                              child: const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CircularProgressIndicator(
                                        color: Colors.redAccent),
                                    SizedBox(height: 8),
                                    Text('Loading video...',
                                        style:
                                            TextStyle(color: Colors.black54)),
                                  ],
                                ),
                              ),
                            )
                          : (_youtubeController != null
                              ? YoutubePlayer(
                                  controller: _youtubeController!,
                                  showVideoProgressIndicator: true,
                                )
                              : Container(
                                  height: 200,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(16)),
                                  ),
                                  child: const Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.video_library_outlined,
                                            size: 48, color: Colors.black54),
                                        SizedBox(height: 8),
                                        Text("No video available",
                                            style: TextStyle(
                                                color: Colors.black54)),
                                      ],
                                    ),
                                  ),
                                )),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          "Video content © Department of Health (DOH) Philippines & USAID.",
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.left,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Guidelines',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

              // ========== NTP MOP 6th Edition ==========
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.description_outlined,
                            size: 24, color: Colors.redAccent),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'NTP MOP 6th Edition',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Official tuberculosis guidelines',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(6),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PracticalPdfViewerScreen(
                                      source:
                                          'assets/documents/NTP_MOP_6TH_EDITION.pdf',
                                      sourceType: PdfSourceType.asset),
                                ),
                              );
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 15, vertical: 11),
                              child: Text(
                                'Open',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ========== TB Screening, Diagnosis and Management Pocket Guide ==========
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.medical_information_outlined,
                            size: 24, color: Colors.redAccent),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'TB (DS & DR) and Latent TB Screening, Diagnosis and Management Pocket Guide',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Comprehensive TB screening guidelines',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(6),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PracticalPdfViewerScreen(
                                      source:
                                          'assets/documents/TB_Screening,DiagnosisandManagement_PocketGuide.pdf',
                                      sourceType: PdfSourceType.asset),
                                ),
                              );
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 15, vertical: 11),
                              child: Text(
                                'Open',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  _showImageDialog(context);
                },
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        Image.asset('assets/images/guidelines.png',
                            fit: BoxFit.cover),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(
                              Icons.zoom_in,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _quickAction(
      BuildContext context, IconData icon, String label, Widget destination) {
    return GestureDetector(
      onTap: () async {
        // Only intercept for Book Appointment
        if (label.contains('Book')) {
          final user = FirebaseAuth.instance.currentUser;
          final patientEmail = user?.email;
          if (patientEmail == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('User not found. Please log in.')),
            );
            return;
          }
          final blockedStatuses = {
            'pending',
            'approved',
            'consultation completed'
          };
          // Fetch from both collections
          final pendingSnap = await FirebaseFirestore.instance
              .collection('pending_patient_data')
              .where('patientEmail', isEqualTo: patientEmail)
              .get();
          final approvedSnap = await FirebaseFirestore.instance
              .collection('approved_appointments')
              .where('patientEmail', isEqualTo: patientEmail)
              .get();
          // Check both collections for blocked statuses
          bool hasBlocked = false;
          for (final doc in pendingSnap.docs) {
            final status =
                (doc['status'] ?? '').toString().trim().toLowerCase();
            debugPrint('Checking pending_patient_data status: $status');
            if (blockedStatuses.contains(status)) {
              hasBlocked = true;
              break;
            }
          }
          if (!hasBlocked) {
            for (final doc in approvedSnap.docs) {
              final status =
                  (doc['status'] ?? '').toString().trim().toLowerCase();
              debugPrint('Checking approved_appointments status: $status');
              if (blockedStatuses.contains(status)) {
                hasBlocked = true;
                break;
              }
            }
          }
          if (hasBlocked) {
            showModalBottomSheet(
              context: context,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                side: BorderSide(color: Colors.white, width: 2),
              ),
              builder: (ctx) => Padding(
                padding: EdgeInsets.zero,
                child: Container(
                  color:
                      Colors.white, // Set the whole modal background to white
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.redAccent, size: 40),
                          const SizedBox(height: 16),
                          const Text(
                            'Ongoing Appointment',
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'You already have an ongoing appointment.\nPlease wait for it to be completed or rejected before booking another.',
                            style: TextStyle(fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('OK',
                                  style: TextStyle(fontSize: 16)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
            return;
          }
        }
        // Navigate to destination
        Navigator.push(
            context, MaterialPageRoute(builder: (context) => destination));
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.redAccent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: Colors.black26, blurRadius: 4, offset: Offset(2, 2))
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 4),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  // Helper method for symptom items
  static Widget _symptomItem(IconData icon, String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.redAccent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: Colors.redAccent,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}
