import 'package:flutter/material.dart';
import 'package:savr/services/firestore_service.dart'; // ✅ Import FirestoreService
import 'allergy_screen.dart'; // ✅ Import AllergyScreen
import 'disease_screen.dart'; // ✅ Import DiseaseScreen

class DietScreen extends StatefulWidget {
  @override
  _DietScreenState createState() => _DietScreenState();
}

class _DietScreenState extends State<DietScreen> {
  final FirestoreService _firestoreService =
      FirestoreService(); // ✅ Initialize Firestore Service
  bool _isLoading = false; // ✅ Loading state
  String? _selectedOption;

  Future<void> _navigateToNext(String option) async {
    setState(() => _selectedOption = option); // ✅ Track selected

    try {
      if (option == "Yes") {
        await _firestoreService.updateUserField('hasDietaryRestrictions', true);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => AllergyScreen()),
        );
      } else {
        await _firestoreService.updateUserField(
            'hasDietaryRestrictions', false);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => DiseaseScreen()),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    } finally {
      setState(() => _selectedOption = null); // Reset after nav
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
              value: 0.7, // ✅ Progress updated
              backgroundColor: Colors.grey[300],
              color: Colors.orange,
            ),
            SizedBox(height: 30),

            // Image
            Center(child: Image.asset('assets/diet.png', width: 200)),
            SizedBox(height: 30),

            // Question
            Text(
              "Do you have any dietary restrictions or food allergies?",
              style: TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 30),

            // Yes / No Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildOptionButton("Yes"),
                SizedBox(width: 20),
                _buildOptionButton("No"),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionButton(String text) {
    final isSelected = _selectedOption == text;

    return GestureDetector(
      onTap: _selectedOption != null ? null : () => _navigateToNext(text),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(vertical: 15, horizontal: 30),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 16,
            color: isSelected ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }
}
