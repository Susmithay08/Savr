import 'package:flutter/material.dart';
import 'package:savr/services/firestore_service.dart';
import 'package:savr/services/firebase_auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'privacy_screen.dart';
import 'login_screen.dart'; // 👈 Add this line if not already imported

class CreateScreen extends StatefulWidget {
  @override
  _CreateScreenState createState() => _CreateScreenState();
}

class _CreateScreenState extends State<CreateScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  // Email Sign-Up
  Future<void> _onEmailSignUp() async {
    try {
      setState(() => _isLoading = true);
      final User? user = await _authService.registerWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (user != null) {
        await _firestoreService.saveUserData({
          'displayName': '',
          'email': _emailController.text.trim(),
          'age': 0,
          'height': 0,
          'weight': 0,
          'idealWeight': 0,
          'goal': '',
          'medicalConditions': [],
          'allergies': [],
          'createdAt': DateTime.now(),
        });

        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => PrivacyScreen()));
      }
    } catch (e) {
      _showError("Failed to create account: ${e.toString()}");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 80),
              Image.asset("assets/create.png", height: 150),
              SizedBox(height: 20),
              Text("Create your account",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              SizedBox(height: 30),
              TextField(
                  controller: _emailController,
                  decoration: InputDecoration(labelText: "Email")),
              SizedBox(height: 10),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: "Password",
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword
                        ? Icons.visibility
                        : Icons.visibility_off),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                obscureText: _obscurePassword,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  minimumSize: Size(double.infinity, 50),
                ),
                onPressed: _isLoading ? null : _onEmailSignUp,
                child: _isLoading
                    ? CircularProgressIndicator()
                    : Text("Sign Up with Email",
                        style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
              SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => LoginScreen()),
                  );
                },
                child: RichText(
                  text: TextSpan(
                    text: "Already have an account? ",
                    style: TextStyle(color: Colors.black),
                    children: [
                      TextSpan(
                        text: "Login here",
                        style: TextStyle(
                          color: Colors.blueAccent,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
