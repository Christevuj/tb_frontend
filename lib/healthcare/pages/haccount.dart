import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tb_frontend/login_screen.dart';

class HAccount extends StatelessWidget {
  const HAccount({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Healthcare Worker Account'),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TBisitaLoginScreen(),
                    ),
                    (route) => false, // This will remove all previous routes
                  );
                }
              },
              child: Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }
}
