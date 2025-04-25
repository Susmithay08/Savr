import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:math';
import 'emergency_screen.dart';
import 'chat_screen.dart';
import 'package:savr/kitchen/kitchen_screen.dart';
import 'package:savr/screens/point_screen.dart';
import 'package:savr/health/workout_screen.dart';
import 'package:intl/intl.dart';
import 'package:savr/kitchen/mealplanner_screen.dart';
import 'package:savr/health/health_screen.dart'; // update the path as needed
import 'package:savr/medicine/medicines_screen.dart';
import 'package:savr/themes/colors.dart';

// Import the ProfileDrawer widget (make sure you have created this file)
import 'profile_drawer.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String userName = "User";
  double bmi = 0;
  String bmiStatus = "Unknown";

  // Trackers for the day
  double waterIntake = 0.0; // cups (0 to 8)
  double sleepHours = 0.0; // sleep hours (0 to 12)
  List<String> tasks = []; // list of tasks for today
  List<String> todayMeds = [];
  bool isCompleted(dynamic completed) {
    return completed == true ||
        completed == "true" ||
        completed == 1 ||
        completed.toString().toLowerCase() == "true";
  }

  List<String> healthTips = [
    "Drink 8 cups of water every day!",
    "Take deep breaths to reduce stress!",
    "Get at least 7 hours of sleep!",
    "Avoid processed sugar for heart health!",
    "Stretch every morning to improve flexibility!"
  ];
  String dailyHealthTip = "";
  int _selectedIndex = 0;
  Timer? _tipTimer;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _updateHealthTip();

    // Update health tip every 2 minutes.
    _tipTimer = Timer.periodic(Duration(minutes: 2), (timer) {
      _updateHealthTip();
    });
  }

  @override
  void dispose() {
    _tipTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        setState(() {
          userName = userDoc['displayName'] ?? "User";
          double height = (userDoc['height'] ?? 0).toDouble() / 100;
          double weight = (userDoc['weight'] ?? 0).toDouble();
          bmi = (height > 0) ? weight / (height * height) : 0.0;
          bmiStatus = _getBMIStatus(bmi);
        });
        await _fetchTodayWaterIntake();
        await _fetchTodaySleep();
        await _fetchTodayTasks();

        // Add this line:
        todayMeds = await _fetchTodayMeds();
        setState(() {});
      }
    }
  }

  Future<List<String>> _fetchTodayMeds() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final now = DateTime.now();
    final todayWeekday = DateFormat('EEEE').format(now); // e.g., "Monday"
    final todayDay = now.day; // Day of month (e.g., 7)

    List<String> todayMeds = [];
    final firestore = FirebaseFirestore.instance;

    // Fetch Daily Medications
    final dailySnapshot = await firestore
        .collection('users')
        .doc(user.uid)
        .collection('medications')
        .doc('daily')
        .collection('items')
        .get();

    for (var doc in dailySnapshot.docs) {
      final data = doc.data();
      if (data.containsKey('name')) {
        todayMeds.add(data['name'].toString().trim());
      }
    }

    // Fetch Weekday-Specific Medications
    final weekdaySnapshot = await firestore
        .collection('users')
        .doc(user.uid)
        .collection('medications')
        .doc(todayWeekday)
        .collection('items')
        .get();

    for (var doc in weekdaySnapshot.docs) {
      final data = doc.data();
      if (data.containsKey('name')) {
        todayMeds.add(data['name'].toString().trim());
      }
    }

    // Fetch Monthly Once Medications
    final monthlySnapshot = await firestore
        .collection('users')
        .doc(user.uid)
        .collection('medications')
        .doc('monthly once')
        .collection('items')
        .where('monthlyDay', isEqualTo: todayDay)
        .get();

    for (var doc in monthlySnapshot.docs) {
      final data = doc.data();
      if (data.containsKey('name')) {
        todayMeds.add(data['name'].toString().trim());
      }
    }

    print('✅ Total meds today (${todayMeds.length}): $todayMeds');

    return todayMeds;
  }

  Future<Map<String, double>> _fetchWeeklySleepLogs() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return {};

    Map<String, double> weeklySleep = {};
    DateTime today = DateTime.now();

    for (int i = 0; i < 7; i++) {
      DateTime date = today.subtract(Duration(days: i));
      String dateString = date.toIso8601String().substring(0, 10);

      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('sleep_logs')
          .doc(dateString)
          .get();

      double hours = doc.exists ? (doc['sleepHours'] ?? 0).toDouble() : 0;
      weeklySleep[dateString] = hours;
    }

    return weeklySleep;
  }

  void _showSleepHistoryDialog() async {
    Map<String, double> weeklySleep = await _fetchWeeklySleepLogs();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Weekly Sleep Hours"),
          content: Container(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: weeklySleep.length,
                    itemBuilder: (context, index) {
                      String date = weeklySleep.keys.elementAt(index);
                      double hours = weeklySleep[date]!;
                      return ListTile(
                        leading: Icon(Icons.bedtime),
                        title: Text(date),
                        trailing: Text("$hours hours"),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              child: Text("Close"),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        );
      },
    );
  }

  Future<Map<String, double>> _fetchWeeklyWaterIntake() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return {};

    Map<String, double> weeklyIntake = {};
    DateTime today = DateTime.now();

    for (int i = 0; i < 7; i++) {
      DateTime date = today.subtract(Duration(days: i));
      String dateString = date.toIso8601String().substring(0, 10);

      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('water_logs')
          .doc(dateString)
          .get();

      double intake = doc.exists ? (doc['waterIntake'] ?? 0).toDouble() : 0;
      weeklyIntake[dateString] = intake;
    }

    return weeklyIntake;
  }

  void _showWaterHistoryDialog() async {
    Map<String, double> weeklyIntake = await _fetchWeeklyWaterIntake();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Weekly Water Intake"),
          content: Container(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: weeklyIntake.length,
                    itemBuilder: (context, index) {
                      String date = weeklyIntake.keys.elementAt(index);
                      double cups = weeklyIntake[date]!;
                      return ListTile(
                        leading: Icon(Icons.water_drop),
                        title: Text(date),
                        trailing: Text("$cups cups"),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              child: Text("Close"),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        );
      },
    );
  }

  // --- Water Tracker Functions ---
  Future<void> _fetchTodayWaterIntake() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    String today = DateTime.now().toIso8601String().substring(0, 10);
    DocumentSnapshot waterDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('water_logs')
        .doc(today)
        .get();
    if (waterDoc.exists) {
      setState(() {
        waterIntake = (waterDoc['waterIntake'] ?? 0).toDouble();
      });
    } else {
      setState(() {
        waterIntake = 0;
      });
    }
  }

  Future<void> _updateWaterLogInFirestore(int cups) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    String today = DateTime.now().toIso8601String().substring(0, 10);
    DocumentReference waterLogRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('water_logs')
        .doc(today);
    await waterLogRef.set({'waterIntake': cups}, SetOptions(merge: true));
  }

  // --- Sleep Tracker Functions ---
  Future<void> _fetchTodaySleep() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    String today = DateTime.now().toIso8601String().substring(0, 10);
    DocumentSnapshot sleepDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('sleep_logs')
        .doc(today)
        .get();
    if (sleepDoc.exists) {
      setState(() {
        sleepHours = (sleepDoc['sleepHours'] ?? 0).toDouble();
      });
    } else {
      setState(() {
        sleepHours = 0;
      });
    }
  }

  Future<void> _updateSleepLogInFirestore(int hours) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    String today = DateTime.now().toIso8601String().substring(0, 10);
    DocumentReference sleepLogRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('sleep_logs')
        .doc(today);
    await sleepLogRef.set({'sleepHours': hours}, SetOptions(merge: true));
  }

  // --- Tasks Tracker Functions ---
  Future<void> _fetchTodayTasks() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    String today = DateTime.now().toIso8601String().substring(0, 10);
    String yesterday = DateTime.now()
        .subtract(Duration(days: 1))
        .toIso8601String()
        .substring(0, 10);

    List<String> tempTasks = [];

    Future<void> loadTasksFromDate(String dateKey) async {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('tasks_logs')
          .doc(dateKey)
          .get();

      if (doc.exists && doc['tasks'] != null) {
        List<dynamic> tasksList = doc['tasks'];
        for (var task in tasksList) {
          if (task is Map && !isCompleted(task['completed'])) {
            tempTasks.add(task['title'] ?? '');
          }
        }
      }
    }

    await loadTasksFromDate(yesterday); // carry forward uncompleted
    await loadTasksFromDate(today); // today’s uncompleted

    setState(() {
      tasks = tempTasks.toSet().toList(); // Remove duplicates
    });
  }

  Future<void> _updateTasksLogInFirestore(List<String> tasksList,
      [List<String>? completedList]) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String today = DateTime.now().toIso8601String().substring(0, 10);

    List<Map<String, dynamic>> taskMap = tasksList.map((task) {
      return {
        "title": task,
        "completed": completedList?.contains(task) == true,
      };
    }).toList();

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('tasks_logs')
        .doc(today)
        .set({'tasks': taskMap}, SetOptions(merge: true));
  }

  String _getBMIStatus(double bmi) {
    if (bmi < 18.5) return "Underweight";
    if (bmi >= 18.5 && bmi < 25) return "Normal";
    if (bmi >= 25 && bmi < 30) return "Overweight";
    return "Obese";
  }

  void _updateHealthTip() {
    final random = Random();
    setState(() {
      dailyHealthTip = healthTips[random.nextInt(healthTips.length)];
    });
  }

  // --- Dialogs ---
  // Water Tracker Dialog
  void _showWaterDialog() {
    int cups = waterIntake.toInt();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          String funnyMessage;
          if (cups == 0) {
            funnyMessage = "Time to drink some water!";
          } else if (cups < 4) {
            funnyMessage = "Keep sipping!";
          } else if (cups < 8) {
            funnyMessage = "Almost there, stay hydrated!";
          } else {
            funnyMessage = "You're a hydration hero!";
          }
          return AlertDialog(
            title: Text("Log Your Water Intake"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("$cups / 8 cups", style: TextStyle(fontSize: 18)),
                TextButton(
                  onPressed: _showWaterHistoryDialog,
                  child: Text("View History",
                      style: TextStyle(color: NudePalette.mauveBrown)),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(Icons.remove),
                      onPressed: () {
                        if (cups > 0) {
                          setStateDialog(() {
                            cups--;
                          });
                        }
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.add),
                      onPressed: () {
                        if (cups < 8) {
                          setStateDialog(() {
                            cups++;
                          });
                        }
                      },
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Text(funnyMessage),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () async {
                  await _updateWaterLogInFirestore(cups);
                  setState(() {
                    waterIntake = cups.toDouble();
                  });
                  Navigator.of(context).pop();
                },
                child: Text("Log"),
              ),
            ],
          );
        });
      },
    );
  }

  // Sleep Tracker Dialog
  void _showSleepDialog() {
    int hours = sleepHours.toInt();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          String message;
          if (hours == 0) {
            message = "You haven't slept yet today!";
          } else if (hours < 4) {
            message = "You need more sleep!";
          } else if (hours < 8) {
            message = "Keep going, try to hit 8 hours!";
          } else {
            message = "Great, you're well-rested!";
          }
          return AlertDialog(
            title: Text("Log Your Sleep Hours"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("$hours hours", style: TextStyle(fontSize: 18)),
                TextButton(
                  onPressed: _showSleepHistoryDialog,
                  child: Text("View History",
                      style: TextStyle(color: NudePalette.mauveBrown)),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(Icons.remove),
                      onPressed: () {
                        if (hours > 0) {
                          setStateDialog(() {
                            hours--;
                          });
                        }
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.add),
                      onPressed: () {
                        if (hours < 12) {
                          setStateDialog(() {
                            hours++;
                          });
                        }
                      },
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Text(message),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () async {
                  await _updateSleepLogInFirestore(hours);
                  setState(() {
                    sleepHours = hours.toDouble();
                  });
                  Navigator.of(context).pop();
                },
                child: Text("Log"),
              ),
            ],
          );
        });
      },
    );
  }

  // Tasks Tracker Dialog with checkbox removal functionality
  void _showTasksDialog() {
    List<String> tempTasks = List.from(tasks);
    List<String> completedTasks = [];
    TextEditingController taskController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Today's Tasks"),
                TextButton(
                  onPressed: _showTaskHistoryDialog,
                  child: Text("View History",
                      style: TextStyle(color: NudePalette.mauveBrown)),
                ),
              ],
            ),
            content: Container(
              height: 300,
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: taskController,
                          decoration: InputDecoration(hintText: "Enter task"),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.add),
                        onPressed: () {
                          if (taskController.text.trim().isNotEmpty) {
                            setStateDialog(() {
                              tempTasks.add(taskController.text.trim());
                              taskController.clear();
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  Expanded(
                    child: tempTasks.isEmpty
                        ? Center(child: Text("No tasks added"))
                        : ListView.builder(
                            itemCount: tempTasks.length,
                            itemBuilder: (context, index) {
                              return ListTile(
                                leading: Checkbox(
                                  value:
                                      completedTasks.contains(tempTasks[index]),
                                  onChanged: (val) {
                                    setStateDialog(() {
                                      if (val == true) {
                                        completedTasks.add(tempTasks[index]);
                                      } else {
                                        completedTasks.remove(tempTasks[index]);
                                      }
                                    });
                                  },
                                ),
                                title: Text(tempTasks[index]),
                                trailing: IconButton(
                                  icon: Icon(Icons.delete_outline),
                                  onPressed: () {
                                    setStateDialog(() {
                                      completedTasks.remove(tempTasks[index]);
                                      tempTasks.removeAt(index);
                                    });
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () async {
                  await _updateTasksLogInFirestore(tempTasks, completedTasks);
                  setState(() {
                    tasks = tempTasks
                        .where((t) => !completedTasks.contains(t))
                        .toList(); // carry over uncompleted only
                  });
                  Navigator.of(context).pop();
                },
                child: Text("Save"),
              ),
            ],
          );
        });
      },
    );
  }

  void _showTaskHistoryDialog() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final taskLogs = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('tasks_logs')
          // .orderBy(FieldPath.documentId, descending: true) // temporarily remove this
          .get();

      final docs = taskLogs.docs;

      if (docs.isEmpty) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text("Task History"),
            content: Text("No history found."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Close"),
              ),
            ],
          ),
        );
        return;
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("Task History"),
          content: Container(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final date = doc.id;
                return ListTile(
                  leading: Icon(Icons.calendar_today),
                  title: Text(date),
                  onTap: () {
                    Navigator.of(context).pop();
                    _showTasksForDate(date);
                  },
                );
              },
            ),
          ),
        ),
      );
    } catch (e) {
      print("🔥 Failed to fetch task history: $e");
    }
  }

  void _showTasksForDate(String date) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('tasks_logs')
        .doc(date)
        .get();

    List<dynamic> tasksList = doc.data()?['tasks'] ?? [];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Completed Tasks on $date"),
        content: Container(
          width: double.maxFinite,
          child: tasksList.isEmpty
              ? Text("No tasks found.")
              : ListView(
                  shrinkWrap: true,
                  children: tasksList.map<Widget>((task) {
                    if (task is String) {
                      return ListTile(
                        leading: Icon(Icons.task),
                        title: Text(task),
                      );
                    } else if (task is Map<String, dynamic> &&
                        isCompleted(task['completed'])) {
                      return ListTile(
                        leading: Icon(Icons.check_circle_outline),
                        title: Text(task['title'] ?? ''),
                      );
                    } else {
                      return SizedBox.shrink(); // not shown
                    }
                  }).toList(),
                ),
        ),
        actions: [
          TextButton(
            child: Text("Close"),
            onPressed: () => Navigator.of(context).pop(),
          )
        ],
      ),
    );
  }

  // Pills Dialog – simple placeholder
  void _showPillsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Today's Pills"),
          content: Container(
            width: double.maxFinite,
            child: todayMeds.isEmpty
                ? Text("You don't have any medications today.")
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: todayMeds.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        leading: Icon(Icons.medication),
                        title: Text(todayMeds[index]),
                      );
                    },
                  ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text("Close"),
            ),
          ],
        );
      },
    );
  }

  // --- UI Helper: Health Card Widget ---
  Widget _buildHealthCard(String title, String subtitle, Color color) {
    return Container(
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(15)),
      padding: EdgeInsets.all(15),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: NudePalette.darkBrown,
            ),
          ),
          SizedBox(height: 10),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  // Option buttons (Plan a Meal, Plan a Workout)
  Widget _buildOptionButton(String text) {
    return ElevatedButton(
      onPressed: () {
        if (text == "Plan a Meal") {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => MealPlannerScreen()),
          );
        } else if (text == "Plan a Workout") {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => WorkoutPlannerScreen()),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Coming soon!")),
          );
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: NudePalette.mauveBrown,
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      ),
      child: Text(text, style: TextStyle(color: Colors.white)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Integrate the ProfileDrawer as the drawer.
      drawer: ProfileDrawer(),
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(50),
        child: AppBar(
          backgroundColor: NudePalette.lightCream,
          elevation: 0,
          // Use a Builder to obtain the proper context for opening the drawer.
          leading: Builder(
            builder: (context) => IconButton(
              icon: Icon(Icons.account_circle,
                  color: NudePalette.darkBrown, size: 28),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            ),
          ),

          actions: [
            IconButton(
              icon: Icon(Icons.call, color: Colors.black, size: 28),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const EmergencyScreen()),
                );
              },
            ),
            IconButton(
              icon: Icon(Icons.chat, color: Colors.black, size: 28),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ChatScreen()),
                );
              },
            ),
          ],
        ),
      ),
      backgroundColor: NudePalette.lightCream,

      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Greeting
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Hey $userName, how’s it going?",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(height: 30),
            // BMI and Status
            Center(
              child: Column(
                children: [
                  Text(
                    bmi.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "BMI Status: $bmiStatus",
                    style: TextStyle(
                      fontSize: 16,
                      color: NudePalette.darkBrown.withOpacity(0.54),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            // Plan Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildOptionButton("Plan a Meal"),
                SizedBox(width: 15),
                _buildOptionButton("Plan a Workout"),
              ],
            ),
            SizedBox(height: 15),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, "/points");
              },
              icon: Icon(Icons.stars),
              label: Text("View Weekly Points"),
              style: ElevatedButton.styleFrom(
                backgroundColor: NudePalette.sandBeige,
                foregroundColor: NudePalette.darkBrown,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                elevation: 0,
              ),
            ),

            SizedBox(height: 30),
            // Daily Health Tip
            Text(
              "Daily Health Tip",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 5),
            Text(
              dailyHealthTip,
              style: TextStyle(
                fontSize: 16,
                color: NudePalette.darkBrown.withOpacity(0.54),
              ),
            ),
            SizedBox(height: 20),
            // Grid with Health Cards
            GridView.count(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              children: [
// Water
                InkWell(
                  onTap: _showWaterDialog,
                  child: _buildHealthCard(
                    "Water",
                    "${waterIntake.toInt()} / 8 cups",
                    NudePalette.paleBlush,
                  ),
                ),

// Pills
                InkWell(
                  onTap: _showPillsDialog,
                  child: _buildHealthCard(
                    "Pills",
                    todayMeds.isEmpty
                        ? "No meds today"
                        : "You have ${todayMeds.length} pills today",
                    NudePalette.sandBeige,
                  ),
                ),

// Tasks
                InkWell(
                  onTap: _showTasksDialog,
                  child: _buildHealthCard(
                    "Tasks",
                    tasks.isEmpty
                        ? "No tasks for today"
                        : "You have ${tasks.length} tasks",
                    NudePalette.softTaupe,
                  ),
                ),

// Sleep
                InkWell(
                  onTap: _showSleepDialog,
                  child: _buildHealthCard(
                    "Sleep",
                    sleepHours == 0
                        ? "No sleep logged"
                        : "$sleepHours / 8 hours",
                    NudePalette.mauveBrown,
                  ),
                ),
              ],
            ),
            SizedBox(height: 50),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: NudePalette.darkBrown, // Background behind nav bar
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: NudePalette.darkBrown.withOpacity(0.4),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        margin: EdgeInsets.all(15),
        padding: EdgeInsets.symmetric(vertical: 10),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          selectedItemColor: NudePalette.lightCream, // Active icon color
          unselectedItemColor:
              NudePalette.lightCream.withOpacity(0.6), // Inactive icon color
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() => _selectedIndex = index);
            if (index == 0) {
              // Home
            } else if (index == 1) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => KitchenScreen()),
              );
            } else if (index == 2) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (context) => const MedicinesScreen()),
              );
            } else if (index == 3) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const HealthScreen()),
              );
            } else if (index == 4) {
              // TODO: Navigate to Feed screen.
            }
          },
          items: [
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
