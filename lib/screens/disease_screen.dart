import 'package:flutter/material.dart';
import 'processing_screen.dart';
import 'package:savr/services/firestore_service.dart';

class DiseaseScreen extends StatefulWidget {
  @override
  _DiseaseScreenState createState() => _DiseaseScreenState();
}

class _DiseaseScreenState extends State<DiseaseScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  List<String> conditions = [
    "Hypertension or high blood pressure",
    "Diabetes",
    "Depression",
    "Eating disorders (Anorexia, Bulimia)",
    "Other",
    "None"
  ];

  List<String> selectedConditions = [];
  bool _isLoading = false;

  void _toggleSelection(String condition) {
    setState(() {
      if (condition == "None" || condition == "Other") {
        if (selectedConditions.contains(condition)) {
          selectedConditions.remove(condition);
        } else {
          selectedConditions = [condition];
        }
      } else {
        if (selectedConditions.contains(condition)) {
          selectedConditions.remove(condition);
        } else {
          selectedConditions
              .removeWhere((item) => item == "None" || item == "Other");
          selectedConditions.add(condition);
        }
      }
    });
  }

  void _navigateToNext() async {
    if (selectedConditions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please select at least one condition.")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _firestoreService.updateUserField(
          'medicalConditions', selectedConditions);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => ProcessingScreen()),
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
              value: 1.0,
              backgroundColor: Colors.grey[300],
              color: Colors.orange,
            ),
            SizedBox(height: 30),
            Text("Have you ever had any of the following conditions?",
                style: TextStyle(fontSize: 18)),
            SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: conditions.length,
                itemBuilder: (context, index) {
                  final condition = conditions[index];
                  final isNoneOrOther =
                      condition == "None" || condition == "Other";
                  final hasNoneOrOtherSelected = selectedConditions
                      .any((item) => item == "None" || item == "Other");

                  return CheckboxListTile(
                    title: Text(condition),
                    value: selectedConditions.contains(condition),
                    onChanged: (hasNoneOrOtherSelected &&
                            !selectedConditions.contains(condition) &&
                            !isNoneOrOther)
                        ? null
                        : (_) => _toggleSelection(condition),
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
