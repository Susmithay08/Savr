import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'workout_timer_page.dart';
import 'package:savr/themes/colors.dart';

class ChallengeProgressPopup extends StatefulWidget {
  final String challengeId;
  final List<Map<String, dynamic>> workouts;

  const ChallengeProgressPopup({
    super.key,
    required this.challengeId,
    required this.workouts,
  });

  @override
  State<ChallengeProgressPopup> createState() => _ChallengeProgressPopupState();
}

class _ChallengeProgressPopupState extends State<ChallengeProgressPopup> {
  int currentDay = 1;
  List<int> completedDays = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _restartChallenge() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    await FirebaseFirestore.instance
        .collection("users")
        .doc(userId)
        .collection("fitness_challenges")
        .doc(widget.challengeId)
        .set({
      'currentDay': 1,
      'completedDays': [],
      'lastUpdated': FieldValue.serverTimestamp(),
    });

    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final doc = await FirebaseFirestore.instance
        .collection("users")
        .doc(userId)
        .collection("fitness_challenges")
        .doc(widget.challengeId)
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        currentDay = (data['currentDay'] ?? 1);
        completedDays = List<int>.from(data['completedDays'] ?? []);
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
    }
  }

  Future<void> _markDayComplete(int day) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    await FirebaseFirestore.instance
        .collection("users")
        .doc(userId)
        .collection("fitness_challenges")
        .doc(widget.challengeId)
        .set({
      'currentDay': day + 1,
      'completedDays': [...completedDays, day],
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: NudePalette.lightCream,
      appBar: AppBar(
        title: const Text("Challenge Progress",
            style: TextStyle(color: NudePalette.darkBrown)),
        backgroundColor: NudePalette.lightCream,
        elevation: 0,
        foregroundColor: NudePalette.darkBrown,
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: "Restart Challenge",
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  backgroundColor: NudePalette.paleBlush,
                  title: const Text("Restart Challenge",
                      style: TextStyle(color: NudePalette.darkBrown)),
                  content: const Text(
                    "This will reset your progress to Day 1. Are you sure?",
                    style: TextStyle(color: NudePalette.darkBrown),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancel",
                          style: TextStyle(color: NudePalette.mauveBrown)),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _restartChallenge();
                      },
                      child: const Text("Restart",
                          style: TextStyle(color: NudePalette.mauveBrown)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 30,
        itemBuilder: (context, index) {
          final day = index + 1;
          final isCompleted = completedDays.contains(day);
          final isCurrent = day == currentDay;

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: isCompleted
                  ? Colors.green
                  : isCurrent
                      ? NudePalette.mauveBrown
                      : Colors.grey.shade300,
              child: Text("$day", style: const TextStyle(color: Colors.white)),
            ),
            title: Text("Day $day Workout",
                style: const TextStyle(color: NudePalette.darkBrown)),
            subtitle: isCompleted
                ? const Text("Completed",
                    style: TextStyle(color: NudePalette.darkBrown))
                : isCurrent
                    ? const Text("Ready to start",
                        style: TextStyle(color: NudePalette.darkBrown))
                    : const Text("Locked",
                        style: TextStyle(color: Colors.grey)),
            trailing: isCurrent
                ? ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: NudePalette.mauveBrown,
                    ),
                    onPressed: () async {
                      final todayWorkouts = widget.workouts
                          .where((w) => w['day'] == day)
                          .toList();
                      if (todayWorkouts.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text("No workouts for today")),
                        );
                        return;
                      }

                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              WorkoutTimerPage(exercises: todayWorkouts),
                        ),
                      );

                      if (result == true) {
                        await _markDayComplete(day);
                        _loadProgress();
                      }
                    },
                    child: const Text("Start",
                        style: TextStyle(color: Colors.white)),
                  )
                : null,
          );
        },
      ),
    );
  }
}
