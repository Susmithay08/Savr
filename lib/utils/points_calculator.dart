import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class WeeklyPoints {
  final int meals;
  final int meds;
  final int water;
  final int sleep;
  final int workout;
  final int tasks;

  WeeklyPoints({
    required this.meals,
    required this.meds,
    required this.water,
    required this.sleep,
    required this.workout,
    required this.tasks,
  });

  int get total => meals + meds + water + sleep + workout + tasks;
}

class PointsCalculator {
  static Future<WeeklyPoints> calculatePoints(String userId) async {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1)); // Monday
    final firestore = FirebaseFirestore.instance;

    int meals = 0, meds = 0, water = 0, sleep = 0, workout = 0, tasks = 0;

    for (int i = 0; i < 7; i++) {
      final date =
          DateFormat('yyyy-MM-dd').format(startOfWeek.add(Duration(days: i)));

      // Meals
      final mealDocs = await firestore
          .collection('users/$userId/mealPlans/$date/meals')
          .get();
      if (mealDocs.docs.length == 3) meals++;

      // Medications
      final medDocs = await firestore
          .collection('users/$userId/medication_logs')
          .where('timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeek))
          .where('status', isEqualTo: 'taken')
          .get();
      if (medDocs.docs.any((doc) {
        final ts = (doc['timestamp'] as Timestamp).toDate();
        return DateFormat('yyyy-MM-dd').format(ts) == date;
      })) meds++;

      // Water
      final waterDoc =
          await firestore.doc('users/$userId/water_logs/$date').get();
      if (waterDoc.exists && (waterDoc['waterIntake'] ?? 0) >= 1) water++;

      // Sleep
      final sleepDoc =
          await firestore.doc('users/$userId/sleep_logs/$date').get();
      if (sleepDoc.exists && (sleepDoc['sleepHours'] ?? 0) >= 6) sleep++;

      // Workout
      final workoutDoc =
          await firestore.doc('users/$userId/workout_logs/$date').get();
      if (workoutDoc.exists && workoutDoc['completed'] == true) workout++;

      // Tasks
      final taskDoc =
          await firestore.doc('users/$userId/tasks_logs/$date').get();
      if (taskDoc.exists && (taskDoc['tasks'] as List?)?.isNotEmpty == true)
        tasks++;
    }

    return WeeklyPoints(
      meals: meals,
      meds: meds,
      water: water,
      sleep: sleep,
      workout: workout,
      tasks: tasks,
    );
  }
}
