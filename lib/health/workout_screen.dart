import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:savr/screens/home_screen.dart';
import 'package:savr/kitchen/kitchen_screen.dart';
import 'dart:math';
import 'package:intl/intl.dart';
import 'workout_popup.dart';
import 'generate_workout_planner.dart';
import 'saved_workouts_screen.dart';
import 'package:savr/themes/colors.dart';

class WorkoutPlannerScreen extends StatefulWidget {
  const WorkoutPlannerScreen({super.key});

  @override
  State<WorkoutPlannerScreen> createState() => _WorkoutPlannerScreenState();
}

class _WorkoutPlannerScreenState extends State<WorkoutPlannerScreen> {
  int _selectedIndex = 3;
  String selectedGender = 'female';
  int weeklyGoal = 3;
  List<String> completedDays = [];
  Map<String, String> plannedWorkouts = {};
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  final now = DateTime.now();
  final List<DateTime> weekDates = List.generate(7, (index) {
    final today = DateTime.now();
    return today.subtract(Duration(days: today.weekday - 1 - index));
  });

  void _onBottomNavTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen()),
      );
    } else if (index == 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const KitchenScreen()),
      );
    } else if (index == 2) {
      // TODO: Replace with actual MedicinesScreen
      Navigator.pushReplacementNamed(context, '/medicines');
    } else if (index == 3) {
      // Do nothing, you're already in Health section (Workout is under Health)
    } else if (index == 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Feed screen is coming soon!")),
      );
    }
  }

  Future<void> _loadPlannedWorkouts() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('plannedWorkouts')
        .get();

    final Map<String, String> plans = {};
    for (var doc in snapshot.docs) {
      plans[doc.id] = doc['title'] ?? '';
    }

    setState(() {
      plannedWorkouts = plans;
    });
  }

  Future<void> _loadCompletedDays() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1)); // Monday
    final weekEnd = weekStart.add(const Duration(days: 6)); // Sunday

    try {
      final snapshot = await _firestore
          .collection("users")
          .doc(userId)
          .collection("completedWorkouts")
          .get();

      final List<String> currentWeekCompleted = [];

      for (final doc in snapshot.docs) {
        final date = DateTime.tryParse(doc.id);
        if (date == null) continue;

        if (!date.isBefore(weekStart) && !date.isAfter(weekEnd)) {
          currentWeekCompleted.add(doc.id); // yyyy-MM-dd
        }
      }

      setState(() {
        completedDays = currentWeekCompleted;
      });

      print("✅ Completed workout days this week: $completedDays");
    } catch (e) {
      print("❌ Error loading completed days: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    _loadWeeklyGoal();
    _loadCompletedDays(); // ✅ add this
    _loadPlannedWorkouts();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCompletedDays();
    });
  }

  Future<void> _loadWeeklyGoal() async {
    final userId = _auth.currentUser?.uid;
    final doc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('settings')
        .doc('weekly_goal')
        .get();
    if (doc.exists) {
      setState(() {
        weeklyGoal = doc['goal'] ?? 3;
      });
    }
  }

  void _editWeeklyGoal() {
    int tempGoal = weeklyGoal;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: NudePalette.paleBlush,
          title: const Text("Set Weekly Goal"),
          content: DropdownButton<int>(
            value: tempGoal,
            items: List.generate(7, (index) => index + 1)
                .map((val) =>
                    DropdownMenuItem(value: val, child: Text("$val days")))
                .toList(),
            onChanged: (value) => setState(() => tempGoal = value!),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                setState(() => weeklyGoal = tempGoal);
                final userId = _auth.currentUser?.uid;
                await _firestore
                    .collection('users')
                    .doc(userId)
                    .collection('settings')
                    .doc('weekly_goal')
                    .set({'goal': weeklyGoal});

                Navigator.pop(context);
              },
              child: const Text("Save"),
            )
          ],
        );
      },
    );
  }

  void _openWeekPlannerDialog() {
    final TextEditingController _controller = TextEditingController();
    final Map<String, String> tempPlan = {};

    showDialog(
      context: context,
      builder: (context) {
        return Scaffold(
          backgroundColor: NudePalette.lightCream,
          appBar: AppBar(
            title: const Text(
              "Plan Your Week",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: NudePalette.darkBrown,
              ),
            ),
            backgroundColor: NudePalette.lightCream,
            elevation: 0,
            foregroundColor: NudePalette.darkBrown,
            actions: [
              TextButton(
                onPressed: () async {
                  final userId = _auth.currentUser?.uid;
                  if (userId != null) {
                    for (var entry in tempPlan.entries) {
                      await _firestore
                          .collection('users')
                          .doc(userId)
                          .collection('plannedWorkouts')
                          .doc(entry.key)
                          .set({'title': entry.value});
                    }
                  }
                  Navigator.pop(context);
                },
                child: const Text("Save"),
              )
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: weekDates.map((date) {
              final dateStr = DateFormat('yyyy-MM-dd').format(date);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(DateFormat('EEEE, MMM d').format(date),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  TextField(
                    decoration: InputDecoration(
                      hintText: "Enter workout (e.g., Chest Day, Rest)",
                      filled: true,
                      fillColor: NudePalette.paleBlush,
                      hintStyle: TextStyle(
                          color: NudePalette.darkBrown.withOpacity(0.6)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                    style: const TextStyle(color: NudePalette.darkBrown),
                    onChanged: (val) => tempPlan[dateStr] = val,
                  ),
                  const SizedBox(height: 16),
                ],
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildWeeklyGoal() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('WEEK GOAL',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Row(
              children: [
                Text('${completedDays.length}/$weeklyGoal'),
                TextButton(
                  onPressed: _openWeekPlannerDialog,
                  child: const Text('Plan'),
                ),
              ],
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: weekDates.map((date) {
            final label = DateFormat('E\nd').format(date);
            final isCompleted =
                completedDays.contains(DateFormat('yyyy-MM-dd').format(date));
            final dateKey = DateFormat('yyyy-MM-dd').format(date);
            final planned = plannedWorkouts[dateKey] ?? '';
            return Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? NudePalette.mauveBrown.withOpacity(0.1)
                        : Colors.transparent,
                    border: Border.all(color: NudePalette.mauveBrown, width: 1),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.check,
                      size: 18,
                      color: isCompleted
                          ? NudePalette.mauveBrown
                          : Colors.transparent,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(label, style: const TextStyle(fontSize: 12)),
                if (planned.isNotEmpty)
                  Text(
                    planned,
                    style: const TextStyle(fontSize: 10, color: Colors.black54),
                    textAlign: TextAlign.center,
                  ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildGenderToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () => setState(() => selectedGender = 'female'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: selectedGender == 'female'
                  ? NudePalette.paleBlush
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: NudePalette.mauveBrown),
            ),
            child: const Text('Women',
                style: TextStyle(color: NudePalette.mauveBrown)),
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: () => setState(() => selectedGender = 'male'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: selectedGender == 'male'
                  ? NudePalette.paleBlush
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: NudePalette.mauveBrown),
            ),
            child: const Text('Men',
                style: TextStyle(color: NudePalette.mauveBrown)),
          ),
        ),
      ],
    );
  }

  Widget _buildWorkoutCard(
    String title,
    String subtitle, {
    bool isNew = false,
    required String category,
    required String level,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WorkoutPopup(
              category: category,
              level: level,
              gender: selectedGender, // ✅ Make sure this line exists
            ),
          ),
        ).then((result) {
          if (result == true) {
            _loadCompletedDays().then((_) {
              setState(() {});
            });
          }
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        width: 160,
        decoration: BoxDecoration(
          color: NudePalette.paleBlush,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isNew)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.pinkAccent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'NEW',
                        style: TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: NudePalette.darkBrown,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPredefinedSection(
    String category,
    List<Map<String, String>> workouts,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(category.toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: workouts
                .map(
                  (workout) => _buildWorkoutCard(
                    workout['title']!,
                    workout['subtitle']!,
                    category:
                        category.toLowerCase().split(" ")[0], // e.g., "abs"
                    level: workout['title']!.toLowerCase(), // e.g., "beginner"
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final femaleWorkouts = [
      {
        'category': 'Abs Workout',
        'workouts': [
          {'title': 'Beginner', 'subtitle': '12 minutes'},
          {'title': 'Intermediate', 'subtitle': '17 minutes'},
          {'title': 'Advanced', 'subtitle': '20 minutes'},
        ]
      },
      {
        'category': 'Thighs Workout',
        'workouts': [
          {'title': 'Beginner', 'subtitle': '10 minutes'},
          {'title': 'Intermediate', 'subtitle': '15 minutes'},
          {'title': 'Advanced', 'subtitle': '18 minutes'},
        ]
      },
      {
        'category': 'Glutes Workout',
        'workouts': [
          {'title': 'Beginner', 'subtitle': '11 minutes'},
          {'title': 'Intermediate', 'subtitle': '14 minutes'},
          {'title': 'Advanced', 'subtitle': '19 minutes'},
        ]
      },
      {
        'category': 'Arms Workout',
        'workouts': [
          {'title': 'Beginner', 'subtitle': '13 minutes'},
        ]
      },
      {
        'category': 'Chest Workout',
        'workouts': [
          {'title': 'Beginner', 'subtitle': '3 minutes'},
          {'title': 'Intermediate', 'subtitle': '9 minutes'},
          {'title': 'Advanced', 'subtitle': '7 minutes'},
        ]
      },
      {
        'category': 'Face Workout',
        'workouts': [
          {'title': 'Chin', 'subtitle': '5 minutes'},
          {'title': 'Jawline', 'subtitle': '7 minutes'},
        ]
      },
    ];

    final maleWorkouts = [
      {
        'category': 'Abs Workout',
        'workouts': [
          {'title': 'Beginner', 'subtitle': '10 minutes'},
          {'title': 'Intermediate', 'subtitle': '15 minutes'},
          {'title': 'Advanced', 'subtitle': '20 minutes'},
        ]
      },
      {
        'category': 'Arms Workout',
        'workouts': [
          {'title': 'Beginner', 'subtitle': '9 minutes'},
          {'title': 'Intermediate', 'subtitle': '14 minutes'},
          {'title': 'Advanced', 'subtitle': '19 minutes'},
        ]
      },
      {
        'category': 'Chest Workout',
        'workouts': [
          {'title': 'Beginner', 'subtitle': '9 minutes'},
          {'title': 'Intermediate', 'subtitle': '14 minutes'},
          {'title': 'Advanced', 'subtitle': '19 minutes'},
        ]
      },
      {
        'category': 'Leg Workout',
        'workouts': [
          {'title': 'Beginner', 'subtitle': '10 minutes'},
          {'title': 'Intermediate', 'subtitle': '15 minutes'},
          {'title': 'Advanced', 'subtitle': '20 minutes'},
        ]
      },
      {
        'category': 'Shoulder Workout',
        'workouts': [
          {'title': 'Beginner', 'subtitle': '10 minutes'},
          {'title': 'Intermediate', 'subtitle': '15 minutes'},
          {'title': 'Advanced', 'subtitle': '20 minutes'},
        ]
      },
      {
        'category': 'Face Workout',
        'workouts': [
          {'title': 'Chin', 'subtitle': '5 minutes'},
          {'title': 'Jawline', 'subtitle': '7 minutes'},
        ]
      },
    ];

    return Scaffold(
      backgroundColor: NudePalette.lightCream,
      appBar: AppBar(
        title: const Text('Workout Planner',
            style: TextStyle(
              color: NudePalette.darkBrown,
              fontWeight: FontWeight.bold,
            )),
        foregroundColor: NudePalette.darkBrown,
        backgroundColor: NudePalette.lightCream,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWeeklyGoal(),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: NudePalette.mauveBrown,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GenerateWorkoutPopup(
                        onResult: (plan) {
                          showDialog(
                              context: context,
                              builder: (_) => Scaffold(
                                    backgroundColor: const Color(0xFFFCF9F4),
                                    appBar: AppBar(
                                      backgroundColor: const Color(0xFFFCF9F4),
                                      title: const Text("Your AI Workout Plan"),
                                      leading: IconButton(
                                        icon: const Icon(Icons.arrow_back,
                                            color: Colors.black),
                                        onPressed: () => Navigator.pop(context),
                                      ),
                                      elevation: 0,
                                    ),
                                    body: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: SingleChildScrollView(
                                        child: Text(
                                          plan,
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                      ),
                                    ),
                                  ));
                        },
                      ),
                    ),
                  );
                },
                child: const Text(
                  'Generate My Workout Plan',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SavedWorkoutsScreen(),
                    ),
                  );
                },
                child: const Text(
                  "View Saved Workouts",
                  style: TextStyle(
                    color: NudePalette.mauveBrown,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            _buildGenderToggle(),
            const SizedBox(height: 20),
            ...(selectedGender == 'female' ? femaleWorkouts : maleWorkouts)
                .map((section) => _buildPredefinedSection(
                      section['category'] as String,
                      (section['workouts'] as List).cast<Map<String, String>>(),
                    )),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: NudePalette.darkBrown,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(color: Colors.black38, blurRadius: 10, spreadRadius: 2)
          ],
        ),
        margin: const EdgeInsets.all(15),
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          selectedItemColor: NudePalette.lightCream,
          unselectedItemColor: NudePalette.lightCream.withOpacity(0.6),
          currentIndex: _selectedIndex,
          onTap: _onBottomNavTapped,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
            BottomNavigationBarItem(
                icon: Icon(Icons.kitchen), label: "Kitchen"),
            BottomNavigationBarItem(
                icon: Icon(Icons.medical_services), label: "Medicines"),
            BottomNavigationBarItem(
                icon: Icon(Icons.favorite), label: "Health"),
            //BottomNavigationBarItem(icon: Icon(Icons.rss_feed), label: "Feed"),
          ],
        ),
      ),
    );
  }
}
