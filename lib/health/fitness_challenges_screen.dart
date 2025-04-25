import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'challenge_progress_popup.dart';
import 'package:savr/themes/colors.dart';

class FitnessChallengesScreen extends StatefulWidget {
  const FitnessChallengesScreen({super.key});

  @override
  State<FitnessChallengesScreen> createState() =>
      _FitnessChallengesScreenState();
}

class _FitnessChallengesScreenState extends State<FitnessChallengesScreen> {
  Map<String, dynamic> challengeData = {};

  @override
  void initState() {
    super.initState();
    _loadChallengeData();
  }

  Future<void> _loadChallengeData() async {
    final String response =
        await rootBundle.loadString('assets/fitness_challenges.json');
    final data = json.decode(response);
    setState(() {
      challengeData = data['challenges'] ?? {};
    });
  }

  Widget _buildChallengeCard(BuildContext context, String id, String title,
      String subtitle, String duration) {
    return GestureDetector(
      onTap: () {
        final challenge = challengeData[id];
        if (challenge != null && challenge['workouts'] != null) {
          final workouts =
              List<Map<String, dynamic>>.from(challenge['workouts']);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChallengeProgressPopup(
                challengeId: id,
                workouts: workouts,
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Workout not found for $title")),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        width: double.infinity,
        decoration: BoxDecoration(
          color: NudePalette.paleBlush,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: NudePalette.darkBrown,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style:
                  const TextStyle(fontSize: 14, color: NudePalette.darkBrown),
            ),
            const SizedBox(height: 4),
            Text(
              duration,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  final List<Map<String, String>> challengesList = [
    {
      'id': 'full_body_challenge',
      'title': 'Full Body Challenge',
      'description': 'Engage your entire body each day',
      'duration': '30 days'
    },
    {
      'id': 'flat_stomach',
      'title': 'Flat Stomach',
      'description': 'Target belly fat with daily workouts',
      'duration': '30 days'
    },
    {
      'id': 'round_glutes',
      'title': 'Round Glutes',
      'description': 'Lift and tone your glutes',
      'duration': '30 days'
    },
    {
      'id': 'thigh_workout',
      'title': 'Thigh Workout',
      'description': 'Sculpt your thighs and inner legs',
      'duration': '30 days'
    },
    {
      'id': 'toned_arms',
      'title': 'Toned Arms',
      'description': 'Strengthen and shape your arms',
      'duration': '30 days'
    },
    {
      'id': 'breast_lift',
      'title': '28 Days Breast Lift',
      'description': 'Natural upper body lift program',
      'duration': '28 days'
    },
    {
      'id': 'walking_28_days',
      'title': '28 Days Walking',
      'description': 'Daily walks for full-body wellness',
      'duration': '28 days'
    },
    {
      'id': 'lose_weight_30',
      'title': 'Lose Weight in 30 Days',
      'description': 'Total body transformation routine',
      'duration': '30 days'
    }
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NudePalette.lightCream,
      appBar: AppBar(
        title: const Text("Fitness Challenges",
            style: TextStyle(color: NudePalette.darkBrown)),
        backgroundColor: NudePalette.lightCream,
        elevation: 0,
        foregroundColor: NudePalette.darkBrown,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: challengeData.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                children: challengesList
                    .map((challenge) => _buildChallengeCard(
                          context,
                          challenge['id']!,
                          challenge['title']!,
                          challenge['description']!,
                          challenge['duration']!,
                        ))
                    .toList(),
              ),
      ),
    );
  }
}
