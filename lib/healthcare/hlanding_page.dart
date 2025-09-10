import 'package:flutter/material.dart';

class Hlandingpage extends StatefulWidget {
  const Hlandingpage({super.key});

  @override
  State<Hlandingpage> createState() => _HlandingpageState();
}

class _HlandingpageState extends State<Hlandingpage> {
  final List<Map<String, String>> conversations = [
    {"name": "Juan Dela Cruz", "message": "Kumusta ka na?"},
    {"name": "Cardo Dalisay", "message": "Magkita tayo bukas."},
    {"name": "Maria Clara", "message": "Salamat sa tulong mo."},
    {"name": "Andres Bonifacio", "message": "Nasaan ka ngayon?"},
    {"name": "Jose Rizal", "message": "May balita ka na ba?"},
  ];

  String searchQuery = "";

  @override
  Widget build(BuildContext context) {
    final filteredConversations = conversations
        .where((convo) =>
            convo["name"]!.toLowerCase().contains(searchQuery.toLowerCase()) ||
            convo["message"]!.toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();

    return Scaffold(
      backgroundColor: Colors.white,
      // AppBar with logo like landing page
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.white,
          elevation: 0,
          flexibleSpace: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(
                  left: 16, top: 16), // aligns with search bar
              child: Align(
                alignment: Alignment.centerLeft,
                child: Image.asset(
                  'assets/images/tbisita_logo2.png',
                  height: 44,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
      ),

      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Reduced vertical spacing between logo and search bar
          const SizedBox(height: 8), // <-- less space than before

          // Search bar like landing page
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(25),
              ),
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    searchQuery = value;
                  });
                },
                decoration: const InputDecoration(
                  icon: Icon(Icons.search, color: Colors.grey),
                  hintText: 'Search messages...',
                  border: InputBorder.none,
                ),
              ),
            ),
          ),

          // Messages list
          Expanded(
            child: ListView.builder(
              itemCount: filteredConversations.length,
              itemBuilder: (context, index) {
                final convo = filteredConversations[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.redAccent,
                    child: Text(
                      convo['name']![0],
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(
                    convo['name']!,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(convo['message']!),
                  onTap: () {
                    // TODO: Handle message tap
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
