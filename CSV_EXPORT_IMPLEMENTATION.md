# Quick Implementation: Enhanced CSV Export 🚀

## Add This to Your pubspec.yaml

```yaml
dependencies:
  share_plus: ^7.2.2  # Add this line
```

Then run: `flutter pub get`

---

## Replace Your Success SnackBar in dpost.dart

**Find this section (around line 660-720):**

```dart
if (mounted) {
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Report generated successfully!'),
                Text(
                  'Found ${rows.length - 1} patients',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
      backgroundColor: Colors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      action: SnackBarAction(
        label: 'Open',
        textColor: Colors.white,
        onPressed: () async {
          try {
            final result = await OpenFile.open(filePath);
            debugPrint('Open file result: ${result.type} - ${result.message}');
          } catch (e) {
            debugPrint('Error opening file: $e');
          }
        },
      ),
      duration: const Duration(seconds: 5),
    ),
  );
```

**Replace with:**

```dart
if (mounted) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Report generated successfully!'),
                    Text(
                      'Found ${rows.length - 1} patients',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '📁 $fileName',
            style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tap "OPTIONS" to open or share',
            style: TextStyle(fontSize: 10, color: Colors.white70),
          ),
        ],
      ),
      backgroundColor: Colors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      action: SnackBarAction(
        label: 'OPTIONS',
        textColor: Colors.white,
        onPressed: () {
          _showFileOptionsDialog(filePath, fileName);
        },
      ),
      duration: const Duration(seconds: 8),
    ),
  );
}
```

---

## Add This Method to Your _DpostappointmentState Class

**Add this new method anywhere in the class (before the closing brace):**

```dart
// Show file options dialog (Open or Share)
void _showFileOptionsDialog(String filePath, String fileName) {
  showDialog(
    context: context,
    barrierColor: Colors.black.withOpacity(0.5),
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      elevation: 16,
      backgroundColor: Colors.white,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4CAF50).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.file_present_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Report Ready',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Choose how to view',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // File info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.insert_drive_file, size: 16, color: Colors.green.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          fileName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade900,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Options
            Column(
              children: [
                // Open with Excel/Sheets
                _buildFileOption(
                  icon: Icons.table_chart_rounded,
                  iconColor: Colors.green,
                  title: 'Open with Excel/Sheets',
                  subtitle: 'View in spreadsheet app',
                  onTap: () async {
                    Navigator.pop(context);
                    try {
                      final result = await OpenFile.open(filePath);
                      if (result.type != ResultType.done) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Row(
                                children: [
                                  Icon(Icons.info_outline, color: Colors.white),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text('Please install Excel, Google Sheets, or WPS Office app'),
                                  ),
                                ],
                              ),
                              backgroundColor: Colors.orange,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        }
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error opening file: $e'),
                            backgroundColor: Colors.red,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      }
                    }
                  },
                ),
                
                const SizedBox(height: 12),
                
                // Share file
                _buildFileOption(
                  icon: Icons.share_rounded,
                  iconColor: Colors.blue,
                  title: 'Share via...',
                  subtitle: 'Send via WhatsApp, Email, etc.',
                  onTap: () async {
                    Navigator.pop(context);
                    try {
                      await Share.shareXFiles(
                        [XFile(filePath)],
                        text: 'TB Patient Report',
                        subject: fileName,
                      );
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error sharing file: $e'),
                            backgroundColor: Colors.red,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Close button
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Close',
                  style: TextStyle(
                    color: Colors.grey.shade600,
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

// Helper widget for file options
Widget _buildFileOption({
  required IconData icon,
  required Color iconColor,
  required String title,
  required String subtitle,
  required VoidCallback onTap,
}) {
  return InkWell(
    borderRadius: BorderRadius.circular(12),
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: iconColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios, size: 16, color: iconColor),
        ],
      ),
    ),
  );
}
```

---

## Add Import at the Top of dpost.dart

**Add this import at the top of your file:**

```dart
import 'package:share_plus/share_plus.dart';
```

---

## That's It! 🎉

Now your export will:
1. ✅ Generate CSV file
2. ✅ Show success message with filename
3. ✅ Provide "OPTIONS" button
4. ✅ Open dialog with:
   - "Open with Excel/Sheets" - Opens in installed app
   - "Share via..." - Share to any app
5. ✅ Better user experience!

---

## Apply Same Changes to dhistory.dart

Just repeat the same steps in `dhistory.dart`:
1. Add `share_plus` import
2. Replace the success SnackBar
3. Add the `_showFileOptionsDialog()` method
4. Add the `_buildFileOption()` method

Done! 🚀
