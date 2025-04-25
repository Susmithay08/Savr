import 'package:flutter/material.dart';
import 'home_screen.dart';

class ProcessingScreen extends StatefulWidget {
  @override
  _ProcessingScreenState createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 3), // ✅ Progress completes in 3 seconds
    )..forward();

    Future.delayed(Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (context) => HomeScreen()), // ✅ Goes to HomeScreen
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/info.png', width: 300), // ✅ Show info image
            SizedBox(height: 20),
            Text(
              "Sit right back, we got all your information!",
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 10),
            Text(
              "We're processing everything for you. Hang tight!",
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 30),

            // **Orange Progress Bar**
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return LinearProgressIndicator(
                  value: _controller.value, // ✅ Moves right dynamically
                  backgroundColor: Colors.grey[300], // Light background
                  color: Colors.orange, // ✅ Orange progress bar
                  minHeight: 6, // Thin line
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
