import 'package:flutter/material.dart';
import 'package:savr/services/firestore_service.dart'; // ✅ Import FirestoreService
import 'diet_screen.dart'; // ✅ Import next screen

class IdealScreen extends StatefulWidget {
  @override
  _IdealScreenState createState() => _IdealScreenState();
}

class _IdealScreenState extends State<IdealScreen> {
  final FirestoreService _firestoreService =
      FirestoreService(); // ✅ Initialize Firestore Service
  final TextEditingController idealWeightController = TextEditingController();
  double? recommendedMinWeight;
  double? recommendedMaxWeight;
  double? userIdealWeight;
  bool showConfirmation = false;
  bool showPaceSelection = false;
  String? selectedPace;
  bool _isLoading = false; // ✅ Loading state

  @override
  void initState() {
    super.initState();
    _fetchHeightAndCalculateRecommendedWeight();
  }

  // ✅ Fetch user's height from Firestore & Calculate Recommended Weight
  Future<void> _fetchHeightAndCalculateRecommendedWeight() async {
    try {
      Map<String, dynamic>? userData = await _firestoreService.getUserData();
      if (userData != null &&
          userData['height'] != null &&
          userData['height'] > 0) {
        double heightMeters = userData['height'] / 100; // Convert cm to meters
        setState(() {
          recommendedMinWeight = 18.5 * (heightMeters * heightMeters);
          recommendedMaxWeight = 24.9 * (heightMeters * heightMeters);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching height: ${e.toString()}")),
      );
    }
  }

  // ✅ Handle when ideal weight is entered
  void _onIdealWeightEntered(String value) {
    if (value.isNotEmpty) {
      setState(() {
        userIdealWeight = double.parse(value);
        showConfirmation = true;
        showPaceSelection = true;
      });
    }
  }

  // ✅ Handle pace selection
  void _selectPace(String pace) {
    setState(() {
      selectedPace = pace;
    });
  }

  // ✅ Save Ideal Weight to Firestore
  Future<void> _saveIdealWeightToFirestore() async {
    if (userIdealWeight == null) return;
    try {
      await _firestoreService.updateUserField('idealWeight', userIdealWeight);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving ideal weight: ${e.toString()}")),
      );
    }
  }

  // ✅ Navigate to next screen
  void _navigateToNext() async {
    if (selectedPace != null) {
      setState(() => _isLoading = true); // ✅ Show loading state
      await _saveIdealWeightToFirestore();
      Navigator.push(
          context, MaterialPageRoute(builder: (context) => DietScreen()));
      setState(() => _isLoading = false); // ✅ Hide loading state
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 50),
            Text(
              "Goal & profile",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            SizedBox(height: 10),
            LinearProgressIndicator(
              value: 0.6,
              backgroundColor: Colors.grey[300],
              color: Colors.orange,
            ),
            SizedBox(height: 30),

            // ✅ Title Text
            Text(
              "What is your ideal weight?",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),

            // ✅ Recommended Weight Hint
            if (recommendedMinWeight != null && recommendedMaxWeight != null)
              Row(
                children: [
                  Icon(Icons.lightbulb, color: Colors.orange, size: 18),
                  SizedBox(width: 5),
                  Text(
                    "Recommended: ${recommendedMinWeight!.toStringAsFixed(1)} - ${recommendedMaxWeight!.toStringAsFixed(1)} kg",
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            SizedBox(height: 10),

            // ✅ Ideal Weight Input Field
            TextField(
              controller: idealWeightController,
              keyboardType: TextInputType.number,
              onChanged: _onIdealWeightEntered,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey.shade100,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                suffixIcon: Padding(
                  padding: EdgeInsets.only(right: 10),
                  child: Text("kg",
                      style: TextStyle(fontSize: 16, color: Colors.orange)),
                ),
              ),
            ),
            SizedBox(height: 20),

            // ✅ Confirmation Message
            if (showConfirmation)
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 5),
                  Text("Great! Thanks for sharing.",
                      style: TextStyle(color: Colors.green, fontSize: 16)),
                ],
              ),
            SizedBox(height: 20),

            // ✅ Goal Pace Selection
            if (showPaceSelection) ...[
              Text("What pace do you want to achieve your goal?",
                  style: TextStyle(fontSize: 18)),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildPaceOption("Slowly but surely", Icons.directions_walk),
                  _buildPaceOption("In the middle", Icons.directions_bike),
                  _buildPaceOption("As fast as possible", Icons.rocket),
                ],
              ),
              SizedBox(height: 30),
            ],

            // ✅ "Next" Button
            if (selectedPace != null)
              Center(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _navigateToNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                  ),
                  child: _isLoading
                      ? CircularProgressIndicator(
                          color: Colors.white) // ✅ Show loader
                      : Text("Next", style: TextStyle(color: Colors.white)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaceOption(String text, IconData icon) {
    return GestureDetector(
      onTap: () => _selectPace(text),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: selectedPace == text
                  ? Colors.orange.shade100
                  : Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 30, color: Colors.orange),
          ),
          SizedBox(width: 5),
          Text(text, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
