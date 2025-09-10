import 'package:flutter/material.dart';
import 'package:tb_frontend/guest/gviewdoctor.dart';
import 'package:tb_frontend/guest/gappointment.dart';
import 'package:tb_frontend/guest/gconsultant.dart';
import 'package:tb_frontend/features/map/map_screen_enhanced.dart';

// ✅ Import YouTube player
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

// PDF viewer screen (create file as shown below)
import 'pdf_viewer_screen.dart';

class GlandingPage extends StatefulWidget {
  const GlandingPage({super.key});

  @override
  State<GlandingPage> createState() => _GlandingPageState();
}

class _GlandingPageState extends State<GlandingPage> {
  late YoutubePlayerController _youtubeController;

  @override
  void initState() {
    super.initState();

    const videoUrl =
        "https://www.youtube.com/watch?v=VCPngZ5oxGI"; // DOH–USAID TBDOTS Commercial
    final videoId = YoutubePlayer.convertUrlToId(videoUrl)!;

    _youtubeController = YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: false,
        mute: false,
      ),
    );
  }

  @override
  void dispose() {
    _youtubeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo
            Image.asset(
              "assets/images/tbisita_logo2.png",
              height: 44,
              alignment: Alignment.centerLeft,
            ),
            const SizedBox(height: 20),

            // Quick Actions
            const Text(
              'Quick Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _quickAction(
                  context,
                  Icons.smart_toy,
                  'AI\nConsultant',
                  const GConsultant(),
                ),
                _quickAction(
                  context,
                  Icons.calendar_today,
                  'Book\nAppointment',
                  const Gappointment(),
                ),
                _quickAction(
                  context,
                  Icons.local_hospital,
                  'TB DOTS\nFacilities',
                  const MapScreenEnhanced(),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // --- EMBEDDED YOUTUBE VIDEO ---
            const Text(
              'TB DOTS Commercial',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: YoutubePlayer(
                controller: _youtubeController,
                showVideoProgressIndicator: true,
              ),
            ),

            // ✅ Disclaimer below the video
            const SizedBox(height: 8),
            const Text(
              "Video content © Department of Health (DOH) Philippines & USAID.",
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),

            // PDF preview + open button
            const Text(
              'Guidelines (NTP MOP - 6th Edition)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 2,
              color: Colors.white, // ✅ White background
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: const Icon(Icons.picture_as_pdf,
                    size: 32, color: Colors.red),
                title: const Text(
                  'NTP_MOP_6TH_EDITION.pdf',
                  style: TextStyle(fontSize: 14), // ✅ Smaller font
                  overflow: TextOverflow.ellipsis, // ✅ Single line only
                ),
                trailing: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PdfViewerScreen(
                            assetPath:
                                'assets/documents/NTP_MOP_6TH_EDITION.pdf'),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey, // ✅ Gray button
                    foregroundColor: Colors.white, // ✅ White text
                  ),
                  child: const Text('Open PDF'),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Image: guidelines.png (directly below PDF, no title text)
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/images/guidelines.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  static Widget _quickAction(
      BuildContext context, IconData icon, String label, Widget destination) {
    return GestureDetector(
      onTap: () {
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
                  color: Colors.black26,
                  blurRadius: 4,
                  offset: Offset(2, 2),
                )
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
