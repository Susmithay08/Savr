import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/home_screen.dart';
import '../kitchen/kitchen_screen.dart';
import 'dart:math';
import '../health/workout_screen.dart';
import '../health/fitness_challenges_screen.dart';
import 'package:intl/intl.dart';
import 'activity_calculator_screen.dart';
import 'package:savr/themes/colors.dart';

class HealthScreen extends StatefulWidget {
  const HealthScreen({Key? key}) : super(key: key);

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen>
    with WidgetsBindingObserver {
  int _selectedIndex = 3;
  List<DocumentSnapshot> _habits = [];
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  int _completedWorkouts = 0;
  double _averageSleepHours = 0.0;
  int _habitsCompleted = 0;

  bool showWellnessTips = false;
  final PageController _pageController = PageController();

  final List<String> wellnessTips = [
    'Take 3 deep breaths and reset.',
    'Drink a glass of water right now.',
    'Stretch your arms and shoulders.',
    'Write down one thing you’re grateful for.',
    'Avoid screens 30 minutes before sleep.',
    'Take a 5-minute mindful break.',
    'Eat one extra fruit today.',
    'Check in with a friend.',
    'Do 10 jumping jacks.',
    'Step outside and get fresh air.',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadHabits().then((habits) => _loadProgressOverview(habitDocs: habits));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // 👈 Add this
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadHabits().then((habits) => _loadProgressOverview(habitDocs: habits));
    }
  }

  Future<List<DocumentSnapshot>> _loadHabits() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return [];

    final snapshot = await _firestore
        .collection("users")
        .doc(userId)
        .collection("habits")
        .get();

    if (snapshot.docs.isEmpty) {
      final predefined = [
        "Walk 20 minutes",
        "Sleep before 11 PM",
        "Drink 8 glasses of water",
        "Avoid junk food",
        "Meditate for 5 minutes",
      ];
      for (final habit in predefined) {
        await _firestore
            .collection("users")
            .doc(userId)
            .collection("habits")
            .add({
          "title": habit,
          "isChecked": false,
          "createdAt": FieldValue.serverTimestamp(),
          "lastUpdated": FieldValue.serverTimestamp(),
        });
      }
      return _loadHabits(); // Re-call after creating
    }

