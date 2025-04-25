import 'package:flutter/material.dart';
import 'ideal_screen.dart'; // ✅ Import next screen
import 'package:savr/services/firestore_service.dart'; // ✅ Import FirestoreService

class DetailsScreen extends StatefulWidget {
  final String userName;
  final String goal;

  DetailsScreen(
      {required this.userName, required this.goal}); // ✅ Require parameters

  @override
  _DetailsScreenState createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  final TextEditingController ageController = TextEditingController();
  final TextEditingController heightController = TextEditingController();
  final TextEditingController weightController = TextEditingController();
  final FirestoreService _firestoreService =
      FirestoreService(); // ✅ Initialize Firestore Service

  bool showAgeField = false;
  bool showHeightField = false;
  bool showWeightField = false;
  bool allFieldsCompleted = false;
  bool _isLoading = false; // ✅ Loading state

  void _onAgeEntered(String value) {
    if (value.isNotEmpty) {
      setState(() => showHeightField = true);
    }
  }

  void _onHeightEntered(String value) {
    if (value.isNotEmpty) {
      setState(() => showWeightField = true);
    }
  }

  void _onWeightEntered(String value) {
    if (value.isNotEmpty) {
      setState(() => allFieldsCompleted = true);
    }
  }

  void _navigateToNext() async {
    if (!allFieldsCompleted) return;

    setState(() => _isLoading = true); // ✅ Show loading state

    try {
      Map<String, dynamic> updatedData = {
        'age': int.parse(ageController.text),
        'height': int.parse(heightController.text),
        'weight': int.parse(weightController.text),
      };

      await _firestoreService
          .saveUserData(updatedData); // ✅ Store details in Firestore

      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => IdealScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    } finally {
      setState(() => _isLoading = false); // ✅ Hide loading state
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 50),
            Text(
              "Goal & profile",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            SizedBox(height: 10),
            LinearProgressIndicator(
              value: 0.4,
              backgroundColor: Colors.grey[300],
              color: Colors.orange,
            ),
            SizedBox(height: 30),

            // Age Input Field
            _buildInputField("How old are you?", ageController, _onAgeEntered),

            // Height Input Field
            if (showHeightField)
              _buildInputField(
                  "What is your height?", heightController, _onHeightEntered,
                  suffix: "cm"),

            // Weight Input Field
            if (showWeightField)
              _buildInputField(
                  "What is your weight?", weightController, _onWeightEntered,
                  suffix: "kg"),

            SizedBox(height: 30),

            // ✅ "Next" Button (Appears when all fields are filled)
            if (allFieldsCompleted)
              Center(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _navigateToNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                  ),
                  child: _isLoading
                      ? CircularProgressIndicator(
                          color: Colors.white) // ✅ Show loader
                      : Text("Next", style: TextStyle(color: Colors.white)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller,
      Function(String) onChanged,
      {String? suffix}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 18)),
        SizedBox(height: 10),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            suffixIcon: suffix != null
                ? Padding(
                    padding: EdgeInsets.only(right: 10),
                    child: Text(suffix,
                        style: TextStyle(fontSize: 16, color: Colors.orange)),
                  )
                : null,
          ),
        ),
        SizedBox(height: 20),
      ],
    );
  }
}
