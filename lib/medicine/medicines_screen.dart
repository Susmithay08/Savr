import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:savr/screens/home_screen.dart';
import 'package:savr/kitchen/kitchen_screen.dart';
import 'package:savr/medicine/medicines_screen.dart';
import 'package:savr/medicine/add_medicine_screen.dart';
import 'package:savr/medicine/take_your_meds_screen.dart';
import 'package:savr/health/health_screen.dart';
import 'package:savr/themes/colors.dart'; // ✅ NudePalette colors

class MedicinesScreen extends StatefulWidget {
  const MedicinesScreen({Key? key}) : super(key: key);

  @override
  _MedicinesScreenState createState() => _MedicinesScreenState();
}

class _MedicinesScreenState extends State<MedicinesScreen>
    with WidgetsBindingObserver {
  int _selectedIndex = 2; // Medicines is at index 2 in the bottom nav
  int expiredCount = 0;
  int expiringSoonCount = 0;
  int freshCount = 0;
  bool isLoading = true;
  List<DateTime> _weekDates = [];
  Map<String, String> _weeklyLogStatus = {}; // e.g., {"2025-03-24": "taken"}
  bool _hasLoadedLogs = false; // 🆕 Ensure logs are loaded only once

  @override
  void initState() {
    super.initState();
    _fetchMedicineExpiryData();
    _generateWeekDates(); // 🆕 Add this
    _fetchWeeklyLogs();
    WidgetsBinding.instance.addObserver(this);
    // 🆕 Add this after you implement Step 2
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_hasLoadedLogs) {
      _generateWeekDates();
      _fetchWeeklyLogs();
      _hasLoadedLogs = true;
    }

    // 🧠 When you navigate back, check if the screen is resumed
    ModalRoute.of(context)?.addScopedWillPopCallback(() async {
      _generateWeekDates(); // regenerate week
      await _fetchWeeklyLogs(); // refetch logs
      setState(() {}); // update chart
      return true;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _generateWeekDates(); // 🧠 Refresh week
      _fetchWeeklyLogs(); // 🔄 Refresh data
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Fetch medicine items and categorize them
  Future<void> _fetchMedicineExpiryData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("No user logged in");
      setState(() {
        isLoading = false;
      });
      return;
    }

    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .collection("medicines")
          .get();

      print("Total medicines fetched: ${snapshot.docs.length}");

      int expired = 0, expiringSoon = 0, fresh = 0;
      DateTime now = DateTime.now();

      for (var doc in snapshot.docs) {
        DateTime expiryDate = (doc['expiryDate'] as Timestamp).toDate();
        if (expiryDate.isBefore(now)) {
          expired++;
        } else if (expiryDate.isBefore(now.add(const Duration(days: 3)))) {
          expiringSoon++;
        } else {
          fresh++;
        }
      }

      setState(() {
        expiredCount = expired;
        expiringSoonCount = expiringSoon;
        freshCount = fresh;
        isLoading = false; // ✅ Stop loading after fetching data
      });
    } catch (e) {
      print("Error fetching medicine expiry data: $e");
      setState(() {
        isLoading = false; // 🔴 Ensure loading stops even on error
      });
    }
  }

  void _generateWeekDates() {
    DateTime today = DateTime.now();

    // 🔧 Force today to midnight (00:00:00), then go back to Monday
    DateTime monday = DateTime(today.year, today.month, today.day)
        .subtract(Duration(days: today.weekday - 1));

    // 🗓 Generate the 7 days of the week, each set to midnight
    _weekDates = List.generate(7, (index) {
      final day = monday.add(Duration(days: index));
      return DateTime(day.year, day.month, day.day); // Force each to 00:00
    });
  }

  Future<void> _fetchWeeklyLogs() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      DateTime start = _weekDates.first;
      DateTime end = _weekDates.last.add(const Duration(days: 1)); // inclusive

      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .collection("medication_logs")
          .where("timestamp", isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where("timestamp", isLessThan: Timestamp.fromDate(end))
          .get();

      Map<String, List<String>> statusLists = {};

      for (var doc in snapshot.docs) {
        Timestamp ts = doc['timestamp'];
        String dayKey = _formatDateKey(ts.toDate());
        print("📅 Log date: ${ts.toDate()} → Key: $dayKey");

        String status = doc['status'];

        statusLists.putIfAbsent(dayKey, () => []).add(status);
      }

      Map<String, String> finalStatusMap = {};

      statusLists.forEach((day, statuses) {
        if (statuses.every((s) => s == "taken")) {
          finalStatusMap[day] = "taken";
        } else if (statuses.every((s) => s == "skipped")) {
          finalStatusMap[day] = "skipped";
        } else {
          finalStatusMap[day] = "partial";
        }
      });

      setState(() {
        _weeklyLogStatus = finalStatusMap;
      });
    } catch (e) {
      print("Error fetching weekly logs: $e");
    }
  }

  String _formatDateKey(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  double _calculateParticipationProgress() {
    int loggedDays = 0;

    for (DateTime day in _weekDates) {
      String key = _formatDateKey(day);
      if (_weeklyLogStatus.containsKey(key)) {
        loggedDays++;
      }
    }

    return loggedDays / 7;
  }

  double _calculateWeeklyAdherence() {
    int takenDays = 0;

    for (DateTime day in _weekDates) {
      String key = _formatDateKey(day); // "yyyy-MM-dd"
      String? status = _weeklyLogStatus[key];

      if (status == "taken") {
        takenDays++;
      }
    }

    return takenDays / 7;
  }

  void _showLogsForDay(DateTime date) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String dateLabel = "${date.day}-${date.month}-${date.year}";

    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .collection("medication_logs")
          .where("timestamp",
              isGreaterThanOrEqualTo:
                  Timestamp.fromDate(DateTime(date.year, date.month, date.day)))
          .where("timestamp",
              isLessThan: Timestamp.fromDate(
                  DateTime(date.year, date.month, date.day + 1)))
          .get();

      if (snapshot.docs.isEmpty) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text("No Logs"),
            content: Text("No medication logs found for $dateLabel."),
          ),
        );
        return;
      }

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text("Logs for $dateLabel"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: snapshot.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return ListTile(
                title: Text(data['name'] ?? "Unknown"),
                subtitle: Text("Status: ${data['status']}"),
                leading: Icon(
                  data['status'] == "taken" ? Icons.check_circle : Icons.cancel,
                  color:
                      data['status'] == "taken" ? Colors.green : Colors.orange,
                ),
              );
            }).toList(),
          ),
        ),
      );
    } catch (e) {
      print("Error fetching logs for $date: $e");
    }
  }

  /// Builds a visual alert based on medicine expiry data.
  /// Builds a visual alert based on medicine expiry data.
  Widget _buildMedicineAlert() {
    if (isLoading) {
      return const Center(
        child: Text(
          "Loading medicine data...",
          style: TextStyle(fontSize: 16, color: Colors.black54),
        ),
      );
    }

    // ✅ Show message when no medicines are tracked
    if (expiredCount == 0 && expiringSoonCount == 0 && freshCount == 0) {
      return const Center(
        child: Text(
          "No medicines tracked.",
          style: TextStyle(fontSize: 16, color: Colors.black54),
        ),
      );
    }

    return Column(
      children: [
        if (expiredCount > 0)
          _buildAlertRow("Expired: $expiredCount medicines", Colors.red),
        if (expiringSoonCount > 0)
          _buildAlertRow(
              "Expiring Soon: $expiringSoonCount medicines", Colors.orange),
        if (freshCount > 0)
          _buildAlertRow("Fresh: $freshCount medicines", Colors.green),
      ],
    );
  }

  Widget buildWeeklyAdherenceChart() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      margin: EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: NudePalette.paleBlush, // Updated from mint to theme beige
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Weekly Adherence",
            style: TextStyle(
              color: NudePalette.darkBrown,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 10),
          Text(
            _weeklyLogStatus.isEmpty
                ? "0%"
                : "${(_calculateWeeklyAdherence() * 100).round()}%",
            style: TextStyle(
              fontSize: 48,
              color: NudePalette.darkBrown,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              List<String> days = [
                "Mon",
                "Tue",
                "Wed",
                "Thu",
                "Fri",
                "Sat",
                "Sun"
              ];
              DateTime day = _weekDates[index];
              String dayKey = _formatDateKey(day);
              String status = (_weeklyLogStatus[dayKey] ?? "").toLowerCase();

              IconData icon;
              Color iconColor;

              if (status == "taken") {
                icon = Icons.check_circle;
                iconColor = Colors.green;
              } else if (status == "skipped") {
                icon = Icons.cancel;
                iconColor = Colors.red;
              } else if (status == "partial") {
                icon = Icons.change_circle;
                iconColor = Colors.orange;
              } else {
                icon = Icons.radio_button_unchecked;
                iconColor = Colors.grey;
              }

              return Column(
                children: [
                  Text(
                    days[index],
                    style: TextStyle(color: NudePalette.darkBrown),
                  ),
                  SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => _showLogsForDay(day),
                    child: Icon(
                      icon,
                      color: iconColor,
                      size: 22,
                    ),
                  ),
                ],
              );
            }),
          ),
          SizedBox(height: 10),
          LinearProgressIndicator(
            value: _calculateParticipationProgress(),
            backgroundColor: NudePalette.paleBlush,
            valueColor: AlwaysStoppedAnimation<Color>(NudePalette.mauveBrown),
            minHeight: 8,
          )
        ],
      ),
    );
  }

  /// Builds an alert row for expired, expiring soon, and fresh medicines.
  Widget _buildAlertRow(String text, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.warning, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ],
      ),
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
        // Subtle background color
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Header Text
                  const Text(
                    "Manage Your Medicines",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: NudePalette.darkBrown,
                    ),
                  ),
                  Text(
                    "Track medicine expiry, dosage schedules, and reminders.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 16,
                        color: NudePalette.darkBrown.withOpacity(0.6)),
                  ),

                  const SizedBox(height: 20),

                  // Medicine Expiry Alerts
                  _buildMedicineAlert(),

                  const SizedBox(height: 20),

                  // Weekly Adherence Chart
                  buildWeeklyAdherenceChart(),

                  const SizedBox(height: 20),

                  // Grid Options
                  GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    children: [
                      _buildOption(
                        imagePath: 'assets/Meds.png',
                        title: "Add Medicine",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => AddMedicineScreen()),
                          );
                        },
                      ),
                      _buildOption(
                        imagePath: 'assets/Dose.png',
                        title: "Take your Meds",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => TakeYourMedsScreen()),
                          ).then((_) async {
                            // ✅ Add a short delay to ensure Firestore logs are synced
                            await Future.delayed(Duration(milliseconds: 300));

                            _generateWeekDates(); // ✅ Rebuild the week
                            await _fetchWeeklyLogs(); // ✅ Refetch logs including Monday
                            setState(() {}); // ✅ Refresh the UI
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // Bottom Navigation stays the same
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: NudePalette.darkBrown,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black38, blurRadius: 10, spreadRadius: 2),
            ],
          ),
          margin: EdgeInsets.all(15),
          padding: EdgeInsets.symmetric(vertical: 10),
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.transparent,
            selectedItemColor: NudePalette.lightCream,
            unselectedItemColor: NudePalette.lightCream.withOpacity(0.6),
            currentIndex: _selectedIndex,
            onTap: (index) {
              setState(() => _selectedIndex = index);

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
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => MedicinesScreen()),
                );
              } else if (index == 3) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) => HealthScreen()), // ✅ Add this line
                );
              } else if (index == 4) {
                // TODO: Add your Feed screen navigation here if not already
              }
            },
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
              BottomNavigationBarItem(
                  icon: Icon(Icons.kitchen), label: "Kitchen"),
              BottomNavigationBarItem(
                  icon: Icon(Icons.medical_services), label: "Medicines"),
              BottomNavigationBarItem(
                  icon: Icon(Icons.favorite), label: "Health"),
              // BottomNavigationBarItem(
              //    icon: Icon(Icons.rss_feed), label: "Feed"),
            ],
          ),
        ),
      ),
    );
  }

  // FUNCTION TO BUILD OPTIONS
  Widget _buildOption({
    required String imagePath,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: NudePalette.paleBlush,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(imagePath, width: 70),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: NudePalette.darkBrown,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
