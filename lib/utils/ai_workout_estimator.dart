import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

final String apiKey = "AIzaSyDXUcPiGbY1d9yDLO2Ps_Qxd2yzxkk7HYo";

Future<void> estimateCaloriesFromLogsAndSendToAI({
  required String userId,
  required String gender,
  required String date, // format: yyyy-MM-dd
  required double userWeight, // in kg
  required Function(String) onAIResponse, // callback to display result
}) async {
  final firestore = FirebaseFirestore.instance;

  // 1. Fetch workout log
  final logSnapshot = await firestore
      .collection('users')
      .doc(userId)
      .collection('workout_logs')
      .doc(date)
      .get();

  if (!logSnapshot.exists || logSnapshot.data()?['workoutDone'] == null) {
    onAIResponse("No workout found for $date.");
    return;
  }

  final workoutKey = logSnapshot.data()!['workoutDone']; // e.g. abs:beginner
  final parts = workoutKey.split(":");
  if (parts.length != 2) {
    onAIResponse("Invalid workout format.");
    return;
  }

  final category = parts[0];
  final level = parts[1];
  final lookupKey = "${category}_${level}".toLowerCase();

  // 2. Load predefined_workouts.json
  final jsonString =
      await rootBundle.loadString('assets/predefined_workouts.json');
  final jsonData = json.decode(jsonString);
  final workoutData = jsonData[gender.toLowerCase()]?[lookupKey];

  if (workoutData == null) {
    onAIResponse("Workout data not found for: $workoutKey");
    return;
  }

  // 3. Format prompt for Gemini AI
  final workoutList = (workoutData['workouts'] as List)
      .map((w) => "- ${w['name']} – ${w['reps']}")
      .join("\n");

  final prompt = """
A person weighing $userWeight kg performed this workout:

Workout: ${workoutData['title']}
Duration: ${workoutData['duration']}
Exercises:
$workoutList

Please respond with only the total estimated calories burned as a **number only**. Do not include any text, explanation, or formatting. Just return a number like: 123.4
""";

  // 4. Call Gemini AI API
  final url = Uri.parse(
    "https://generativelanguage.googleapis.com/v1/models/gemini-1.5-pro:generateContent?key=$apiKey",
  );

  final headers = {
    "Content-Type": "application/json",
  };

  final body = json.encode({
    "contents": [
      {
        "parts": [
          {"text": prompt}
        ]
      }
    ]
  });

  try {
    final response = await http.post(url, headers: headers, body: body);
    final data = json.decode(response.body);

    final aiText = data['candidates']?[0]?['content']?['parts']?[0]?['text'];

    if (aiText != null) {
      onAIResponse(aiText);
    } else {
      onAIResponse("AI did not return a valid response.");
    }
  } catch (e) {
    onAIResponse("AI error: $e");
  }
}
