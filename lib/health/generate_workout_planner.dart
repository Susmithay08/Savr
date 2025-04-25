import 'package:flutter/material.dart';
import 'workout_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:savr/themes/colors.dart';

class GenerateWorkoutPopup extends StatefulWidget {
  final Function(String aiResponse) onResult;
  const GenerateWorkoutPopup({super.key, required this.onResult});

  @override
  State<GenerateWorkoutPopup> createState() => _GenerateWorkoutPopupState();
}

class _GenerateWorkoutPopupState extends State<GenerateWorkoutPopup> {
  String goal = '';
  String type = '';
  String duration = '';
  bool isLoading = false;

  Future<void> _generatePlan() async {
    setState(() => isLoading = true);

    final prompt = """
Create a personalized workout plan for the following preferences:
Goal: $goal
Workout Type: $type
Duration per day: $duration
Make it easy to follow and include rest days if needed.
""";

    final url =
        "https://generativelanguage.googleapis.com/v1/models/gemini-1.5-pro:generateContent?key=AIzaSyC8RV1M4_yLHiOnBudsYehJrBXJs09jysg";

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: '''
      {
        "contents": [{
          "parts": [{
            "text": "$prompt"
          }]
        }]
      }
      ''',
    );

    final responseBody = json.decode(response.body);
    final text =
        responseBody["candidates"]?[0]?["content"]?["parts"]?[0]?["text"];

    if (text == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Gemini did not return a plan.")),
      );
      setState(() => isLoading = false);
      return;
    }

    setState(() => isLoading = false);

    final cleanText =
        text.replaceAll("**", "").replaceAll("#", "").replaceAll("*", "");

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutPlanDisplayScreen(
          plan: cleanText,
          fitnessName: goal,
          workoutType: type,
          duration: duration,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NudePalette.lightCream,
      appBar: AppBar(
        title: const Text(
          "Your Preferences",
          style: TextStyle(color: NudePalette.darkBrown),
        ),
        backgroundColor: NudePalette.lightCream,
        elevation: 0,
        foregroundColor: NudePalette.darkBrown,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: NudePalette.mauveBrown),
                    SizedBox(height: 20),
                    Text(
                      "⏳ Wait up… Best plan for you is generating…",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: NudePalette.darkBrown,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      labelText: "Your Fitness Goal",
                      filled: true,
                      fillColor: NudePalette.paleBlush,
                      labelStyle: const TextStyle(color: NudePalette.darkBrown),
                      border: OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(
                            color: NudePalette.mauveBrown, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    style: const TextStyle(color: NudePalette.darkBrown),
                    onChanged: (val) => goal = val,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    decoration: InputDecoration(
                      labelText: "Workout Type (e.g., HIIT, strength)",
                      filled: true,
                      fillColor: NudePalette.paleBlush,
                      labelStyle: const TextStyle(color: NudePalette.darkBrown),
                      border: OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(
                            color: NudePalette.mauveBrown, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    style: const TextStyle(color: NudePalette.darkBrown),
                    onChanged: (val) => type = val,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    decoration: InputDecoration(
                      labelText: "Duration (e.g., 30 min)",
                      filled: true,
                      fillColor: NudePalette.paleBlush,
                      labelStyle: const TextStyle(color: NudePalette.darkBrown),
                      border: OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(
                            color: NudePalette.mauveBrown, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    style: const TextStyle(color: NudePalette.darkBrown),
                    onChanged: (val) => duration = val,
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _generatePlan,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: NudePalette.mauveBrown,
                      minimumSize: const Size.fromHeight(50),
                    ),
                    child: const Text("Generate Workout Plan",
                        style: TextStyle(color: Colors.white)),
                  )
                ],
              ),
      ),
    );
  }
}

String formatPlan(String plan) {
  final lines = plan.split('\n');
  return lines.map((line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return "";
    if (trimmed.startsWith("•") || RegExp(r"^\d+\.\s").hasMatch(trimmed)) {
      return trimmed;
    }
    return "• $trimmed";
  }).join("\n");
}

class WorkoutPlanDisplayScreen extends StatelessWidget {
  final String plan;
  final String fitnessName;
  final String workoutType;
  final String duration;

  const WorkoutPlanDisplayScreen({
    Key? key,
    required this.plan,
    required this.fitnessName,
    required this.workoutType,
    required this.duration,
  }) : super(key: key);

  Future<void> _savePlan(BuildContext context) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('saved_workouts')
        .add({
      'plan': plan,
      'fitnessName': fitnessName,
      'workoutType': workoutType,
      'duration': duration,
      'timestamp': FieldValue.serverTimestamp(),
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Workout plan saved successfully")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NudePalette.lightCream,
      appBar: AppBar(
        title: Text(
          fitnessName,
          style: const TextStyle(
            color: NudePalette.darkBrown,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: NudePalette.lightCream,
        iconTheme: const IconThemeData(color: NudePalette.darkBrown),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Text(
            formatPlan(plan),
            style: const TextStyle(
              fontSize: 16,
              color: NudePalette.darkBrown,
            ),
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(
              onPressed: () => _savePlan(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: NudePalette.mauveBrown,
                minimumSize: const Size(150, 50),
              ),
              child: const Text("Save", style: TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: NudePalette.mauveBrown,
                minimumSize: const Size(150, 50),
              ),
              child: const Text("Close", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
