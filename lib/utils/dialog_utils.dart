import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DialogUtils {
  static Future<String?> showPasswordConfirmDialog(BuildContext context) async {
    final passwordController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Confirm Current Password',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
            ),
          ),
          content: TextField(
            controller: passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Current Password',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Confirm'),
              onPressed: () =>
                  Navigator.of(context).pop(passwordController.text),
            ),
          ],
        );
      },
    );

    return result;
  }
}
