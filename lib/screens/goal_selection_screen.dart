import 'package:flutter/material.dart';
import 'package:savr/services/firestore_service.dart'; // ✅ Import FirestoreService
import 'reason_selection_screen.dart';

class GoalSelectionScreen extends StatefulWidget {
  final String userName;

  GoalSelectionScreen({required this.userName});

  @override
  _GoalSelectionScreenState createState() => _GoalSelectionScreenState();
}

class _GoalSelectionScreenState extends State<GoalSelectionScreen> {
  final FirestoreService _firestoreService =
      FirestoreService(); // ✅ Initialize Firestore Service
  bool _isLoading = false; // ✅ Loading state
  int? _selectedIndex;

  Future<void> _navigateToNext(
      BuildContext context, String selectedGoal) async {
    setState(() => _isLoading = true);
    try {
      await _firestoreService.updateUserField('goal', selectedGoal);

      // Optional delay to show selected option briefly
      await Future.delayed(Duration(milliseconds: 300));

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReasonSelectionScreen(
              userName: widget.userName, goal: selectedGoal),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    List<String> goals = [
      "Losing weight",
      "Gaining muscle and losing fat",
      "Gaining muscle, losing fat is secondary",
      "Eating healthier without losing weight"
    ];

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/sunflower.png', width: 200, height: 120),
                SizedBox(height: 20),
                Text(
                  "Hello ${widget.userName}!",
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 10),
                Text(
                  "So, what brings you here?",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 20),
                ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: goals.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: 5),
                      child: GestureDetector(
                        onTap: _isLoading
                            ? null
                            : () {
                                setState(() {
                                  _selectedIndex = index;
                                });
                                _navigateToNext(context, goals[index]);
                              },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              vertical: 15, horizontal: 20),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: _selectedIndex == index
                                ? Colors.black
                                : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            goals[index],
                            style: TextStyle(
                              fontSize: 16,
                              color: _selectedIndex == index
                                  ? Colors.white
                                  : Colors.black,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
