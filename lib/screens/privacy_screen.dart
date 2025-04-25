import 'package:flutter/material.dart';
import 'onboarding_screen.dart'; // ✅ Navigates to OnboardingScreen
import 'terms_conditions_screen.dart';
import 'privacy_policy_screen.dart';

class PrivacyScreen extends StatefulWidget {
  @override
  _PrivacyScreenState createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  bool _isChecked = false;

  void _onNext() {
    if (_isChecked) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => OnboardingScreen()), // ✅ Goes to Onboarding
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please accept the terms to continue")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F5DC), // Light yellow background
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 60),

              // **Privacy Image**
              Image.asset(
                "assets/privacy.png",
                height: 150,
              ),
              SizedBox(height: 20),

              // **Title**
              Text(
                "Your privacy matters",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),

              // **Privacy Points**
              _buildPrivacyPoint(Icons.food_bank,
                  "Your personal data is only used to give you personalized nutritional advice"),
              _buildPrivacyPoint(Icons.lock,
                  "We do not share your personal data with third parties"),
              _buildPrivacyPoint(
                  Icons.visibility_off, "Your data stays between you and us"),
              SizedBox(height: 15),

              // **Links for Terms & Conditions + Privacy Policy**
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => TermsConditionsScreen()),
                      );
                    },
                    // ✅ Navigate to Terms & Conditions
                    child: Text(
                      "Terms & conditions",
                      style: TextStyle(
                          color: Colors.blue,
                          decoration: TextDecoration.underline),
                    ),
                  ),
                  Text("  ·  "), // Separator
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => PrivacyPolicyScreen()),
                      );
                    },
                    // ✅ Navigate to Privacy Policy
                    child: Text(
                      "Privacy policy",
                      style: TextStyle(
                          color: Colors.blue,
                          decoration: TextDecoration.underline),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 15),

              // **Checkbox for Acceptance**
              Row(
                children: [
                  Checkbox(
                    value: _isChecked,
                    onChanged: (value) {
                      setState(() {
                        _isChecked = value!;
                      });
                    },
                  ),
                  Expanded(
                    child: Text(
                        "I have read and accepted the terms and conditions and the privacy policy"),
                  ),
                ],
              ),
              SizedBox(height: 30),

              // **Next Button**
              ElevatedButton(
                onPressed: _onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue, // Button color
                  minimumSize: Size(double.infinity, 50), // Full width
                ),
                child: Text("Next",
                    style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // **Reusable Widget for Privacy Points**
  Widget _buildPrivacyPoint(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, color: Colors.black54, size: 24),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
