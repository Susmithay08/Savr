import 'package:flutter/material.dart';
import 'disease_screen.dart';
import 'package:savr/services/firestore_service.dart';

class AllergyScreen extends StatefulWidget {
  @override
  _AllergyScreenState createState() => _AllergyScreenState();
}

class _AllergyScreenState extends State<AllergyScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  List<String> allergies = [
    "Veganism",
    "Vegetarianism",
    "Pescetarianism",
    "Gluten-Free",
    "Lactose Intolerant",
    "Nut Allergy",
    "Seafood or Shellfish",
    "Religious restriction",
    "Other",
    "None"
  ];

  List<String> selectedAllergies = [];
  bool _isLoading = false;

  void _toggleSelection(String allergy) {
    setState(() {
      if (allergy == "None" || allergy == "Other") {
        if (selectedAllergies.contains(allergy)) {
          selectedAllergies.remove(allergy);
        } else {
          selectedAllergies = [allergy];
        }
      } else {
        if (selectedAllergies.contains(allergy)) {
          selectedAllergies.remove(allergy);
        } else {
          selectedAllergies
              .removeWhere((item) => item == "None" || item == "Other");
          selectedAllergies.add(allergy);
        }
      }
    });
  }

  void _navigateToNext() async {
    if (selectedAllergies.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please select at least one option.")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _firestoreService.updateUserField('allergies', selectedAllergies);

      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => DiseaseScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: ${e.toString()}")));
    } finally {
      setState(() => _isLoading = false);
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
              value: 0.8,
              backgroundColor: Colors.grey[300],
              color: Colors.orange,
            ),
            SizedBox(height: 30),
            Text("Which restrictions/allergies do you have?",
                style: TextStyle(fontSize: 18)),
            SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: allergies.length,
                itemBuilder: (context, index) {
                  final allergy = allergies[index];
                  final isNoneOrOther = allergy == "None" || allergy == "Other";
                  final hasNoneOrOtherSelected = selectedAllergies
                      .any((item) => item == "None" || item == "Other");

                  return CheckboxListTile(
                    title: Text(allergy),
                    value: selectedAllergies.contains(allergy),
                    onChanged: (hasNoneOrOtherSelected &&
                            !selectedAllergies.contains(allergy) &&
                            !isNoneOrOther)
                        ? null
                        : (_) => _toggleSelection(allergy),
                  );
                },
              ),
            ),
            Center(
              child: ElevatedButton(
                onPressed: _isLoading ? null : _navigateToNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                ),
                child: _isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text("Next", style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
