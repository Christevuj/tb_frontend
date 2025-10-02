import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import 'chat_screen.dart';

class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});
  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  final ChatService _chatService = ChatService();

  // For testing: set currentUserId manually until you add Firebase Auth
  // Change this value to test patient / doctor / healthcare roles.
  final String currentUserId = 'patient123';

  String? currentUserRole;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final role = await _chatService.getUserRole(currentUserId);
    setState(() {
      currentUserRole = role ?? 'patient';
    });
  }

  @override
  Widget build(BuildContext context) {
    // still loading role
    if (currentUserRole == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Determine which roles to show as contacts
    final List<String> showRoles = (currentUserRole == 'patient')
        ? ['doctor', 'healthcare']
        : ['patient']; // doctors & healthcare only see patients

    return Scaffold(
      appBar: AppBar(title: const Text('Contacts')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _chatService.streamUsers(), // streams documents from "users"
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No users found.'));
          }

          // Filter out current user and roles not allowed to be shown
          final allUsers = snapshot.data!;
          final users = allUsers
              .where((u) =>
                  u['id'] != currentUserId &&
                  u['role'] != null &&
                  showRoles.contains(u['role']))
              .toList();

          if (users.isEmpty) {
            return const Center(child: Text('No contacts found.'));
          }

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, i) {
              final u = users[i];
              final displayName =
                  (u['name'] ?? u['fullName'] ?? u['id']).toString();
              final role = (u['role'] ?? '').toString();

              return ListTile(
                title: Text(displayName),
                subtitle: Text(role),
                onTap: () {
                  // Navigate to ChatScreen (ChatScreen will generate chatId automatically)
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        currentUserId: currentUserId,
                        otherUserId: u['id'],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
