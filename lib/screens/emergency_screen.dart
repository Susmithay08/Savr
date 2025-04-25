import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:savr/themes/colors.dart';

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({Key? key}) : super(key: key);

  @override
  _EmergencyScreenState createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  // For bottom navigation:
  int _selectedIndex = 0;

  // Store user name & emergency contacts from Firestore.
  String userName = "User";
  List<Map<String, String>> emergencyContacts = [];

  // Controllers for adding a new contact.
  final TextEditingController _contactNameController = TextEditingController();
  final TextEditingController _contactPhoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUserName();
    _fetchEmergencyContacts();
  }

  // Fetch the current user's display name.
  Future<void> _fetchUserName() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        userName = user.displayName ?? "User";
      });
    }
  }

  // Load emergency contacts from Firestore.
  Future<void> _fetchEmergencyContacts() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    DocumentSnapshot doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (doc.exists &&
        doc.data() != null &&
        doc.data().toString().contains('emergencyContacts')) {
      List<dynamic>? contacts = doc.get('emergencyContacts');
      if (contacts != null) {
        setState(() {
          emergencyContacts = contacts
              .map((c) => {
                    'name': c['name'] as String,
                    'phone': c['phone'] as String,
                  })
              .toList();
        });
      }
    } else {
      setState(() {
        emergencyContacts = [];
      });
    }
  }

  // Add a new contact locally & update Firestore.
  Future<void> _addEmergencyContact(String name, String phone) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() {
      emergencyContacts.add({'name': name, 'phone': phone});
    });
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'emergencyContacts': emergencyContacts,
    });
  }

  // Remove a contact and update Firestore.
  Future<void> _removeEmergencyContact(int index) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() {
      emergencyContacts.removeAt(index);
    });
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'emergencyContacts': emergencyContacts,
    });
  }

  // Send the SOS SMS.
  Future<void> _sendSOSMessage() async {
    if (emergencyContacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("No emergency contacts added.")));
      return;
    }

    // Build a comma-separated string of phone numbers.
    final String phoneNumbers =
        emergencyContacts.map((c) => c['phone']!).join(",");

    // Build the SMS URL using legacy style.
    final String url =
        "sms:$phoneNumbers?body=${Uri.encodeComponent("Hey, $userName needs your help!")}";
    print("SMS URL: $url");

    if (await canLaunch(url)) {
      await launch(url);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Could not launch SMS app.")));
    }
  }

  // Show dialog to add a new emergency contact.
  void _showAddContactDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text("Add Emergency Contact"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _contactNameController,
                decoration: InputDecoration(labelText: "Contact Name"),
              ),
              TextField(
                controller: _contactPhoneController,
                decoration: InputDecoration(labelText: "Phone Number"),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _contactNameController.clear();
                _contactPhoneController.clear();
              },
              child: Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_contactNameController.text.trim().isNotEmpty &&
                    _contactPhoneController.text.trim().isNotEmpty) {
                  await _addEmergencyContact(
                    _contactNameController.text.trim(),
                    _contactPhoneController.text.trim(),
                  );
                  Navigator.pop(ctx);
                  _contactNameController.clear();
                  _contactPhoneController.clear();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text("Please enter both name and phone.")));
                }
              },
              child: Text("Add"),
            ),
          ],
        );
      },
    );
  }

  // Basic bottom navigation logic.
  void _onNavItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // Implement navigation to other screens as needed.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Emergency Assistance",
            style: TextStyle(color: NudePalette.darkBrown)),
        backgroundColor: NudePalette.lightCream,
        iconTheme: IconThemeData(color: NudePalette.darkBrown),
      ),

      backgroundColor: NudePalette.lightCream,

      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(height: 20),
            Text(
              "Are you in an emergency?",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 5),
            Text(
              "Press the SOS button and help will reach you soon.",
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            SizedBox(height: 30),
            // Large SOS button.
            GestureDetector(
              onTap: _sendSOSMessage,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    "SOS",
                    style: TextStyle(
                      fontSize: 40,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),
            // Emergency contacts list.
            Expanded(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: emergencyContacts.isEmpty
                    ? Center(
                        child: Text(
                          "No emergency contacts added yet.",
                          style: TextStyle(
                              fontSize: 16, color: NudePalette.darkBrown),
                        ),
                      )
                    : ListView.builder(
                        itemCount: emergencyContacts.length,
                        itemBuilder: (context, index) {
                          final contact = emergencyContacts[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: NudePalette.paleBlush,
                              child: Text(
                                contact['name']![0],
                                style: TextStyle(color: Colors.black),
                              ),
                            ),
                            title: Text(contact['name']!),
                            subtitle: Text(contact['phone']!),
                            trailing: IconButton(
                              icon: Icon(
                                Icons.delete,
                                color: NudePalette.mauveBrown,
                              ),
                              onPressed: () => _removeEmergencyContact(index),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
      // Floating button to add new contacts.
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddContactDialog,
        backgroundColor: NudePalette.darkBrown,
        child: Icon(Icons.add, color: NudePalette.lightCream),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      // Bottom Navigation Bar.
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: NudePalette.darkBrown,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: NudePalette.darkBrown.withOpacity(0.4),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        margin: EdgeInsets.all(15),
        padding: EdgeInsets.symmetric(vertical: 10),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          selectedItemColor: NudePalette.lightCream,
          unselectedItemColor: NudePalette.lightCream.withOpacity(0.6),
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() => _selectedIndex = index);

            if (index == 0) {
              Navigator.pushReplacementNamed(context, "/home");
            } else if (index == 1) {
              Navigator.pushReplacementNamed(context, "/kitchen");
            } else if (index == 2) {
              Navigator.pushReplacementNamed(context, "/medicines");
            } else if (index == 3) {
              Navigator.pushReplacementNamed(context, "/health");
            } else if (index == 4) {
              // TODO: Navigate to Feed screen
            }
          },
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
    );
  }
}
