import 'package:flutter/material.dart';
import 'name_input_screen.dart';

class OnboardingScreen extends StatefulWidget {
  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentIndex = 0;

  final List<Map<String, String>> _slides = [
    {
      "image": "assets/onboarding1.png",
      "text": "Congrats on taking the first step!"
    },
    {
      "image": "assets/onboarding2.png",
      "text": "You are unique, so is our program."
    },
  ];

  void _nextSlide() {
    if (_currentIndex < _slides.length - 1) {
      setState(() {
        _currentIndex++;
      });
    } else {
      // ✅ Navigate to Name Input Screen after the last onboarding slide
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => NameInputScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(_slides[_currentIndex]["image"]!, width: 330),
          SizedBox(height: 20),
          Text(_slides[_currentIndex]["text"]!, style: TextStyle(fontSize: 22)),
          SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _slides.length,
              (index) => Container(
                margin: EdgeInsets.symmetric(horizontal: 5),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: index == _currentIndex
                      ? Colors.black
                      : Colors.grey.shade300,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          SizedBox(height: 30),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
            onPressed: _nextSlide,
            child: Icon(Icons.arrow_forward, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
