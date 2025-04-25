import 'package:flutter/material.dart';

final ThemeData nudeTheme = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: Color(0xFFF1EDE6), // App background
  primaryColor: Color(0xFF3A2D28), // Dark Brown
  canvasColor: Color(0xFFF1EDE6),
  cardColor: Color(0xFFD1C7BD), // Card background

  colorScheme: ColorScheme.light(
    primary: Color(0xFF3A2D28),
    secondary: Color(0xFFA48374), // Accent
    surface: Color(0xFFEBE3DB),
    background: Color(0xFFF1EDE6),
  ),

  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: Color(0xFFA48374), // Button
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  ),

  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Color(0xFFEBE3DB), // Input field background
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide.none,
    ),
  ),

  appBarTheme: AppBarTheme(
    backgroundColor: Color(0xFFF1EDE6),
    iconTheme: IconThemeData(color: Color(0xFF3A2D28)),
    titleTextStyle: TextStyle(
      color: Color(0xFF3A2D28),
      fontSize: 20,
      fontWeight: FontWeight.w300,
    ),
  ),

  textTheme: TextTheme(
    bodyMedium: TextStyle(color: Color(0xFF3A2D28)),
    titleLarge: TextStyle(color: Color(0xFF3A2D28)),
  ),
);