    final now = DateTime.now();
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final lastUpdated = (data["lastUpdated"] as Timestamp).toDate();
      if (lastUpdated.day != now.day ||
          lastUpdated.month != now.month ||
          lastUpdated.year != now.year) {
        await doc.reference.update({
          "isChecked": false,
          "lastUpdated":
              Timestamp.fromDate(DateTime(now.year, now.month, now.day)),
        });
      }
    }

    final updated = await _firestore
        .collection("users")
        .doc(userId)
        .collection("habits")
        .get();

    setState(() {
      _habits = updated.docs;
    });

    return updated.docs; // 👈 Return loaded habits
  }

  Future<void> _loadProgressOverview(
      {List<DocumentSnapshot>? habitDocs}) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final now = DateTime.now();
    final todayKey =
        "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    // ✅ 1. Get today's workout
    int workoutCount = 0;
    final workoutDoc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('workout_logs')
        .doc(todayKey)
        .get();
    if (workoutDoc.exists && workoutDoc.data()?['completed'] == true) {
      workoutCount = 1;
    }

    // ✅ 2. Get today's sleep
    double sleepHours = 0;
    final sleepDoc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('sleep_logs')
        .doc(todayKey)
        .get();
    if (sleepDoc.exists && sleepDoc.data()?['sleepHours'] != null) {
      sleepHours = sleepDoc.data()!['sleepHours'].toDouble();
    }

    // ✅ 3. Habits checked
    final habitsToCheck = habitDocs ?? _habits;
    int checked = 0;
    for (final habit in habitsToCheck) {
      if (habit['isChecked'] == true) checked++;
    }

    // ✅ Update UI
    setState(() {
      _completedWorkouts = workoutCount;
      _averageSleepHours = sleepHours;
      _habitsCompleted = checked;
    });
  }

  Widget _buildProgressOverview() {
    return Card(
      color: NudePalette.softTaupe,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Daily Progress Overview',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: NudePalette.darkBrown,
                )),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(children: [
                  const Icon(Icons.bar_chart, size: 40),
                  const SizedBox(height: 4),
                  Text(
                    'Fitness Score ${calculateFitnessScore().toInt()}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  )
                ]),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Completed Workouts: $_completedWorkouts'),
                  Text(
                      'Average Sleep: ${_averageSleepHours.toStringAsFixed(1)} hr'),
                  Text('Habits Completed: $_habitsCompleted'),
                ]),
              ],
            )
          ],
        ),
      ),
    );
  }

  double calculateFitnessScore() {
    double score = 0;

    // You can fine-tune the weights
    score += (_completedWorkouts / 5) * 30; // up to 30 pts
    score += (_averageSleepHours / 8) * 30; // up to 30 pts
    score += (_habitsCompleted / 5) * 40; // up to 40 pts

    return score.clamp(0, 100); // Max score: 100
  }

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
        MaterialPageRoute(builder: (context) => KitchenScreen()),
      );
    } else if (index == 2) {
      Navigator.pushReplacementNamed(context, '/medicines');
    } else if (index == 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Feed is coming soon!")),
      );
    }
  }

  void _toggleHabit(DocumentSnapshot doc) async {
    final userId = _auth.currentUser?.uid;
    final current = doc["isChecked"];
    await _firestore
        .collection("users")
        .doc(userId)
        .collection("habits")
        .doc(doc.id)
        .update({
      "isChecked": !current,
      "lastUpdated": Timestamp.now(),
    });
    await _loadHabits()
        .then((habits) => _loadProgressOverview(habitDocs: habits));
    // ✅ refresh fitness score
  }

  void _addHabit() {
    showDialog(
      context: context,
      builder: (context) {
        String habitText = "";
        return AlertDialog(
          title: const Text("Add New Habit"),
          content: TextField(
            onChanged: (value) => habitText = value,
            decoration:
                const InputDecoration(hintText: "e.g. Run for 10 minutes"),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                if (habitText.trim().isNotEmpty) {
                  final userId = _auth.currentUser?.uid;
                  await _firestore
                      .collection("users")
                      .doc(userId)
                      .collection("habits")
                      .add({
                    "title": habitText.trim(),
                    "isChecked": false,
                    "createdAt": FieldValue.serverTimestamp(),
                    "lastUpdated": FieldValue.serverTimestamp(),
                  });
                  Navigator.pop(context);
                  _loadHabits();
                }
              },
              child: const Text("Add"),
            )
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomeScreen()),
        );
        return false;
      },
      child: Scaffold(
        backgroundColor: NudePalette.lightCream,
        appBar: AppBar(
          automaticallyImplyLeading: false, // ✅ hides back button
          backgroundColor: NudePalette.lightCream,
          iconTheme: IconThemeData(color: NudePalette.darkBrown),
          title: const Text(
            'Health',
            style: TextStyle(
              color:
                  NudePalette.darkBrown, // 👈 use this instead of Colors.black
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),

          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildTile(
              icon: Icons.calendar_today,
              title: 'Workout Planner',
              subtitle: 'Create your daily routine',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const WorkoutPlannerScreen()),
                );
              },
            ),
            _buildTile(
              icon: Icons.local_fire_department,
              title: 'Activity-Based Calorie Burn Calculator',
              subtitle: 'Estimate calories burned',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ActivityCalculatorScreen()),
                );
              },
            ),
            _buildTile(
              icon: Icons.emoji_events,
              title: 'Fitness Challenges',
              subtitle: 'Join challenge-based programs',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const FitnessChallengesScreen()),
                );
              },
            ),
            _buildProgressOverview(),
            _buildWellnessTipsCard(),
            _buildHabitBuilder(),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: NudePalette.darkBrown,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(color: Colors.black38, blurRadius: 10, spreadRadius: 2),
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
              //BottomNavigationBarItem(
              // icon: Icon(Icons.rss_feed), label: "Feed"),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      color: NudePalette.softTaupe,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color.fromARGB(255, 255, 255, 255),
          child: Icon(icon, color: Color(0xFF687E5E)),
        ),
        title: Text(title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: NudePalette.darkBrown,
            )),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  int currentTipIndex = 0;
  bool isFlipped = false;

  Widget _buildWellnessTipsCard() {
    return GestureDetector(
      onTap: () {
        setState(() {
          isFlipped = !isFlipped;
        });

        Future.delayed(const Duration(milliseconds: 250), () {
          setState(() {
            currentTipIndex = (currentTipIndex + 1) % wellnessTips.length;
          });
        });
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        transitionBuilder: (Widget child, Animation<double> animation) {
          final rotate = Tween(begin: pi, end: 0.0).animate(animation);
          return AnimatedBuilder(
            animation: rotate,
            child: child,
            builder: (context, child) {
              final isUnder = (ValueKey(isFlipped) != child?.key);
              final tilt = (isUnder ? min(rotate.value, pi / 2) : rotate.value);
              return Transform(
                transform: Matrix4.rotationY(tilt),
                alignment: Alignment.center,
                child: child,
              );
            },
          );
        },
        child: _buildTipCard(wellnessTips[currentTipIndex], isFlipped),
      ),
    );
  }

  Widget _buildTipCard(String tip, bool flipped) {
    return Card(
      key: ValueKey(flipped),
      color: NudePalette.softTaupe,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.psychology, color: NudePalette.darkBrown),
                SizedBox(width: 10),
                Text(
                  'Wellness Tips (Tap it)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: NudePalette.darkBrown,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              tip,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: NudePalette.darkBrown,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHabitBuilder() {
    return Card(
      color: NudePalette.softTaupe,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Habit Builder',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: NudePalette.darkBrown,
                    )),
                IconButton(
                  icon: const Icon(Icons.add, color: NudePalette.darkBrown),
                  onPressed: _addHabit,
                )
              ],
            ),
            const SizedBox(height: 12),
            for (final habit in _habits)
              CheckboxListTile(
                title: Text(habit['title']),
                value: habit['isChecked'],
                activeColor: NudePalette.mauveBrown,
                onChanged: (_) => _toggleHabit(habit),
              ),
          ],
        ),
      ),
    );
  }
}
