import 'package:flutter/material.dart';
import 'package:savr/services/firestore_service.dart'; // ✅ Import FirestoreService
import 'goal_selection_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NameInputScreen extends StatefulWidget {
  @override
  _NameInputScreenState createState() => _NameInputScreenState();
}

class _NameInputScreenState extends State<NameInputScreen> {
  final TextEditingController _nameController = TextEditingController();
  final FirestoreService _firestoreService =
      FirestoreService(); // ✅ Initialize Firestore Service
  bool _isLoading = false; // ✅ Show loading state

  Future<void> _navigateToNext() async {
    String name = _nameController.text.trim();
    User? user = FirebaseAuth.instance.currentUser; // ✅ User now exists

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enter your name.")),
      );
      return;
    }

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text("Error: User not logged in.")), // ✅ Show error if no user
      );
      return;
    }

    setState(() => _isLoading = true); // ✅ Show loading

    try {
      // ✅ Store name in Firestore (Now Works!)
      await _firestoreService.updateUserField('displayName', name);

      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => GoalSelectionScreen(userName: name)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    } finally {
      setState(() => _isLoading = false); // ✅ Hide loading
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/sunflower.png', width: 250),
            SizedBox(height: 20),
            Text("Welcome",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Text("Let's get to know each other 😊"),
            SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: "First Name",
                filled: true,
                fillColor: Colors.grey[200],
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _navigateToNext,
              child: _isLoading
                  ? CircularProgressIndicator(
                      color: Colors.white) // ✅ Show loader
                  : Text("Next"),
            ),
          ],
        ),
      ),
    );
  }
}
