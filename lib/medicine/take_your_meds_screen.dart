import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/standalone.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'dart:io';
import 'dart:async'; // ✅ Required for Timer
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:savr/health/health_screen.dart';
import 'package:savr/themes/colors.dart';

class TakeYourMedsScreen extends StatefulWidget {
  @override
  _TakeYourMedsScreenState createState() => _TakeYourMedsScreenState();
}

class _TakeYourMedsScreenState extends State<TakeYourMedsScreen> {
  List<String> selectedDays = []; // ✅ Define this in the class
  int _selectedIndex = 2;
  int _selectedDayIndex = 0;
  DateTime _selectedTime = DateTime.now();
  DateTime _currentWeekStart = DateTime.now();
  bool _isMounted = false; // ✅ Prevents setState() after dispose
  Key _medicationListKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _isMounted = true;
    _initializeTimezone();
    _setCurrentWeekStart();

    // ✅ Set _selectedDayIndex to today's index in the week (0 = Mon, 6 = Sun)
    DateTime today = DateTime.now();
    _selectedDayIndex = today.weekday - 1;
  }

  @override
  void dispose() {
    _isMounted = false;
    super.dispose();
  }

  void _safeSetState(VoidCallback callback) {
    if (_isMounted) {
      setState(callback);
    }
  }

  void _setCurrentWeekStart() {
    DateTime now = DateTime.now();
    _currentWeekStart = now.subtract(Duration(days: now.weekday - 1));
  }

  void _changeWeek(int direction) {
    _safeSetState(() {
      _currentWeekStart = _currentWeekStart.add(Duration(days: 7 * direction));
    });
  }

  Future<void> _initializeTimezone() async {
    tz.initializeTimeZones(); // Load time zone database

    // 🌍 Fallback method to get device timezone
    String localTimeZone = Platform.isAndroid || Platform.isIOS
        ? DateTime.now().timeZoneName
        : "UTC"; // fallback for web or desktop

    print("Detected Timezone (Fallback): $localTimeZone");

    tz.Location location;
    try {
      location = tz.getLocation(localTimeZone);
    } catch (e) {
      print("Failed to load location for $localTimeZone, defaulting to UTC");
      location = tz.getLocation("UTC");
    }

    // Now you can use this `location`
    DateTime now = tz.TZDateTime.now(location);
    print("🌍 Local time: $now");
  }

  void _logMedicationTaken(
      String docId, String frequency, DateTime selectedDate) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc =
        FirebaseFirestore.instance.collection("users").doc(user.uid);

    try {
      DocumentReference? docRef =
          await _findMedicationDocRef(docId, frequency, user);

      if (docRef == null) {
        throw Exception("Medication document does not exist.");
      }

      final snapshot = await docRef.get();
      final medData = snapshot.data() as Map<String, dynamic>;

      // ✅ Filter logs only for the selected day
      DateTime dayStart =
          DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      DateTime dayEnd = dayStart.add(Duration(days: 1));

      print("📅 Logging TAKEN for: $selectedDate"); // ✅ Debug info

      var logQuery = await userDoc
          .collection("medication_logs")
          .where("docId", isEqualTo: docId)
          .where("timestamp",
              isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
          .where("timestamp", isLessThan: Timestamp.fromDate(dayEnd))
          .get();

      String existingStatus = "";
      for (var log in logQuery.docs) {
        existingStatus = log['status'] ?? '';
        await log.reference.delete(); // 🔁 Remove old log
        await Future.delayed(
            Duration(milliseconds: 100)); // allow Firestore sync
      }

      // ✅ If already marked as "taken", unmark it
      if (existingStatus == "taken") {
        if (mounted) {
          setState(() {
            _medicationListKey = UniqueKey(); // 🔁 Refresh UI
          });
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Medication unmarked.")),
        );
        return;
      }

      // ✅ Create timestamp for selected date with current time
      DateTime timestamp = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        DateTime.now().hour,
        DateTime.now().minute,
        DateTime.now().second,
      );

      // ✅ Add new taken log
      await userDoc.collection("medication_logs").add({
        "docId": docId,
        "name": medData['name'] ?? 'Unknown',
        "dosage": medData['dosage'] ?? '',
        "frequency": frequency,
        "status": "taken",
        "timestamp": Timestamp.fromDate(timestamp),
      });

      if (mounted) {
        setState(() {
          _medicationListKey = UniqueKey(); // 🔁 Refresh UI
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Medication marked as taken!")),
      );
    } catch (e) {
      print("🔥 Error logging taken medication: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to mark as taken.")),
      );
    }
  }

  Future<DocumentReference?> _findMedicationDocRef(
      String docId, String frequency, User user) async {
    final userDoc =
        FirebaseFirestore.instance.collection("users").doc(user.uid);

    if (frequency == "Daily") {
      return userDoc
          .collection("medications")
          .doc("daily")
          .collection("items")
          .doc(docId);
    } else if (frequency == "Every 8 hours") {
      for (String day in [
        "Monday",
        "Tuesday",
        "Wednesday",
        "Thursday",
        "Friday",
        "Saturday",
        "Sunday"
      ]) {
        var ref = userDoc
            .collection("medications")
            .doc(day)
            .collection("items")
            .doc(docId);
        var snapshot = await ref.get();
        if (snapshot.exists) return ref;
      }
    } else if (frequency == "Monthly Once") {
      return userDoc
          .collection("medications")
          .doc("monthly_once")
          .collection("items")
          .doc(docId);
    } else {
      for (String day in [
        "Monday",
        "Tuesday",
        "Wednesday",
        "Thursday",
        "Friday",
        "Saturday",
        "Sunday"
      ]) {
        var ref = userDoc
            .collection("medications")
            .doc(day)
            .collection("items")
            .doc(docId);
        var snapshot = await ref.get();
        if (snapshot.exists) return ref;
      }
    }

    return null;
  }

  void _logMedicationSkipped(
      String docId, String frequency, DateTime selectedDate) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc =
        FirebaseFirestore.instance.collection("users").doc(user.uid);

    try {
      DocumentReference? docRef =
          await _findMedicationDocRef(docId, frequency, user);

      if (docRef == null) {
        throw Exception("Medication document does not exist.");
      }

      final snapshot = await docRef.get();
      final medData = snapshot.data() as Map<String, dynamic>;

      // ✅ Use selected date for accurate logging
      DateTime dayStart =
          DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      DateTime dayEnd = dayStart.add(Duration(days: 1));

      print("📅 Logging SKIPPED for: $selectedDate"); // ✅ Debug info

      var logQuery = await userDoc
          .collection("medication_logs")
          .where("docId", isEqualTo: docId)
          .where("timestamp",
              isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
          .where("timestamp", isLessThan: Timestamp.fromDate(dayEnd))
          .get();

      String existingStatus = "";
      for (var log in logQuery.docs) {
        existingStatus = log['status'] ?? '';
        await log.reference.delete(); // 🔁 Remove old log
        await Future.delayed(
            Duration(milliseconds: 100)); // allow Firestore sync
      }

      // ✅ If already skipped, unmark it
      if (existingStatus == "skipped") {
        if (mounted) {
          setState(() {
            _medicationListKey = UniqueKey(); // 🔁 Refresh
          });
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Medication unmarked.")),
        );
        return;
      }

      // ✅ Log as skipped using selectedDate
      DateTime timestamp = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        DateTime.now().hour,
        DateTime.now().minute,
        DateTime.now().second,
      );

      await userDoc.collection("medication_logs").add({
        "docId": docId,
        "name": medData['name'] ?? 'Unknown',
        "dosage": medData['dosage'] ?? '',
        "frequency": frequency,
        "status": "skipped",
        "timestamp": Timestamp.fromDate(timestamp),
      });

      if (mounted) {
        setState(() {
          _medicationListKey = UniqueKey(); // 🔁 Refresh UI
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Medication skipped for selected day.")),
      );
    } catch (e) {
      print("🔥 Error logging skipped medication: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to mark as skipped.")),
      );
    }
  }

  Future<void> _saveMedicationToFirestore(String name, String dosage,
      DateTime time, String frequency, List<String> specificDays) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    var firestore = FirebaseFirestore.instance;
    var userDoc = firestore.collection("users").doc(user.uid);

    if (frequency == "Daily") {
      var dailyDocRef = userDoc.collection("medications").doc("daily");
      await dailyDocRef.set({"exists": true}, SetOptions(merge: true));

      DocumentReference newMedRef = await dailyDocRef.collection("items").add({
        "name": name,
        "dosage": dosage,
        "time": Timestamp.fromDate(time),
        "frequency": frequency,
        "days": [],
      });

      await newMedRef.update({"docId": newMedRef.id});
    } else if (frequency == "Every 8 hours") {
      for (String day in specificDays) {
        var dayDocRef = userDoc.collection("medications").doc(day);
        await dayDocRef.set({"exists": true}, SetOptions(merge: true));

        for (int i = 0; i < 3; i++) {
          DateTime newTime = time.add(Duration(hours: i * 8));
          DocumentReference newMedRef =
              await dayDocRef.collection("items").add({
            "name": name,
            "dosage": dosage,
            "time": Timestamp.fromDate(newTime),
            "frequency": frequency,
            "days": specificDays,
          });

          await newMedRef.update({"docId": newMedRef.id});
        }
      }
    } else if (frequency == "Monthly Once") {
      var monthlyDocRef = userDoc.collection("medications").doc("monthly_once");
      await monthlyDocRef.set({"exists": true}, SetOptions(merge: true));

      DocumentReference newMedRef =
          await monthlyDocRef.collection("items").add({
        "name": name,
        "dosage": dosage,
        "time": Timestamp.fromDate(time),
        "frequency": frequency,
        "days": [],
      });

      await newMedRef.update({"docId": newMedRef.id});
    } else {
      for (String day in specificDays) {
        var dayDocRef = userDoc.collection("medications").doc(day);
        await dayDocRef.set({"exists": true}, SetOptions(merge: true));

        DocumentReference newMedRef = await dayDocRef.collection("items").add({
          "name": name,
          "dosage": dosage,
          "time": Timestamp.fromDate(time),
          "frequency": frequency,
          "days": specificDays,
        });

        await newMedRef.update({"docId": newMedRef.id});
      }
    }

    print("🔥 Medication added successfully!");
  }

  void _startLiveDateUpdate(tz.Location location) {
    Timer.periodic(Duration(minutes: 1), (timer) {
      DateTime now = tz.TZDateTime.now(location);
      int newDayIndex = (now.weekday - 1) % 7;

      if (newDayIndex != _selectedDayIndex) {
        _safeSetState(() {
          // ✅ Safe setState call
          _selectedDayIndex = newDayIndex;
        });
      }
    });
  }

  void _onBottomNavTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    if (index == 0) {
      Navigator.pushReplacementNamed(context, '/home');
    } else if (index == 1) {
      Navigator.pushReplacementNamed(context, '/kitchen');
    } else if (index == 2) {
      Navigator.pushReplacementNamed(context, '/medicines');
    } else if (index == 3) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HealthScreen()),
      );
    } //else if (index == 4) {
    //ScaffoldMessenger.of(context).showSnackBar(
    // SnackBar(content: Text("Feed screen coming soon!")),
    //);
    // }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: NudePalette.lightCream,
        elevation: 0,
        title: const Text(
          "Take Your Meds",
          style: TextStyle(
            color: NudePalette.darkBrown,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: NudePalette.darkBrown),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: "View History",
            onPressed: _showMedicationHistory,
          ),
        ],
      ),
      body: Column(
        children: [
          buildWeekView(), // ✅ This ensures week range displays
          _buildWeekNavigation(),
          Expanded(
            child: SingleChildScrollView(
              child: Column(children: [_buildMedicationList()]),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddMedicationPopup(), // ✅ Restored this function
        child: Icon(Icons.add),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.black,
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
            // BottomNavigationBarItem(icon: Icon(Icons.rss_feed), label: "Feed"),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekNavigation() {
    return SizedBox.shrink(); // Removed empty row to avoid unnecessary spacing
  }

  Widget _buildWeekCalendar() {
    return Container(
      padding: EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous Week Arrow
          IconButton(
            icon: Text("<",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            onPressed: () => _changeWeek(-1),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(7, (index) {
                DateTime date = _currentWeekStart.add(Duration(days: index));
                String dayName = DateFormat('EEEE').format(date);
                bool isSelected = _selectedDayIndex == index;

                return GestureDetector(
                  onTap: () {
                    _safeSetState(() {
                      _selectedDayIndex = index;
                    });
                    print("📅 Selected Day: $dayName"); // ✅ Debugging output
                  },
                  child: Column(
                    children: [
                      Text(
                        DateFormat('E').format(date),
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.black : Colors.grey,
                        ),
                      ),
                      SizedBox(height: 5),
                      CircleAvatar(
                        backgroundColor:
                            isSelected ? Colors.blue : Colors.transparent,
                        child: Text(
                          "${date.day}",
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
          // Next Week Arrow
          IconButton(
            icon: Text(">",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            onPressed: () => _changeWeek(1),
          ),
        ],
      ),
    );
  }

  Widget buildWeekView() {
    return Column(
      children: [
        SizedBox(height: 10),
        Center(
          child: Text(
            "${DateFormat('MMM dd').format(_currentWeekStart)} - ${DateFormat('MMM dd').format(_currentWeekStart.add(Duration(days: 6)))}",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(height: 10),
        _buildWeekCalendar(),
      ],
    );
  }

  Widget _buildMedicationList() {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Center(child: Text("Please log in to view medications"));
    }

    DateTime selectedDate =
        _currentWeekStart.add(Duration(days: _selectedDayIndex));
    String selectedDay = DateFormat('EEEE').format(selectedDate);
    int selectedDayOfMonth = selectedDate.day;

    print("📆 Selected Date: $selectedDate ($selectedDay)");

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .collection("medications")
          .snapshots(),
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        List<QueryDocumentSnapshot> medicationDocs = snapshot.data!.docs;
        List<Future<QuerySnapshot>> medicationFutures = [];

        for (var doc in medicationDocs) {
          if (doc.id == "daily" ||
              doc.id == "every_8_hours" ||
              doc.id == selectedDay) {
            medicationFutures.add(doc.reference.collection("items").get());
          }

          if (doc.id == "monthly_once") {
            medicationFutures.add(
              doc.reference.collection("items").get().then((qs) {
                List<QueryDocumentSnapshot<Map<String, dynamic>>> filtered =
                    qs.docs.where((doc) {
                  Timestamp ts = doc['time'];
                  return ts.toDate().day == selectedDayOfMonth;
                }).toList();
                return QuerySnapshotFake<Map<String, dynamic>>(filtered);
              }),
            );
          }
        }

        return FutureBuilder<List<dynamic>>(
          future: Future.wait(medicationFutures),
          builder: (context, medSnapshot) {
            if (!medSnapshot.hasData) {
              return Center(child: CircularProgressIndicator());
            }

            List<QueryDocumentSnapshot> medList = [];
            for (var data in medSnapshot.data!) {
              medList.addAll(data.docs);
            }

            medList.sort((a, b) {
              DateTime timeA = (a['time'] as Timestamp).toDate();
              DateTime timeB = (b['time'] as Timestamp).toDate();
              return timeA.compareTo(timeB);
            });

            if (medList.isEmpty) {
              return Center(child: Text("No medications for $selectedDay."));
            }

            DateTime dayStart = DateTime(
              selectedDate.year,
              selectedDate.month,
              selectedDate.day,
            );
            DateTime dayEnd = dayStart.add(Duration(days: 1));

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("users")
                  .doc(user.uid)
                  .collection("medication_logs")
                  .where("timestamp",
                      isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
                  .where("timestamp", isLessThan: Timestamp.fromDate(dayEnd))
                  .snapshots(),
              builder: (context, logSnapshot) {
                if (!logSnapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                List<QueryDocumentSnapshot> logs = logSnapshot.data!.docs;

                return KeyedSubtree(
                  key: _medicationListKey,
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: medList.length,
                    itemBuilder: (context, index) {
                      var medication = medList[index];
                      Map<String, dynamic> medData =
                          medication.data() as Map<String, dynamic>;

                      String docId = medData["docId"] ?? medication.id;
                      String name = medData["name"] ?? "Unknown";
                      String dosage = medData["dosage"] ?? "Unknown";
                      String frequency = medData["frequency"] ?? "Unknown";
                      DateTime time = (medData["time"] as Timestamp).toDate();

                      String status = '';
                      for (var log in logs) {
                        if (log['docId'] == docId) {
                          final logStatus = log['status'] ?? '';
                          if (logStatus == 'skipped') {
                            status = 'skipped';
                            break;
                          } else if (logStatus == 'taken' &&
                              status != 'skipped') {
                            status = 'taken';
                          }
                        }
                      }

                      return _buildMedicationItem(
                        docId,
                        name,
                        dosage,
                        frequency,
                        time,
                        status,
                      );
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildMedicationItem(
    String docId,
    String name,
    String dosage,
    String frequency,
    DateTime time,
    String status,
  ) {
    return Card(
      color: NudePalette.paleBlush,
      margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: () => _showMedicationOptions(docId, frequency, time,
            _currentWeekStart.add(Duration(days: _selectedDayIndex))),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat.jm().format(time),
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: NudePalette.darkBrown),
              ),
              SizedBox(height: 5),
              Text(
                name,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 5),
              Text(
                "$dosage | $frequency",
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              if (status == "taken" || status == "skipped") SizedBox(height: 8),
              if (status == "taken")
                Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 18),
                    SizedBox(width: 5),
                    Text(
                      "Taken",
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              if (status == "skipped")
                Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.orange, size: 18),
                    SizedBox(width: 5),
                    Text(
                      "Skipped",
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              Align(
                alignment: Alignment.centerRight,
                child: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == "edit") {
                      _showEditMedicationPopup(
                          docId, name, dosage, frequency, time);
                    } else if (value == "delete") {
                      _deleteMedication(docId);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: "edit",
                      child: Text("Edit",
                          style: TextStyle(color: NudePalette.darkBrown)),
                    ),
                    PopupMenuItem(
                      value: "delete",
                      child: Text("Delete",
                          style: TextStyle(color: NudePalette.darkBrown)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditMedicationPopup(
    String docId,
    String currentName,
    String currentDosage,
    String currentFrequency,
    DateTime currentTime,
  ) {
    TextEditingController nameController =
        TextEditingController(text: currentName);
    TextEditingController dosageController =
        TextEditingController(text: currentDosage);
    DateTime selectedTime = currentTime;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 20,
                left: 20,
                right: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Edit Medication",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 10),
                  Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    margin: EdgeInsets.symmetric(vertical: 6),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: "Medication Name",
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 10),
                  Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    margin: EdgeInsets.symmetric(vertical: 6),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: TextField(
                        controller: dosageController,
                        decoration: InputDecoration(
                          labelText: "Dosage (e.g., 500mg, 10ml)",
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 10),

                  /// Time Picker
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Scheduled Time: ${DateFormat.jm().format(selectedTime)}",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: Icon(Icons.access_time),
                        onPressed: () async {
                          TimeOfDay? picked = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(selectedTime),
                          );
                          if (picked != null) {
                            setModalState(() {
                              // ✅ Preserve original date, change only time
                              selectedTime = DateTime(
                                selectedTime.year,
                                selectedTime.month,
                                selectedTime.day,
                                picked.hour,
                                picked.minute,
                              );
                            });
                          }
                        },
                      ),
                    ],
                  ),

                  SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: NudePalette.mauveBrown,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      User? user = FirebaseAuth.instance.currentUser;
                      if (user == null) return;

                      final firestore = FirebaseFirestore.instance;
                      final userDoc =
                          firestore.collection("users").doc(user.uid);

                      try {
                        if (currentFrequency == "Daily") {
                          await userDoc
                              .collection("medications")
                              .doc("daily")
                              .collection("items")
                              .doc(docId)
                              .update({
                            "name": nameController.text,
                            "dosage": dosageController.text,
                            "time": Timestamp.fromDate(selectedTime),
                          });
                        } else if (currentFrequency == "Every 8 hours") {
                          for (String day in [
                            "Monday",
                            "Tuesday",
                            "Wednesday",
                            "Thursday",
                            "Friday",
                            "Saturday",
                            "Sunday"
                          ]) {
                            var docRef = userDoc
                                .collection("medications")
                                .doc(day)
                                .collection("items")
                                .doc(docId);
                            var snapshot = await docRef.get();
                            if (snapshot.exists) {
                              await docRef.update({
                                "name": nameController.text,
                                "dosage": dosageController.text,
                                "time": Timestamp.fromDate(selectedTime),
                              });
                              //await scheduleNotification(
                              // id: DateTime.now().millisecondsSinceEpoch ~/
                              //    1000,
                              // title: 'Time to take your medicine 💊',
                              // body:
                              //    '${nameController.text} - ${dosageController.text}',
                              // scheduledDateTime: selectedTime,
                              //);

                              break;
                            }
                          }
                        } else if (currentFrequency == "Monthly Once") {
                          await userDoc
                              .collection("medications")
                              .doc("monthly_once")
                              .collection("items")
                              .doc(docId)
                              .update({
                            "name": nameController.text,
                            "dosage": dosageController.text,
                            "time": Timestamp.fromDate(selectedTime),
                          });
                        } else {
                          // Specific Days
                          String today =
                              DateFormat('EEEE').format(DateTime.now());
                          await userDoc
                              .collection("medications")
                              .doc(today)
                              .collection("items")
                              .doc(docId)
                              .update({
                            "name": nameController.text,
                            "dosage": dosageController.text,
                            "time": Timestamp.fromDate(selectedTime),
                          });
                        }

                        Future.microtask(() => Navigator.pop(context));

                        setState(() {}); // ✅ Refresh the UI
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content:
                                  Text("Medication Updated Successfully!")),
                        );
                      } catch (e) {
                        print("🔥 Error updating medication: $e");
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text("Failed to update medication.")),
                        );
                      }
                    },
                    child: Text("Save Changes"),
                  ),
                  SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _deleteMedication(String docId) {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String today = DateFormat('EEEE').format(DateTime.now());

    showDialog(
      context: context,
      builder: (context) {
        return Theme(
          data: Theme.of(context).copyWith(
            dialogBackgroundColor: NudePalette.lightCream,
            textTheme: TextTheme(
              bodyMedium: TextStyle(color: NudePalette.darkBrown),
            ),
          ),
          child: AlertDialog(
            title: Text("Delete Medication",
                style: TextStyle(color: NudePalette.darkBrown)),
            content: Text("Are you sure you want to delete this medication?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Cancel"),
              ),
              TextButton(
                onPressed: () async {
                  try {
                    var firestore = FirebaseFirestore.instance;
                    var userDoc = firestore.collection("users").doc(user.uid);

                    // 🔥 Delete from today's collection
                    await userDoc
                        .collection("medications")
                        .doc(today)
                        .collection("items")
                        .doc(docId)
                        .delete();

                    // 🔥 Delete from daily
                    await userDoc
                        .collection("medications")
                        .doc("daily")
                        .collection("items")
                        .doc(docId)
                        .delete();

                    // 🔥 Delete from every_8_hours
                    await userDoc
                        .collection("medications")
                        .doc("every_8_hours")
                        .collection("items")
                        .doc(docId)
                        .delete();

                    // 🔥 Delete from monthly_once
                    await userDoc
                        .collection("medications")
                        .doc("monthly_once")
                        .collection("items")
                        .doc(docId)
                        .delete();

                    // 🔥 Also try deleting from any specific day collections
                    List<String> allDays = [
                      "Monday",
                      "Tuesday",
                      "Wednesday",
                      "Thursday",
                      "Friday",
                      "Saturday",
                      "Sunday"
                    ];

                    for (String day in allDays) {
                      await userDoc
                          .collection("medications")
                          .doc(day)
                          .collection("items")
                          .doc(docId)
                          .delete();
                    }

                    Navigator.pop(context);
                    _safeSetState(() {}); // ✅ Refresh the UI

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text("Medication Deleted Successfully!")),
                    );
                  } catch (e) {
                    print("🔥 Error deleting medication: $e");
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Failed to delete medication.")),
                    );
                  }
                },
                child: Text("Delete", style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMedicationOptions(
      String docId, String frequency, DateTime time, DateTime selectedDate) {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text("Taken"),
                onTap: () {
                  _logMedicationTaken(
                      docId, frequency, selectedDate); // ✅ updated
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: Text("Skip"),
                onTap: () {
                  _logMedicationSkipped(
                      docId, frequency, selectedDate); // ✅ updated
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: Text("Change Time"),
                onTap: () {
                  Navigator.pop(context);
                  _showReschedulePopup(docId, frequency, time);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMedicationHistory() {
    String selectedStatus = "All";
    String searchQuery = "";
    DateTime? startDate;
    DateTime? endDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.88, // 👈 limit height
          child: Scaffold(
            appBar: AppBar(
              backgroundColor: NudePalette.lightCream,
              elevation: 0,
              automaticallyImplyLeading: false,
              title: Text(
                "Medication History",
                style: TextStyle(
                  color: NudePalette.darkBrown,
                  fontWeight: FontWeight.bold,
                ),
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.delete_forever, color: Colors.red),
                  tooltip: "Clear History",
                  onPressed: () async {
                    bool? confirm = await showDialog(
                      context: context,
                      builder: (context) => Theme(
                        data: Theme.of(context).copyWith(
                          dialogBackgroundColor: NudePalette.lightCream,
                          textTheme: TextTheme(
                            bodyMedium: TextStyle(color: NudePalette.darkBrown),
                          ),
                        ),
                        child: AlertDialog(
                          title: Text("Clear All History",
                              style: TextStyle(color: NudePalette.darkBrown)),
                          content: Text(
                              "Are you sure you want to delete all history?"),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text("Cancel"),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: Text("Delete",
                                  style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      ),
                    );

                    if (confirm == true) {
                      User? user = FirebaseAuth.instance.currentUser;
                      var logRef = FirebaseFirestore.instance
                          .collection("users")
                          .doc(user!.uid)
                          .collection("medication_logs");

                      var logs = await logRef.get();
                      for (var doc in logs.docs) {
                        await doc.reference.delete();
                      }

                      Future.microtask(() => Navigator.pop(context));
// Close the modal
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text("All medication history cleared!")),
                      );
                    }
                  },
                )
              ],
            ),
            body: StatefulBuilder(
              builder: (context, setModalState) {
                return FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance
                      .collection("users")
                      .doc(FirebaseAuth.instance.currentUser!.uid)
                      .collection("medication_logs")
                      .orderBy("timestamp", descending: true)
                      .get(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return Center(child: CircularProgressIndicator());
                    }

                    var filteredLogs = snapshot.data!.docs.where((doc) {
                      var log = doc.data() as Map<String, dynamic>;
                      String name = log["name"]?.toString().toLowerCase() ?? "";
                      String status = log["status"] ?? "";
                      DateTime time = (log["timestamp"] as Timestamp).toDate();

                      bool matchesStatus = selectedStatus == "All" ||
                          selectedStatus.toLowerCase() == status.toLowerCase();
                      bool matchesName = name.contains(searchQuery);
                      bool matchesDate = true;

                      if (startDate != null && endDate != null) {
                        matchesDate = !time.isBefore(startDate!) &&
                            time.isBefore(endDate!.add(Duration(days: 1)));
                      }

                      return matchesStatus && matchesName && matchesDate;
                    }).toList();

                    if (filteredLogs.isEmpty) {
                      return Center(
                          child: Text("No medication history found."));
                    }

                    // Group filtered logs by month-year
                    Map<String, List<QueryDocumentSnapshot>> groupedLogs = {};
                    for (var log in filteredLogs) {
                      DateTime time = (log['timestamp'] as Timestamp).toDate();
                      String monthYear = DateFormat('MMMM yyyy').format(time);
                      if (!groupedLogs.containsKey(monthYear)) {
                        groupedLogs[monthYear] = [];
                      }
                      groupedLogs[monthYear]!.add(log);
                    }

                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      value: selectedStatus,
                                      onChanged: (value) {
                                        setModalState(() {
                                          selectedStatus = value!;
                                        });
                                      },
                                      items: ["All", "Taken", "Skipped"]
                                          .map((status) => DropdownMenuItem(
                                              value: status,
                                              child: Text(status)))
                                          .toList(),
                                      decoration: InputDecoration(
                                          labelText: "Filter by Status"),
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: TextField(
                                      onChanged: (value) {
                                        setModalState(() {
                                          searchQuery = value.toLowerCase();
                                        });
                                      },
                                      decoration: InputDecoration(
                                          labelText: "Search by Name"),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () async {
                                        DateTimeRange? picked =
                                            await showDateRangePicker(
                                          context: context,
                                          firstDate: DateTime(2020),
                                          lastDate: DateTime.now(),
                                        );
                                        if (picked != null) {
                                          setModalState(() {
                                            startDate = picked.start;
                                            endDate = picked.end;
                                          });
                                        }
                                      },
                                      child: Text("Select Date Range"),
                                    ),
                                  ),
                                  if (startDate != null && endDate != null) ...[
                                    SizedBox(width: 10),
                                    IconButton(
                                      onPressed: () {
                                        setModalState(() {
                                          startDate = null;
                                          endDate = null;
                                        });
                                      },
                                      icon: Icon(Icons.clear),
                                      tooltip: "Clear Date Range",
                                    ),
                                  ],
                                ],
                              ),
                              if (startDate != null && endDate != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      "${DateFormat('MMM dd').format(startDate!)} – ${DateFormat('MMM dd').format(endDate!)}",
                                      style: TextStyle(color: Colors.blue[800]),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView(
                            children: groupedLogs.entries.map((entry) {
                              String month = entry.key;
                              List<QueryDocumentSnapshot> monthLogs =
                                  entry.value;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10, horizontal: 16),
                                    child: Text(
                                      month,
                                      style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  ...monthLogs.map((logDoc) {
                                    var log =
                                        logDoc.data() as Map<String, dynamic>;
                                    String name = log["name"] ?? "Unknown";
                                    String status = log["status"] ?? "Unknown";
                                    DateTime time =
                                        (log["timestamp"] as Timestamp)
                                            .toDate();

                                    return ListTile(
                                      leading: Icon(
                                        status == "taken"
                                            ? Icons.check_circle
                                            : Icons.cancel,
                                        color: status == "taken"
                                            ? Colors.green
                                            : Colors.orange,
                                      ),
                                      title: Text(name),
                                      subtitle: Text(
                                        DateFormat.yMMMd()
                                            .add_jm()
                                            .format(time),
                                      ),
                                      trailing: Text(
                                        status.toUpperCase(),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: status == "taken"
                                              ? Colors.green
                                              : Colors.orange,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showReschedulePopup(
      String docId, String frequency, DateTime currentTime) {
    DateTime selectedTime = currentTime;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Reschedule Time",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              SizedBox(
                height: 200,
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  initialDateTime: currentTime,
                  onDateTimeChanged: (DateTime newTime) {
                    selectedTime = newTime;
                  },
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: NudePalette.mauveBrown,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  User? user = FirebaseAuth.instance.currentUser;
                  if (user == null) return;

                  final firestore = FirebaseFirestore.instance;
                  final userDoc = firestore.collection("users").doc(user.uid);

                  try {
                    if (frequency == "Daily") {
                      await userDoc
                          .collection("medications")
                          .doc("daily")
                          .collection("items")
                          .doc(docId)
                          .update({"time": Timestamp.fromDate(selectedTime)});
                    } else if (frequency == "Every 8 hours") {
                      for (String day in [
                        "Monday",
                        "Tuesday",
                        "Wednesday",
                        "Thursday",
                        "Friday",
                        "Saturday",
                        "Sunday"
                      ]) {
                        final itemsRef = userDoc
                            .collection("medications")
                            .doc(day)
                            .collection("items");

                        final snap = await itemsRef.doc(docId).get();
                        if (snap.exists) {
                          await itemsRef.doc(docId).update(
                              {"time": Timestamp.fromDate(selectedTime)});
                          break;
                        }
                      }
                    } else if (frequency == "Monthly Once") {
                      await userDoc
                          .collection("medications")
                          .doc("monthly_once")
                          .collection("items")
                          .doc(docId)
                          .update({"time": Timestamp.fromDate(selectedTime)});
                    } else {
                      String today = DateFormat('EEEE').format(DateTime.now());
                      await userDoc
                          .collection("medications")
                          .doc(today)
                          .collection("items")
                          .doc(docId)
                          .update({"time": Timestamp.fromDate(selectedTime)});
                    }

                    // 🟢 Schedule Notification after Reschedule
                    //await scheduleNotification(
                    // id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                    // title: 'Medication Reminder 💊',
                    // body: 'Your medication is rescheduled.',
                    //  scheduledDateTime: selectedTime,
                    // );

                    Future.microtask(() => Navigator.pop(context));

                    if (mounted) {
                      setState(() {});
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          "Medication rescheduled to ${DateFormat.jm().format(selectedTime)}",
                        ),
                      ),
                    );
                  } catch (e) {
                    print("🔥 Error rescheduling: $e");
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text("Failed to reschedule medication.")),
                    );
                  }
                },
                child: Text("Done"),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmReschedule() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              "Medication rescheduled to ${DateFormat.jm().format(_selectedTime)}")),
    );
  }

  // 🟢 Show Add Medication Popup
  void _showAddMedicationPopup() {
    TextEditingController nameController = TextEditingController();
    TextEditingController dosageController = TextEditingController();
    String _selectedFrequency = "Daily"; // Default: Daily
    DateTime? selectedTime;
    List<String> selectedDays = []; // Store selected days

    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("You must be logged in to add medications.")),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  top: 20,
                  left: 20,
                  right: 20),
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: NudePalette.paleBlush,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Add Medication",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 10),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: "Medication Name",
                        filled: true,
                        fillColor: NudePalette.paleBlush,
                        labelStyle: TextStyle(color: NudePalette.darkBrown),
                        border: OutlineInputBorder(
                          borderSide: BorderSide.none,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),

                    SizedBox(height: 10),
                    TextField(
                      controller: dosageController,
                      decoration: InputDecoration(
                        labelText: "Dosage (e.g., 500mg, 10ml)",
                        filled: true,
                        fillColor: NudePalette.paleBlush,
                        labelStyle: TextStyle(color: NudePalette.darkBrown),
                        border: OutlineInputBorder(
                          borderSide: BorderSide.none,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    SizedBox(height: 10),

                    /// Frequency Dropdown
                    Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      margin: EdgeInsets.symmetric(vertical: 6),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: DropdownButtonFormField<String>(
                          value: _selectedFrequency,
                          items: [
                            DropdownMenuItem(
                                value: "Daily", child: Text("Daily")),
                            DropdownMenuItem(
                                value: "Every 8 hours",
                                child: Text("Every 8 hours")),
                            DropdownMenuItem(
                                value: "Specific Days",
                                child: Text("Select Specific Days")),
                            DropdownMenuItem(
                                value: "Monthly Once",
                                child: Text("Monthly Once")),
                          ],
                          onChanged: (value) {
                            setModalState(() {
                              _selectedFrequency = value!;

                              if (_selectedFrequency == "Specific Days") {
                                _showDaySelectionDialog(
                                    setModalState, selectedDays);
                              }

                              if (_selectedFrequency == "Every 8 hours") {
                                _showDaySelectionDialog(
                                    setModalState, selectedDays);
                              }

                              if (_selectedFrequency == "Monthly Once") {
                                showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime.now(),
                                  lastDate:
                                      DateTime.now().add(Duration(days: 365)),
                                ).then((pickedDate) {
                                  if (pickedDate != null) {
                                    showTimePicker(
                                      context: context,
                                      initialTime: TimeOfDay.now(),
                                    ).then((pickedTime) {
                                      if (pickedTime != null) {
                                        setModalState(() {
                                          selectedTime = DateTime(
                                            pickedDate.year,
                                            pickedDate.month,
                                            pickedDate.day,
                                            pickedTime.hour,
                                            pickedTime.minute,
                                          );
                                        });
                                      }
                                    });
                                  }
                                });
                              }
                            });
                          },
                          decoration: InputDecoration(
                            labelText: "Frequency",
                            filled: true,
                            fillColor: NudePalette.paleBlush,
                            labelStyle: TextStyle(color: NudePalette.darkBrown),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          dropdownColor: NudePalette.lightCream,
                          style: TextStyle(color: NudePalette.darkBrown),
                        ),
                      ),
                    ),

                    SizedBox(height: 10),

                    /// Time Picker Section
                    Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      margin: EdgeInsets.symmetric(vertical: 6),
                      child: Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              selectedTime == null
                                  ? "No time selected"
                                  : "Scheduled Time: ${DateFormat.jm().format(selectedTime!)}",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            IconButton(
                              icon: Icon(Icons.access_time),
                              onPressed: () {
                                showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay.now(),
                                ).then((pickedTime) {
                                  if (pickedTime != null) {
                                    DateTime now = DateTime.now();
                                    DateTime pickedDateTime = DateTime(
                                        now.year,
                                        now.month,
                                        now.day,
                                        pickedTime.hour,
                                        pickedTime.minute);
                                    setModalState(() {
                                      selectedTime = pickedDateTime;
                                    });
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: NudePalette.mauveBrown,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        if (nameController.text.isEmpty ||
                            dosageController.text.isEmpty ||
                            selectedTime == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(
                                    "Please fill all fields and select a time")),
                          );
                          return;
                        }

                        if (_selectedFrequency == "Specific Days" &&
                            selectedDays.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content:
                                    Text("Please select at least one day")),
                          );
                          return;
                        }

                        await _saveMedicationToFirestore(
                          nameController.text,
                          dosageController.text,
                          selectedTime!,
                          _selectedFrequency,
                          selectedDays,
                        );

// 👉 Immediately close the modal
                        if (context.mounted) {
                          Navigator.pop(context); // ✅ Close the popup
                        }

// 👉 Rebuild the list instantly
                        if (mounted) {
                          setState(() {
                            _medicationListKey =
                                UniqueKey(); // 🔁 force rebuild
                          });
                        }

// ✅ Show success
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text("Medication Added Successfully!")),
                        );
                      },
                      child: Text("Save"),
                    ),

                    SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showDaySelectionDialog(
      void Function(void Function()) setModalState, List<String> selectedDays) {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Theme(
              data: Theme.of(context).copyWith(
                dialogBackgroundColor: NudePalette.lightCream,
                textTheme: TextTheme(
                  bodyMedium: TextStyle(color: NudePalette.darkBrown),
                ),
              ),
              child: AlertDialog(
                title: Text("Select Days",
                    style: TextStyle(color: NudePalette.darkBrown)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (String day in [
                      "Monday",
                      "Tuesday",
                      "Wednesday",
                      "Thursday",
                      "Friday",
                      "Saturday",
                      "Sunday"
                    ])
                      CheckboxListTile(
                        title: Text(day),
                        value: selectedDays.contains(day),
                        onChanged: (bool? checked) {
                          setState(() {
                            if (checked == true) {
                              if (!selectedDays.contains(day)) {
                                selectedDays.add(day);
                              }
                            } else {
                              selectedDays.remove(day);
                            }
                          });
                        },
                      ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text("Cancel"),
                  ),
                  TextButton(
                    onPressed: () {
                      setModalState(() {}); // ✅ Update UI
                      Navigator.pop(context);
                    },
                    child: Text("Save"),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class QuerySnapshotFake<T> implements QuerySnapshot<T> {
  final List<QueryDocumentSnapshot<T>> _docs;

  QuerySnapshotFake(this._docs);

  @override
  List<QueryDocumentSnapshot<T>> get docs => _docs;

  @override
  List<DocumentChange<T>> get docChanges => [];

  @override
  SnapshotMetadata get metadata => SnapshotMetadataFake();

  @override
  int get size => _docs.length;

  @override
  bool get isEmpty => _docs.isEmpty;

  @override
  bool get isNotEmpty => _docs.isNotEmpty;

  @override
  Query<T> get query => throw UnimplementedError();
}

// ✅ Fake SnapshotMetadata class
class SnapshotMetadataFake implements SnapshotMetadata {
  @override
  bool get hasPendingWrites => false;

  @override
  bool get isFromCache => false;
}
