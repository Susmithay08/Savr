import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:savr/utils/ai_workout_estimator.dart';
import 'package:savr/themes/colors.dart';

class ActivityCalculatorScreen extends StatefulWidget {
  const ActivityCalculatorScreen({Key? key}) : super(key: key);

  @override
  State<ActivityCalculatorScreen> createState() =>
      _ActivityCalculatorScreenState();
}

class _ActivityCalculatorScreenState extends State<ActivityCalculatorScreen> {
  final List<Map<String, dynamic>> _activityLog = [];
  final _auth = FirebaseAuth.instance;

  String _selectedActivity = 'Walking';
  String _duration = '';
  double _caloriesBurned = 0.0;
  double _weeklyGoal = 1500.0;
  double _weeklyTotal = 0.0;
  String? _aiResponse;
  double userWeight = 70;

  final Map<String, double> _activityMET = {
    'Walking': 3.8,
    'Running': 7.5,
    'Cycling': 6.8,
    'Swimming': 5.8,
    'Dancing': 4.5,
    'Yoga': 3.0,
    'Jump Rope': 8.0,
    'Workout': 6.0,
  };

  @override
  void initState() {
    super.initState();
    _loadWeeklyCalories();
    _loadTodayActivities();
  }

  Future<double> _calculateCalories(String activity, String durationMin) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return 0.0;

    final doc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    final data = doc.data();
    final weight = (data != null ? data['weight'] ?? 60 : 60).toDouble();
    final met = _activityMET[activity] ?? 3.0;
    final durationHours = (double.tryParse(durationMin) ?? 0) / 60.0;
    return met * weight * durationHours;
  }

  Future<void> _loadTodayActivities() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final now = DateTime.now();
    final startOfDay =
        Timestamp.fromDate(DateTime(now.year, now.month, now.day));
    final endOfDay =
        Timestamp.fromDate(DateTime(now.year, now.month, now.day, 23, 59, 59));

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('activity_logs')
        .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
        .where('timestamp', isLessThanOrEqualTo: endOfDay)
        .get();

    double totalCalories = 0;
    List<Map<String, dynamic>> loadedActivities = [];

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final cal = (data['caloriesBurned'] ?? 0).toDouble();
      final activity = data['activity'] ?? "Unknown";
      final duration = data['duration'] ?? 0;

      totalCalories += cal;

      loadedActivities.add({
        'activity': activity,
        'duration': duration,
        'calories': cal,
      });
    }

    setState(() {
      _weeklyTotal = totalCalories;
      _caloriesBurned = totalCalories;
      _activityLog.clear();
      _activityLog.addAll(loadedActivities);
    });
  }

  void _addActivity() async {
    final duration = int.tryParse(_duration);
    if (duration == null || _selectedActivity.isEmpty) return;

    final calculatedCalories =
        await _calculateCalories(_selectedActivity, _duration);

    setState(() {
      _weeklyTotal += calculatedCalories;
      _caloriesBurned += calculatedCalories;
      _activityLog.add({
        'activity': _selectedActivity,
        'duration': duration,
        'calories': calculatedCalories,
      });
    });

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .collection('activity_logs')
          .add({
        'activity': _selectedActivity,
        'duration': duration,
        'caloriesBurned': calculatedCalories,
        'timestamp': Timestamp.now(),
      });
    } catch (e) {
      print("Error saving activity log to Firestore: $e");
    }

    setState(() {
      _duration = '';
    });
  }

  Future<void> _loadWeeklyCalories() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('activity_logs')
        .where('timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeek))
        .get();

    double total = 0.0;
    for (var doc in snapshot.docs) {
      total += (doc.data()['calories'] ?? 0).toDouble();
    }

    setState(() {
      _weeklyTotal = total;
    });
  }

  void _removeActivity(int index) {
    setState(() {
      _caloriesBurned -= _activityLog[index]['calories'];
      _weeklyTotal -= _activityLog[index]['calories'];
      _activityLog.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NudePalette.lightCream,
      appBar: AppBar(
        title: const Text(
          'Activity Calorie Calculator',
          style: TextStyle(color: NudePalette.darkBrown),
        ),
        backgroundColor: NudePalette.lightCream,
        iconTheme: const IconThemeData(color: NudePalette.darkBrown),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButton<String>(
              value: _selectedActivity,
              isExpanded: true,
              items: _activityMET.keys
                  .map((activity) => DropdownMenuItem(
                        value: activity,
                        child: Text(activity),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => _selectedActivity = value!),
            ),
            const SizedBox(height: 10),
            TextField(
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Duration (minutes)',
                filled: true,
                fillColor: NudePalette.paleBlush,
                labelStyle: const TextStyle(color: NudePalette.darkBrown),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: NudePalette.mauveBrown, width: 2),
                ),
              ),
              style: const TextStyle(color: NudePalette.darkBrown),
              onChanged: (val) => setState(() => _duration = val),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _addActivity,
              style: ElevatedButton.styleFrom(
                backgroundColor: NudePalette.mauveBrown,
              ),
              child: const Text('Add Activity',
                  style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await estimateCaloriesFromLogsAndSendToAI(
                  userId: FirebaseAuth.instance.currentUser!.uid,
                  gender: "women",
                  date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
                  userWeight: 70,
                  onAIResponse: (response) async {
                    setState(() {
                      _aiResponse = response;
                    });

                    final calories = double.tryParse(response);
                    if (calories != null) {
                      _weeklyTotal += calories;

                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(FirebaseAuth.instance.currentUser!.uid)
                          .collection('activity_logs')
                          .add({
                        'activity': 'AI Workout',
                        'caloriesBurned': calories,
                        'timestamp': Timestamp.now(),
                      });
                    }
                  },
                );
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: NudePalette.mauveBrown),
              child: const Text("Estimate from Completed Workout",
                  style: TextStyle(color: Colors.white)),
            ),
            if (_aiResponse != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  "AI-estimated calories: $_aiResponse kcal",
                  style: const TextStyle(
                      fontSize: 16, color: NudePalette.darkBrown),
                ),
              ),
            const SizedBox(height: 30),
            LinearProgressIndicator(
              value: (_weeklyTotal / _weeklyGoal).clamp(0.0, 1.0),
              backgroundColor: Colors.grey.shade300,
              color: NudePalette.mauveBrown,
            ),
            const SizedBox(height: 6),
            Text(
              'Weekly Burn Goal: ${_weeklyTotal.toStringAsFixed(1)} / $_weeklyGoal kcal',
              style: const TextStyle(color: NudePalette.darkBrown),
            ),
            const SizedBox(height: 20),
            const Text("Today's Activities:",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: NudePalette.darkBrown)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _activityLog.length,
                itemBuilder: (context, index) {
                  final item = _activityLog[index];
                  return Card(
                    color: NudePalette.paleBlush,
                    child: ListTile(
                      title: Text(
                          '${item['activity']} - ${item['duration']} min',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: NudePalette.darkBrown)),
                      subtitle: Text(
                          '${item['calories'].toStringAsFixed(1)} kcal',
                          style: const TextStyle(color: NudePalette.darkBrown)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _removeActivity(index),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Total Calories Burned Today: ${_caloriesBurned.toStringAsFixed(1)} kcal',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: NudePalette.darkBrown),
            ),
          ],
        ),
      ),
    );
  }
}
