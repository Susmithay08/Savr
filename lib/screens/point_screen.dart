import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:savr/screens/home_screen.dart';
import 'package:savr/kitchen/kitchen_screen.dart';
import 'package:savr/medicine/medicines_screen.dart';
import 'package:savr/health/health_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:savr/utils/points_calculator.dart';
import 'package:savr/kitchen/mealplanner_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:savr/themes/colors.dart';

class PointScreen extends StatefulWidget {
  @override
  _PointScreenState createState() => _PointScreenState();
}

class _PointScreenState extends State<PointScreen> {
  int _selectedIndex = 0;
  late Future<WeeklyPoints> _weeklyPoints;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _weeklyPoints =
          PointsCalculator.calculatePoints(user.uid).then((points) async {
        final startOfWeek =
            DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
        final weekId = DateFormat('yyyy-MM-dd').format(startOfWeek);

        await FirebaseFirestore.instance
            .collection("users")
            .doc(user.uid)
            .collection("points")
            .doc(weekId)
            .set({"total": points.total}, SetOptions(merge: true));

        return points;
      });
    }
  }

  Future<void> _savePointsToFirestore(
      String userId, WeeklyPoints points) async {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekId = DateFormat('yyyy-MM-dd').format(weekStart);

    await FirebaseFirestore.instance
        .collection("users")
        .doc(userId)
        .collection("points")
        .doc(weekId)
        .set({
      "total": points.total,
      "meals": points.meals,
      "meds": points.meds,
      "water": points.water,
      "sleep": points.sleep,
      "workout": points.workout,
      "tasks": points.tasks,
      "updatedAt": Timestamp.now(),
    });

    print("✅ Weekly points saved for $weekId: ${points.total}");
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
    } else if (index == 3) {
      Navigator.pushReplacementNamed(context, '/health');
    } else if (index == 4) {
      // You can update this when the Feed screen is added
      // Navigator.pushReplacementNamed(context, '/feed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Weekly Health Points",
          style: TextStyle(color: NudePalette.darkBrown),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: NudePalette.lightCream,
        iconTheme: IconThemeData(color: NudePalette.darkBrown),
      ),
      backgroundColor: NudePalette.lightCream,
      body: FutureBuilder<WeeklyPoints>(
        future: _weeklyPoints,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Calculating how awesome you’ve been this week… please stand by!",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: NudePalette.darkBrown.withOpacity(0.8),
                    ),
                  ),
                  SizedBox(height: 20),
                  SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: NudePalette.mauveBrown,
                    ),
                  ),
                ],
              ),
            );
          } else if (snapshot.hasError || !snapshot.hasData) {
            return Center(child: Text("Error loading data"));
          }

          final points = snapshot.data!;
          double progress = points.total / 42;

          return SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      Text("Your Score",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600)),
                      SizedBox(height: 10),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 140,
                            height: 140,
                            child: CircularProgressIndicator(
                              value: progress,
                              backgroundColor: Colors.grey[300],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  NudePalette.mauveBrown),
                              strokeWidth: 12,
                            ),
                          ),
                          Text("${points.total} / 42",
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      SizedBox(height: 10),
                      Text(
                        points.total >= 21
                            ? "🎉 Cheat Meal Unlocked!"
                            : "🔒 Earn 21 points to unlock Cheat Meal",
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: points.total >= 21 ? Colors.green : Colors.red,
                        ),
                      ),
                      if (points.total >= 21) ...[
                        SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MealPlannerScreen(
                                  showCheatMeal: true,
                                ),
                              ),
                            );
                          },
                          icon: Icon(Icons.fastfood),
                          label: Text("Plan Your Cheat Meal"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: NudePalette.mauveBrown,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: 30),
                Text("Breakdown",
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 10),
                _buildProgressItem("Meals", points.meals, 7),
                _buildProgressItem("Meds", points.meds, 7),
                _buildProgressItem("Water", points.water, 7),
                _buildProgressItem("Sleep", points.sleep, 7),
                _buildProgressItem("Workout", points.workout, 7),
                _buildProgressItem("Tasks", points.tasks, 7),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: NudePalette.darkBrown,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: NudePalette.darkBrown.withOpacity(0.4),
              blurRadius: 10,
              spreadRadius: 2,
            ),
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

  Widget _buildProgressItem(String label, int earned, int max) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 16)),
            Text("$earned / $max",
                style: TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
        SizedBox(height: 4),
        LinearProgressIndicator(
          value: earned / max,
          minHeight: 8,
          backgroundColor: Colors.grey[200],
          color: NudePalette.mauveBrown,
        ),
        SizedBox(height: 8),
      ],
    );
  }
}
