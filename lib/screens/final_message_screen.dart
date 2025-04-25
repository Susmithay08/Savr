import 'package:flutter/material.dart';
import 'details_screen.dart'; // ✅ Import next screen

class FinalMessageScreen extends StatelessWidget {
  final String userName;
  final String goal;

  FinalMessageScreen(
      {required this.userName, required this.goal}); // ✅ Require parameters

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/avocado_character.png', width: 300),
            SizedBox(height: 20),
            Text(
              "You are in the right place, $userName!",
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 10),
            Text(
                "We need some basic information to start customizing your plan.",
                textAlign: TextAlign.center),
            SizedBox(height: 20),

            // ✅ Navigate to DetailsScreen, passing name & goal
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DetailsScreen(
                      userName: userName,
                      goal: goal,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
              ),
              child: Text("Next", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
