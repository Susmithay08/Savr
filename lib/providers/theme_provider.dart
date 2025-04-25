import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  double _fontSize = 16.0;

  double get fontSize => _fontSize;

  ThemeProvider() {
    loadPreferences();
  }

  Future<void> loadPreferences() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      _fontSize = prefs.getDouble('fontSize') ?? 16.0;

      // 🔐 Load font size from Firestore (user-specific)
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          _fontSize = (userDoc.data()?.containsKey('fontSize') ?? false)
              ? (userDoc['fontSize'] as num).toDouble()
              : 16.0;
        }
      }
      notifyListeners();
    } catch (e) {
      print("Failed to load preferences: $e");
    }
  }

  Future<void> setFontSize(double newSize) async {
    _fontSize = newSize;
    notifyListeners();

    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setDouble('fontSize', _fontSize);

    // 🔐 Save to Firestore if user is logged in
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'fontSize': _fontSize,
      });
    }
  }
}
