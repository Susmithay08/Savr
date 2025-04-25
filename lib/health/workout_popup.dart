import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'workout_timer_page.dart';
import 'package:savr/themes/colors.dart';

class WorkoutPopup extends StatefulWidget {
  final String category;
  final String level;
  final String gender;

  const WorkoutPopup({
    super.key,
    required this.category,
    required this.level,
    required this.gender,
  });

  @override
  State<WorkoutPopup> createState() => _WorkoutPopupState();
}

class _WorkoutPopupState extends State<WorkoutPopup>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? workoutData;
  List<Map<String, String>> customExercises = [];

  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _loadWorkoutData();
    _loadCustomExercises();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadWorkoutData() async {
    final isMale = widget.gender.toLowerCase() == 'male';
    final filePath = isMale
        ? 'assets/male_workouts.json'
        : 'assets/predefined_workouts.json';

    final String response = await rootBundle.loadString(filePath);
    final data = json.decode(response);

    final categoryKey = "${widget.category}_${widget.level}".toLowerCase();
    final lookup = isMale ? data : data['women'];
    final selected = lookup[categoryKey];

    if (selected == null) {
      debugPrint("❌ Workout not found: $categoryKey in $filePath");
      return;
    }

    setState(() {
      workoutData = selected;
    });
  }

  Future<void> _loadCustomExercises() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('custom_workouts')
        .get();

    setState(() {
      customExercises = snapshot.docs
          .map((doc) => {
                "name": doc['name'].toString(),
                "reps": doc['reps'].toString(),
              })
          .toList();
    });
  }

  void _addCustomExerciseDialog() {
    String name = '';
    String reps = '';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: NudePalette.paleBlush,
          title: const Text("Add Custom Exercise",
              style: TextStyle(color: NudePalette.darkBrown)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(
                  hintText: "Exercise Name",
                  filled: true,
                  fillColor: Colors.white,
                ),
                onChanged: (value) => name = value,
              ),
              const SizedBox(height: 10),
              TextField(
                decoration: const InputDecoration(
                  hintText: "Reps (e.g. 30 sec or 12 times)",
                  filled: true,
                  fillColor: Colors.white,
                ),
                onChanged: (value) => reps = value,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                if (name.trim().isEmpty || reps.trim().isEmpty) return;

                final userId = FirebaseAuth.instance.currentUser?.uid;
                if (userId == null) return;

                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .collection('custom_workouts')
                    .add({'name': name.trim(), 'reps': reps.trim()});

                setState(() {
                  customExercises.add({
                    "name": name.trim(),
                    "reps": reps.trim(),
                  });
                });

                Navigator.pop(context);
              },
              child: const Text("Add",
                  style: TextStyle(color: NudePalette.mauveBrown)),
            )
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (workoutData == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final combinedWorkouts = [
      ...(workoutData!["workouts"] as List).cast<Map<String, dynamic>>().map(
          (e) => {"name": e["name"].toString(), "reps": e["reps"].toString()}),
      ...customExercises,
    ];

    return Scaffold(
      backgroundColor: NudePalette.lightCream,
      body: SlideTransition(
        position: _slideAnimation,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.only(top: 60, left: 16, right: 16),
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                color: NudePalette.paleBlush,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back,
                            color: NudePalette.darkBrown),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                      Hero(
                        tag: widget.category,
                        child: const CircleAvatar(
                          backgroundColor: NudePalette.mauveBrown,
                          child:
                              Icon(Icons.fitness_center, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.level.toUpperCase(),
                    style: const TextStyle(
                        fontSize: 16,
                        color: Colors.pink,
                        fontWeight: FontWeight.bold),
                  ),
                  Text(
                    widget.category.toUpperCase(),
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: NudePalette.darkBrown),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 16),
                      const SizedBox(width: 4),
                      Text(workoutData!["duration"]),
                      const SizedBox(width: 10),
                      const Icon(Icons.local_fire_department, size: 16),
                      const SizedBox(width: 4),
                      Text("${combinedWorkouts.length} Workouts"),
                      const Spacer(),
                      IconButton(
                        onPressed: _addCustomExerciseDialog,
                        icon: const Icon(Icons.add_circle_outline),
                        color: NudePalette.mauveBrown,
                        iconSize: 28,
                        tooltip: "Add Exercise",
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text("Workout list",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: NudePalette.darkBrown,
                        fontSize: 16)),
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: combinedWorkouts.length,
                separatorBuilder: (_, __) => const Divider(
                  indent: 72,
                  endIndent: 16,
                  color: Colors.black12,
                ),
                itemBuilder: (context, index) {
                  final item = combinedWorkouts[index];
                  return ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: NudePalette.mauveBrown,
                      child: Icon(Icons.fitness_center, color: Colors.white),
                    ),
                    title: Text(item["name"]!.toUpperCase(),
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: NudePalette.darkBrown)),
                    subtitle: Text(item["reps"]!,
                        style: const TextStyle(color: NudePalette.darkBrown)),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => WorkoutTimerPage(
                              exercises: combinedWorkouts
                                  .map((e) => {
                                        "name": e["name"]!,
                                        "reps": e["reps"]!,
                                      })
                                  .toList(),
                              workoutTag: "${widget.category}:${widget.level}"
                                  .toLowerCase(),
                            )),
                  );

                  if (result == true) {
                    Navigator.pop(context, true);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: NudePalette.mauveBrown,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  minimumSize: const Size.fromHeight(50),
                ),
                child: const Text(
                  "START",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
