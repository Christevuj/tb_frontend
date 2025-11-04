import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Simple dialog that renders a QR code for an install URL.
///
/// Usage: Navigator.of(context).push(MaterialPageRoute(builder: (_) =>
/// InstallQrDialog(initialUrl: 'https://play.google.com/store/apps/details?id=your.app.id')));
class InstallQrDialog extends StatefulWidget {
  final String initialUrl;
  const InstallQrDialog({super.key, required this.initialUrl});

  @override
  State<InstallQrDialog> createState() => _InstallQrDialogState();
}

class _InstallQrDialogState extends State<InstallQrDialog> {
  late TextEditingController controller;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.initialUrl);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _exportQrPng() async {
    try {
      setState(() => _isSaving = true);

      final painter = QrPainter(
        data: controller.text,
        version: QrVersions.auto,
        gapless: true,
      );

      final picData =
          await painter.toImageData(800, format: ui.ImageByteFormat.png);
      final bytes = picData!.buffer.asUint8List();

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/tb_install_qr.png');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles([XFile(file.path)], text: 'TBisita install QR');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export QR: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Install App via QR', style: GoogleFonts.poppins()),
        backgroundColor: const Color(0xFFEF4444),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Scan this QR code from your phone to open the app installer or Play Store page.',
              style: GoogleFonts.poppins(fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: QrImageView(
                  data: controller.text,
                  size: 220,
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Install URL',
                hintText:
                    'https://play.google.com/store/apps/details?id=your.app.id',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    // copy link
                    Clipboard.setData(ClipboardData(text: controller.text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Link copied to clipboard')),
                    );
                  },
                ),
              ),
              onChanged: (_) {
                // rebuild to update QR - in this simple stateless widget the QR won't rebuild automatically
                // but for immediate effect the user can press the refresh button below
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSaving
                        ? null
                        : () {
                            // Rebuild by pushing a new page with the updated URL
                            Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                    builder: (_) => InstallQrDialog(
                                        initialUrl: controller.text)));
                          },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh QR'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _exportQrPng,
                    icon: const Icon(Icons.download_rounded),
                    label: Text(_isSaving ? 'Saving...' : 'Download PNG'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
