import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:savr/themes/colors.dart';

class SavedWorkoutsScreen extends StatefulWidget {
  const SavedWorkoutsScreen({Key? key}) : super(key: key);

  @override
  _SavedWorkoutsScreenState createState() => _SavedWorkoutsScreenState();
}

class _SavedWorkoutsScreenState extends State<SavedWorkoutsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<DocumentSnapshot> _savedWorkouts = [];

  Future<void> _loadSavedWorkouts() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('saved_workouts')
        .orderBy('timestamp', descending: true)
        .get();
    setState(() {
      _savedWorkouts = snapshot.docs;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadSavedWorkouts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NudePalette.lightCream,
      appBar: AppBar(
        title: const Text(
          "Saved Workouts",
          style: TextStyle(color: NudePalette.darkBrown),
        ),
        backgroundColor: NudePalette.lightCream,
        iconTheme: const IconThemeData(color: NudePalette.darkBrown),
        elevation: 0,
      ),
      body: _savedWorkouts.isEmpty
          ? const Center(
              child: Text("No saved workouts yet.",
                  style: TextStyle(color: NudePalette.darkBrown)))
          : ListView.builder(
              itemCount: _savedWorkouts.length,
              itemBuilder: (context, index) {
                final data =
                    _savedWorkouts[index].data() as Map<String, dynamic>;
                final timestamp = data['timestamp'] as Timestamp?;
                final dateStr = timestamp != null
                    ? DateFormat('yyyy-MM-dd').format(timestamp.toDate())
                    : '';
                return Card(
                  color: NudePalette.paleBlush,
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    title: Text(
                      data['fitnessName'] ?? "Workout Plan",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: NudePalette.darkBrown),
                    ),
                    subtitle: Text(
                      "${data['workoutType'] ?? ""} - ${data['duration'] ?? ""}",
                      style: const TextStyle(color: NudePalette.darkBrown),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(dateStr,
                            style: const TextStyle(
                                color: NudePalette.darkBrown, fontSize: 12)),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            await _firestore
                                .collection('users')
                                .doc(_auth.currentUser!.uid)
                                .collection('saved_workouts')
                                .doc(_savedWorkouts[index].id)
                                .delete();
                            _loadSavedWorkouts();
                          },
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => WorkoutPlanDetailsScreen(data: data),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}

class WorkoutPlanDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> data;
  const WorkoutPlanDetailsScreen({Key? key, required this.data})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final fitnessName = data['fitnessName'] ?? "Workout Plan";
    final plan = data['plan'] ?? "";
    return Scaffold(
      backgroundColor: NudePalette.lightCream,
      appBar: AppBar(
        title: Text(
          fitnessName,
          style: const TextStyle(color: NudePalette.darkBrown),
        ),
        backgroundColor: NudePalette.lightCream,
        iconTheme: const IconThemeData(color: NudePalette.darkBrown),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Text(
            plan,
            style: const TextStyle(fontSize: 16, color: NudePalette.darkBrown),
          ),
        ),
      ),
    );
  }
}
