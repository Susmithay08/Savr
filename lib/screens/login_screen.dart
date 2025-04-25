import 'package:flutter/material.dart';
import 'create_screen.dart';
import 'package:savr/services/firebase_auth_service.dart';
import 'package:savr/services/firestore_service.dart';
import 'home_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:savr/providers/theme_provider.dart'; // ✅ Make sure this path is correct

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  // Email Login
  Future<void> _signInWithEmail() async {
    try {
      setState(() => _isLoading = true);
      final user = await _authService.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (user != null) {
        // ✅ Load user's font size from Firestore
        final themeProvider =
            Provider.of<ThemeProvider>(context, listen: false);
        await themeProvider.loadPreferences();

        // ✅ Then navigate
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomeScreen()),
        );
      }
    } catch (e) {
      _showError("Invalid email or password. Try again.");
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
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Welcome back!",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text("Log in to access your SAVR account"),
            SizedBox(height: 30),

            // Email Input
            TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: "Email"),
              keyboardType: TextInputType.emailAddress,
            ),
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

            SizedBox(height: 10),

// Forgot Password
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  final email = _emailController.text.trim();
                  if (email.isEmpty) {
                    _showError("Enter your email to reset password.");
                  } else {
                    FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text("Password reset link sent to $email")),
                    );
                  }
                },
                child: Text("Forgot Password?"),
              ),
            ),

// Email Login Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                minimumSize: Size(double.infinity, 50),
              ),
              onPressed: _isLoading ? null : _signInWithEmail,
              child: _isLoading
                  ? CircularProgressIndicator()
                  : Text("Continue with Email",
                      style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
            SizedBox(height: 20),

            // Navigate to Sign-Up
            TextButton(
              onPressed: () {
                Navigator.push(
                    context, MaterialPageRoute(builder: (_) => CreateScreen()));
              },
              child: Text("Don't have an account? Create one here."),
            ),
          ],
        ),
      ),
    );
  }
}
