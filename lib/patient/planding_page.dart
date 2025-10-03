import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tb_frontend/patient/pdoclist.dart';
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

  @override
  void initState() {
    super.initState();
    _loadYoutubeUrl();
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
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset("assets/images/tbisita_logo2.png",
                  height: 44, alignment: Alignment.centerLeft),
              const SizedBox(height: 20),
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
                  child: Column(
                    children: [
                      Row(
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
                                      builder: (_) =>
                                          const PracticalPdfViewerScreen(
                                              assetPath:
                                                  'assets/documents/NTP_MOP_6TH_EDITION.pdf'),
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
}
