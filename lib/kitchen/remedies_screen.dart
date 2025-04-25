import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:savr/themes/colors.dart';
import '../screens/home_screen.dart';
import '../kitchen/kitchen_screen.dart';

class RemediesScreen extends StatefulWidget {
  const RemediesScreen({Key? key}) : super(key: key);

  @override
  State<RemediesScreen> createState() => _RemediesScreenState();
}

class _RemediesScreenState extends State<RemediesScreen> {
  final TextEditingController _conditionController = TextEditingController();
  final String apiKey = "AIzaSyDXUcPiGbY1d9yDLO2Ps_Qxd2yzxkk7HYo";

  bool usePantryOnly = true;
  bool isLoading = false;
  bool showingSaved = false;
  int _selectedIndex = 0;

  List<Map<String, dynamic>> remedies = [];
  List<bool> isExpandedList = <bool>[];

  Future<List<String>> _fetchPantryItems() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('pantryItems')
        .get();

    return snapshot.docs
        .map((doc) => doc['name']?.toString().toLowerCase() ?? "")
        .where((name) => name.isNotEmpty)
        .toList();
  }

  Future<void> _generateRemedy() async {
    String condition = _conditionController.text.trim();
    if (condition.isEmpty) return;

    setState(() {
      isLoading = true;
      remedies.clear();
      isExpandedList =
          []; // ✅ create new empty list instead of clearing fixed-length one
      showingSaved = false;
    });

    final pantryItems = await _fetchPantryItems();

    String prompt = '''
Only reply with a clean JSON array of 3 natural home remedies for "$condition". Each remedy must follow this format:

[
  {
    "title": "Remedy title",
    "ingredients": ["ingredient 1", "ingredient 2"],
    "steps": ["step 1", "step 2"]
  }
]

Use only ingredients from: ${usePantryOnly ? pantryItems.join(", ") : "anywhere"}.
Do NOT add any markdown or explanations. Just return raw JSON.
''';

    final url = Uri.parse(
        "https://generativelanguage.googleapis.com/v1/models/gemini-1.5-pro:generateContent?key=$apiKey");

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "contents": [
          {
            "parts": [
              {"text": prompt}
            ]
          }
        ]
      }),
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final rawText = decoded['candidates'][0]['content']['parts'][0]['text'];

      final regex = RegExp(r'\[.*\]', dotAll: true);
      final match = regex.firstMatch(rawText);

      if (match != null) {
        final cleanedJson = match.group(0)!;
        final parsed = jsonDecode(cleanedJson);

        setState(() {
          remedies = List<Map<String, dynamic>>.from(parsed);
          isExpandedList = List<bool>.filled(remedies.length, false);
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Could not parse remedy format. Try again.")),
        );
      }
    } else {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Gemini API error. Try again.")),
      );
    }
  }

  Future<void> _saveRemedy(Map<String, dynamic> remedy) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('saved_remedies')
        .add({
      'title': remedy['title'],
      'ingredients': remedy['ingredients'],
      'steps': remedy['steps'],
      'timestamp': Timestamp.now(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("${remedy['title']} saved!")),
    );
  }

  void _onBottomNavTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomeScreen()),
        );
        break;
      case 1:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const KitchenScreen()),
        );
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/medicines');
        break;
      case 3:
        Navigator.pushReplacementNamed(context, '/health');
        break;
      case 4:
        Navigator.pushReplacementNamed(context, '/feed');
        break;
    }
  }

  void _showSavedRemediesDialog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('saved_remedies')
        .orderBy('timestamp', descending: true)
        .get();

    final remedies = snapshot.docs;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Saved Remedies"),
        content: remedies.isEmpty
            ? const Text("No remedies saved yet.")
            : SizedBox(
                width: double.maxFinite,
                height: 400,
                child: ListView.builder(
                  itemCount: remedies.length,
                  itemBuilder: (context, index) {
                    final data = remedies[index].data();
                    final docId = remedies[index].id;

                    return Card(
                      child: ExpansionTile(
                        title: Text(data['title'] ?? "No Title",
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        children: [
                          const Text("Ingredients:",
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          ...List.from(data['ingredients'] ?? [])
                              .map((e) => Text("- $e")),
                          const SizedBox(height: 5),
                          const Text("Steps:",
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          ...List.from(data['steps'] ?? [])
                              .map((e) => Text("• $e")),
                          const SizedBox(height: 10),
                          TextButton.icon(
                            onPressed: () async {
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(user.uid)
                                  .collection('saved_remedies')
                                  .doc(docId)
                                  .delete();

                              Navigator.pop(context); // Close the dialog
                              _showSavedRemediesDialog(); // Reload
                            },
                            icon: const Icon(Icons.delete, color: Colors.red),
                            label: const Text("Delete",
                                style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          )
        ],
      ),
    );
  }

  Widget _buildRemedyCard(
      Map<String, dynamic> remedy, bool isExpanded, int index) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          ListTile(
            title: Text(remedy['title'] ?? "",
                style: const TextStyle(fontWeight: FontWeight.bold)),
            trailing: IconButton(
              icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
              onPressed: () {
                setState(() {
                  isExpandedList[index] = !isExpanded;
                });
              },
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Ingredients:",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  ...List.from(remedy['ingredients'])
                      .map((item) => Text("- $item")),
                  const SizedBox(height: 8),
                  const Text("Steps:",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  ...List.from(remedy['steps']).map((step) => Text("• $step")),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: () => _saveRemedy(remedy),
                    icon: const Icon(Icons.save),
                    label: const Text("Save Remedy"),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _loadSavedRemedies() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      isLoading = true;
      showingSaved = true;
      remedies.clear();
    });

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('saved_remedies')
        .orderBy('timestamp', descending: true)
        .get();

    final List<Map<String, dynamic>> loaded = snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        "title": data['title'],
        "ingredients": List<String>.from(data['ingredients'] ?? []),
        "steps": List<String>.from(data['steps'] ?? [])
      };
    }).toList();

    setState(() {
      remedies = loaded;
      isExpandedList = List<bool>.filled(remedies.length, false);
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Home Remedies"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (!showingSaved) ...[
              const Text(
                "Describe your condition",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: NudePalette.darkBrown,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _conditionController,
                decoration: InputDecoration(
                  labelText: "Describe your condition",
                  filled: true,
                  fillColor: NudePalette.paleBlush,
                  labelStyle: const TextStyle(color: NudePalette.darkBrown),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                        color: NudePalette.mauveBrown, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Use pantry items only"),
                  Switch(
                    value: usePantryOnly,
                    onChanged: (val) {
                      setState(() {
                        usePantryOnly = val;
                      });
                    },
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: _generateRemedy,
                child: const Text("Generate Remedies"),
              ),
              const SizedBox(height: 10),
            ],
            if (isLoading) const CircularProgressIndicator(),
            if (!isLoading && remedies.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  itemCount: remedies.length,
                  itemBuilder: (context, index) {
                    return _buildRemedyCard(
                        remedies[index], isExpandedList[index], index);
                  },
                ),
              ),
            if (!isLoading && remedies.isEmpty && showingSaved)
              const Text("No saved remedies yet."),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(color: Colors.black38, blurRadius: 10, spreadRadius: 2),
          ],
        ),
        margin: const EdgeInsets.all(15),
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white60,
          currentIndex: _selectedIndex,
          onTap: _onBottomNavTapped,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
            BottomNavigationBarItem(
                icon: Icon(Icons.kitchen), label: "Kitchen"),
            BottomNavigationBarItem(
                icon: Icon(Icons.medical_services), label: "Medicines"),
            BottomNavigationBarItem(
                icon: Icon(Icons.favorite), label: "Health"),
            //BottomNavigationBarItem(icon: Icon(Icons.rss_feed), label: "Feed"),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showSavedRemediesDialog,
        icon: const Icon(Icons.bookmark),
        label: const Text("Saved Remedies"),
        backgroundColor: NudePalette.mauveBrown,
        foregroundColor: Colors.white,
      ),
    );
  }
}
