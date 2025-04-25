import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:savr/themes/colors.dart';

class WorkoutTimerPage extends StatefulWidget {
  final List<Map<String, dynamic>> exercises;
  final String? workoutTag;

  const WorkoutTimerPage({
    super.key,
    required this.exercises,
    this.workoutTag,
  });

  @override
  State<WorkoutTimerPage> createState() => _WorkoutTimerPageState();
}

class _WorkoutTimerPageState extends State<WorkoutTimerPage> {
  int currentIndex = 0;
  int timerValue = 0;
  int originalTimerValue = 0;
  bool isPaused = false;
  bool inRest = false;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    _startTimerForCurrent();
  }

  void _startTimerForCurrent() {
    final reps = widget.exercises[currentIndex]['reps'];
    timerValue = _parseRepsToSeconds(reps);
    originalTimerValue = timerValue;
    inRest = false;
    _startTimer();
  }

  int _parseRepsToSeconds(String reps) {
    if (reps.contains('sec')) {
      return int.tryParse(reps.replaceAll(RegExp(r'[^0-9]'), '')) ?? 30;
    } else {
      return 30;
    }
  }

  void _startRest() {
    inRest = true;
    timerValue = 10;
    originalTimerValue = timerValue;
    _startTimer();
  }

  void _startTimer() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!isPaused) {
        setState(() {
          timerValue--;
        });
        if (timerValue == 0) {
          timer?.cancel();
          _nextStep();
        }
      }
    });
  }

  void _resetTimer() {
    setState(() {
      timerValue = originalTimerValue;
    });
  }

  void _nextStep() {
    if (inRest) {
      currentIndex++;
      if (currentIndex < widget.exercises.length) {
        _startTimerForCurrent();
      } else {
        _finishWorkout();
      }
    } else {
      if (currentIndex + 1 < widget.exercises.length) {
        _startRest();
      } else {
        _finishWorkout();
      }
    }
  }

  Future<void> _markWorkoutCompleted({String? workoutDone}) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final now = DateTime.now();
    final todayStr =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    final userDoc = FirebaseFirestore.instance.collection('users').doc(userId);

    await userDoc.collection('workout_logs').doc(todayStr).set({
      'completed': true,
      if (workoutDone != null) 'workoutDone': workoutDone,
    }, SetOptions(merge: true));

    await userDoc.collection('completedWorkouts').doc(todayStr).set({
      'status': 'done',
      if (workoutDone != null) 'workoutDone': workoutDone,
    }, SetOptions(merge: true));
  }

  Future<void> _finishWorkout() async {
    await _markWorkoutCompleted(workoutDone: widget.workoutTag);

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: NudePalette.paleBlush,
        title: const Text("Workout Completed! 🎉",
            style: TextStyle(color: NudePalette.darkBrown)),
        content: const Text("You did great! Your progress has been saved.",
            style: TextStyle(color: NudePalette.darkBrown)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, true);
            },
            child: const Text(
              "Close",
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: NudePalette.mauveBrown),
            ),
          ),
        ],
      ),
    );
  }

  void _togglePause() {
    setState(() {
      isPaused = !isPaused;
    });
  }

  void _skip() {
    timer?.cancel();
    _nextStep();
  }

  void _goBack() {
    if (currentIndex > 0) {
      currentIndex--;
      _startTimerForCurrent();
    }
  }

  void _addRestTime() {
    setState(() {
      timerValue += 20;
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.exercises[currentIndex];
    final upcoming = currentIndex + 1 < widget.exercises.length
        ? widget.exercises[currentIndex + 1]
        : null;

    return WillPopScope(
      onWillPop: () async => true,
      child: Scaffold(
        backgroundColor:
            inRest ? const Color(0xFF2F2F2F) : NudePalette.lightCream,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: NudePalette.darkBrown),
            onPressed: () {
              Navigator.pop(context); // 👈 Goes back to WorkoutPopup
            },
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: inRest
              ? _buildRestScreen(upcoming)
              : _buildWorkoutScreen(current),
        ),
      ),
    );
  }

  Widget _buildWorkoutScreen(Map<String, dynamic> current) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(),
        const Icon(Icons.accessibility_new,
            size: 100, color: NudePalette.mauveBrown),
        const SizedBox(height: 20),
        Text(
          current['name'].toString().toUpperCase(),
          style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: NudePalette.darkBrown),
        ),
        const SizedBox(height: 12),
        Text(
          "${timerValue.toString().padLeft(2, '0')} sec",
          style: const TextStyle(
              fontSize: 40, fontWeight: FontWeight.bold, color: Colors.pink),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: _resetTimer,
          child: const Text(
            "RESET",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: NudePalette.mauveBrown,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
                icon: const Icon(Icons.skip_previous,
                    color: NudePalette.darkBrown),
                onPressed: _goBack),
            IconButton(
              icon: Icon(isPaused ? Icons.play_arrow : Icons.pause,
                  color: NudePalette.darkBrown),
              onPressed: _togglePause,
              iconSize: 36,
            ),
            IconButton(
                icon: const Icon(Icons.skip_next, color: NudePalette.darkBrown),
                onPressed: _skip),
          ],
        ),
        const Spacer(),
      ],
    );
  }

  Widget _buildRestScreen(Map<String, dynamic>? upcoming) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("Take a rest",
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        const SizedBox(height: 10),
        Text("$timerValue",
            style: const TextStyle(fontSize: 40, color: Colors.white)),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: NudePalette.softTaupe,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              onPressed: _addRestTime,
              child: const Text(
                "+20s",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: NudePalette.darkBrown,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: NudePalette.roseBlush,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              onPressed: _skip,
              child: const Text(
                "SKIP",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: NudePalette.darkBrown,
                ),
              ),
            ),
          ],
        ),
        if (upcoming != null) ...[
          const SizedBox(height: 30),
          const Text("Next", style: TextStyle(color: Colors.white)),
          Text(
            "${currentIndex + 1}/${widget.exercises.length} ${upcoming['name']} ${upcoming['reps']}",
            style: const TextStyle(fontSize: 16, color: Colors.white),
          ),
        ],
      ],
    );
  }
}
