import 'package:flutter/material.dart';
import 'package:savr/services/firestore_service.dart'; // ✅ Import FirestoreService
import 'final_message_screen.dart';

class ReasonSelectionScreen extends StatefulWidget {
  final String userName;
  final String goal;

  ReasonSelectionScreen({required this.userName, required this.goal});

  @override
  _ReasonSelectionScreenState createState() => _ReasonSelectionScreenState();
}

class _ReasonSelectionScreenState extends State<ReasonSelectionScreen> {
  final FirestoreService _firestoreService =
      FirestoreService(); // ✅ Initialize Firestore Service
  List<String> reasons = [
    "Feel better in my body",
    "Be healthier",
    "Get in shape",
    "Fit in my old clothes",
    "Be more energetic",
    "Move better or improve at a sport",
    "Improve my Mental Health",
    "For my family",
    "For Medical issues",
    "Live Longer",
    "Other Reasons"
  ];

  List<String> selectedReasons = [];
  bool _isLoading = false; // ✅ Loading state

  void _toggleSelection(String reason) {
    setState(() {
      if (reason == "Other Reasons") {
        if (selectedReasons.contains("Other Reasons")) {
          selectedReasons.remove("Other Reasons");
        } else {
          selectedReasons = ["Other Reasons"];
        }
      } else {
        if (selectedReasons.contains(reason)) {
          selectedReasons.remove(reason);
        } else {
          // If "Other Reasons" was selected, remove it first
          selectedReasons.remove("Other Reasons");
          selectedReasons.add(reason);
        }
      }
    });
  }

  Future<void> _navigateToNext() async {
    if (selectedReasons.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please select at least one reason.")),
      );
      return;
    }

    setState(() => _isLoading = true); // ✅ Show loading state

    try {
      await _firestoreService.updateUserField(
          'goalReasons', selectedReasons); // ✅ Store reasons in Firestore

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FinalMessageScreen(
            userName: widget.userName, // ✅ Store name
            goal: widget.goal, // ✅ Store goal
          ),
        ),
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
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                "We all have different reasons to ${widget.goal.toLowerCase()}.",
                style: TextStyle(fontSize: 18),
              ),
              SizedBox(height: 10),
              Text(
                "What are yours? Select all that apply.",
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  itemCount: reasons.length,
                  itemBuilder: (context, index) {
                    final reason = reasons[index];
                    return CheckboxListTile(
                      title: Text(reason),
                      value: selectedReasons.contains(reason),
                      onChanged: (selectedReasons.contains("Other Reasons") &&
                              reason != "Other Reasons")
                          ? null
                          : (bool? value) {
                              _toggleSelection(reason);
                            },
                    );
                  },
                ),
              ),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: _isLoading ? null : _navigateToNext,
                child: _isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text("Next"),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                  backgroundColor: Colors.black,
                ),
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
