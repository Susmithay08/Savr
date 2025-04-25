import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'kitchen_screen.dart';
import 'package:savr/screens/home_screen.dart';
import 'package:flutter/services.dart';
import 'package:savr/themes/colors.dart';

class FreestyleScreen extends StatefulWidget {
  @override
  _FreestyleScreenState createState() => _FreestyleScreenState();
}

class _FreestyleScreenState extends State<FreestyleScreen> {
  static const String apiKey = "AIzaSyC8RV1M4_yLHiOnBudsYehJrBXJs09jysg";
  static const String apiUrl =
      "https://generativelanguage.googleapis.com/v1/models/gemini-1.5-pro:generateContent?key=$apiKey";

  String selectedMealType = "Breakfast";
  String selectedDietOption = "None";
  String selectedNutritionalPreference = "None";
  TextEditingController allergyController = TextEditingController();
  final TextEditingController caloriesController = TextEditingController();
  final TextEditingController mainIngredientController =
      TextEditingController();
  final TextEditingController cuisineController = TextEditingController();
  final TextEditingController timeToPrepareController = TextEditingController();

  String? recipeTitle;
  String? recipeDetails;
  bool isLoading = false;
  Map<String, bool> expandedState = {};
  List<String> missingIngredients = [];

  int _selectedIndex = 1;

  final List<Map<String, dynamic>> allDiets = [
    {"label": "None", "icon": Icons.cancel},
    {"label": "Vegan", "icon": Icons.spa},
    {"label": "Classic", "icon": Icons.food_bank},
    {"label": "Vegetarian", "icon": Icons.emoji_nature},
    {"label": "Pescetarian", "icon": Icons.set_meal},
    {"label": "Flexitarian", "icon": Icons.eco},
    {"label": "Mediterranean", "icon": Icons.local_dining},
    {"label": "Keto", "icon": Icons.restaurant},
    {"label": "Paleo", "icon": Icons.eco},
    {"label": "Atkins", "icon": Icons.no_food},
    {"label": "Dash", "icon": Icons.fitness_center},
    {"label": "Whole30", "icon": Icons.health_and_safety},
    {"label": "Hindu", "icon": Icons.temple_hindu},
  ];

  final List<String> nutritionalPreferences = [
    "None",
    "Low Carb",
    "Low Sugar",
    "Low Cholesterol",
    "Gluten-Free",
    "Low Sodium",
  ];

  Future<void> _fetchRecipe() async {
    setState(() {
      isLoading = true;
      recipeTitle = null;
      recipeDetails = null;
      missingIngredients = [];
    });

    final allergyText = allergyController.text;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // ✅ Fetch pantry items (all lowercase for better comparison)
    List<String> pantryItems = [];
    final pantrySnapshot = await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .collection("pantryItems")
        .get();

    for (var doc in pantrySnapshot.docs) {
      pantryItems.add(doc["name"].toString().toLowerCase().trim());
    }

    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "contents": [
          {
            "parts": [
              {
                "text": "you dont have to use this items ${pantryItems.join(', ')}\n"
                    "Generate a $selectedMealType recipe following the $selectedDietOption diet and "
                    "$selectedNutritionalPreference nutritional preference.\n"
                    "${allergyText.isNotEmpty ? "Avoid ingredients containing: $allergyText.\n" : ""}"
                    "${caloriesController.text.isNotEmpty ? "Limit calories to ${caloriesController.text}.\n" : ""}"
                    "${mainIngredientController.text.isNotEmpty ? "Prefer using ${mainIngredientController.text} as the main ingredient.\n" : ""}"
                    "${cuisineController.text.isNotEmpty ? "Cuisine type should be ${cuisineController.text}.\n" : ""}"
                    "${timeToPrepareController.text.isNotEmpty ? "The meal should take about ${timeToPrepareController.text} to prepare.\n" : ""}"
                    "You're allowed to include additional ingredients if needed to complete the recipe.\n\n"
                    "Provide a detailed recipe including:\n"
                    "- Recipe Name\n"
                    "- Ingredients (as a list, without measurements)\n"
                    "- Step-by-step cooking instructions with measurements\n"
                    "- Nutritional details\n\n"
                    "Format:\n"
                    "Recipe Name: [name]\n"
                    "Ingredients:\n - [ingredient1]\n - [ingredient2]\n"
                    "Instructions:\n 1. [Step 1]\n 2. [Step 2]\n"
                    "Nutritional Details:\n [Details]"
              }
            ]
          }
        ]
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      String content = data["candidates"][0]["content"]["parts"][0]["text"];

      // ✅ Remove unwanted symbols (*, #, -)
      content = content
          .replaceAll(RegExp(r'[*#_\-]'), '')
          .replaceAll('**', '')
          .trim();

      // ✅ Extract recipe name
      final titleMatch = RegExp(r"Recipe Name:\s*(.+)").firstMatch(content);
      String? extractedTitle =
          titleMatch != null ? titleMatch.group(1)?.trim() : "Unknown Recipe";

      // ✅ Extract instructions (from "Instructions:" onwards)
      final instructionsMatch =
          RegExp(r"Instructions:\s*(.+)", dotAll: true).firstMatch(content);
      String? extractedInstructions = instructionsMatch != null
          ? instructionsMatch.group(1)?.trim()
          : "No instructions provided.";

      // ✅ Extract only ingredient names
      final ingredientMatch =
          RegExp(r"Ingredients:\s*(.+?)\n\n", dotAll: true).firstMatch(content);
      List<String> aiIngredients = [];
      if (ingredientMatch != null && ingredientMatch.group(1) != null) {
        aiIngredients = ingredientMatch
            .group(1)!
            .split('\n')
            .map((item) => item
                .replaceAll(RegExp(r'[-]'), '')
                .trim()
                .toLowerCase()) // Remove bullet points
            .map((ingredient) {
              // ✅ Remove measurement words like "1 cup", "a spoon of"
              return ingredient
                  .replaceAll(
                      RegExp(
                          r'\b(a|an|the|one|two|three|half|tbsp|tsp|cup|oz|grams|kg|ml|l|clove|slice|dash|pinch)\b',
                          caseSensitive: false),
                      "")
                  .trim();
            })
            .where((item) => item.isNotEmpty)
            .toList();
      }

      // ✅ Improved Pantry Comparison (handles "whole chicken" vs "chicken")
      List<String> missing = aiIngredients.where((ingredient) {
        return !pantryItems.any((pantryItem) =>
            pantryItem.contains(ingredient) || ingredient.contains(pantryItem));
      }).toList();

      setState(() {
        recipeTitle = extractedTitle;
        recipeDetails = recipeDetails =
            "$extractedTitle\n\nIngredients:\n${aiIngredients.join("\n")}\n\nInstructions:\n$extractedInstructions";
        missingIngredients = missing.isNotEmpty ? missing : ["None"];
        isLoading = false;
      });
    } else {
      setState(() {
        recipeTitle = "Error fetching recipe";
        recipeDetails = "API Error: ${response.body}";
        isLoading = false;
      });
    }
  }

  /// Popup to handle missing ingredients.
  void _showMissingIngredientsPopup() async {
    bool add = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Missing Ingredients"),
        content: Text(missingIngredients.join(", ")),
        actions: [
          TextButton(
            child: Text("Cancel"),
            onPressed: () => Navigator.pop(context, false),
          ),
          ElevatedButton(
            child: Text("Add to Grocery"),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (add) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      for (var item in missingIngredients) {
        await FirebaseFirestore.instance
            .collection("users")
            .doc(user.uid)
            .collection("groceryItems")
            .add({'name': item, 'quantity': '1'});
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Items added to Grocery List")),
      );
    }
  }

  /// Saves the recipe in the Secret Recipe Vault.
  Future<void> _saveRecipe() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || recipeTitle == null) return;

    try {
      final userDoc =
          FirebaseFirestore.instance.collection("users").doc(user.uid);
      final recipeRef = userDoc.collection("secretRecipeVault").doc();

      List<String> categories = [selectedMealType];
      if (selectedDietOption != "None") categories.add(selectedDietOption);
      if (selectedNutritionalPreference != "None")
        categories.add(selectedNutritionalPreference);

      await recipeRef.set({
        'recipeId': recipeRef.id,
        'mealType': selectedMealType,
        'dietOption': selectedDietOption,
        'nutritionPreference': selectedNutritionalPreference,
        'recipeTitle': recipeTitle,
        'recipeDetails': recipeDetails,
        'categories': categories,
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Recipe saved to Secret Recipe Vault!")),
      );
    } catch (e) {
      print("Error saving recipe: $e");
    }
  }

  /// Handles bottom navigation taps.
  void _onBottomNavTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomeScreen()),
        );
        break;
      case 1:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const KitchenScreen()),
        );
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/medicines');
        break;
      case 3:
        Navigator.pushReplacementNamed(context, '/health');
        break;
      case 4:
        Navigator.pushReplacementNamed(context, '/feed');
        break;
    }
  }

  /// Builds horizontal scrollable chips for selection.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NudePalette.lightCream,
      appBar: AppBar(
        backgroundColor: NudePalette.lightCream,
        elevation: 0,
        iconTheme: IconThemeData(color: NudePalette.darkBrown),
        title: const Text(
          'Freestyle Feast',
          style: TextStyle(
            color: NudePalette.darkBrown,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                value: selectedMealType,
                onChanged: (value) => setState(() => selectedMealType = value!),
                decoration: InputDecoration(
                  labelText: "Meal Type",
                  labelStyle: const TextStyle(color: NudePalette.darkBrown),
                  filled: true,
                  fillColor: NudePalette.paleBlush,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: NudePalette.mauveBrown,
                      width: 2,
                    ),
                  ),
                ),
                items: ["Breakfast", "Lunch", "Snack", "Dinner"]
                    .map((item) =>
                        DropdownMenuItem(value: item, child: Text(item)))
                    .toList(),
              ),
              SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: selectedDietOption,
                onChanged: (value) =>
                    setState(() => selectedDietOption = value!),
                decoration: InputDecoration(
                  labelText: "Diet Type",
                  labelStyle: const TextStyle(color: NudePalette.darkBrown),
                  filled: true,
                  fillColor: NudePalette.paleBlush,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: NudePalette.mauveBrown,
                      width: 2,
                    ),
                  ),
                ),
                items: allDiets
                    .map((diet) => DropdownMenuItem<String>(
                          value: diet["label"] as String,
                          child: Text(diet["label"] as String),
                        ))
                    .toList(),
              ),
              SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: selectedNutritionalPreference,
                onChanged: (value) =>
                    setState(() => selectedNutritionalPreference = value!),
                decoration: InputDecoration(
                  labelText: "Nutrition Preference",
                  labelStyle: const TextStyle(color: NudePalette.darkBrown),
                  filled: true,
                  fillColor: NudePalette.paleBlush,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: NudePalette.mauveBrown,
                      width: 2,
                    ),
                  ),
                ),
                items: nutritionalPreferences
                    .map((pref) => DropdownMenuItem(
                          value: pref,
                          child: Text(pref),
                        ))
                    .toList(),
              ),
              SizedBox(height: 15),
              TextField(
                controller: allergyController,
                decoration: InputDecoration(
                  labelText: "Allergies (optional)",
                  labelStyle: const TextStyle(color: NudePalette.darkBrown),
                  filled: true,
                  fillColor: NudePalette.paleBlush,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: NudePalette.mauveBrown,
                      width: 2,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20),
              SizedBox(height: 15),
              Text(
                "Additional Preferences:",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: NudePalette.darkBrown,
                ),
              ),
              SizedBox(height: 10),
              TextField(
                controller: caloriesController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Calories",
                  labelStyle: const TextStyle(color: NudePalette.darkBrown),
                  filled: true,
                  fillColor: NudePalette.paleBlush,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: NudePalette.mauveBrown,
                      width: 2,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 10),
              TextField(
                controller: mainIngredientController,
                decoration: InputDecoration(
                  labelText: "Main Ingredient",
                  labelStyle: const TextStyle(color: NudePalette.darkBrown),
                  filled: true,
                  fillColor: NudePalette.paleBlush,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: NudePalette.mauveBrown,
                      width: 2,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 10),
              TextField(
                controller: cuisineController,
                decoration: InputDecoration(
                  labelText: "Cuisine Type",
                  labelStyle: const TextStyle(color: NudePalette.darkBrown),
                  filled: true,
                  fillColor: NudePalette.paleBlush,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: NudePalette.mauveBrown,
                      width: 2,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 10),
              TextField(
                controller: timeToPrepareController,
                decoration: InputDecoration(
                  labelText: "Time to Prepare",
                  labelStyle: const TextStyle(color: NudePalette.darkBrown),
                  filled: true,
                  fillColor: NudePalette.paleBlush,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: NudePalette.mauveBrown,
                      width: 2,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: _fetchRecipe,
                    icon: Icon(Icons.fastfood),
                    label: Text(
                      "Get Meal",
                      style: TextStyle(color: Colors.black),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: NudePalette.mauveBrown,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _saveRecipe,
                    icon: Icon(Icons.bookmark),
                    label: Text(
                      "Save Recipe",
                      style: TextStyle(color: Colors.black),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: NudePalette.mauveBrown,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              Column(
                children: [
                  if (isLoading)
                    Center(
                      child: Text(
                        "Hold tight! Summoning the best chef-approved meal for you... 🍽️",
                        style: TextStyle(
                            fontStyle: FontStyle.italic, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  if (recipeTitle != null)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          String recipeKey = recipeTitle ?? "Generated Meal";
                          expandedState[recipeKey] =
                              !(expandedState[recipeKey] ?? false);
                        });
                      },
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: NudePalette
                              .paleBlush, // ✅ matches Pantry & Recipe screen

                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 5,
                              spreadRadius: 1,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              recipeTitle ?? "Generated Meal",
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            AnimatedCrossFade(
                              firstChild: SizedBox.shrink(),
                              secondChild: SelectableText(recipeDetails ?? ""),
                              crossFadeState: (expandedState[
                                          recipeTitle ?? "Generated Meal"] ??
                                      false)
                                  ? CrossFadeState.showSecond
                                  : CrossFadeState.showFirst,
                              duration: Duration(milliseconds: 300),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // ✅ Missing Ingredients card here!
                  if (missingIngredients.isNotEmpty)
                    GestureDetector(
                      onTap: _showMissingIngredientsPopup,
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(12),
                        margin: EdgeInsets.only(top: 12),
                        decoration: BoxDecoration(
                          color: NudePalette.roseBlush, // If you define it

                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.redAccent.withOpacity(0.2),
                              blurRadius: 5,
                              spreadRadius: 1,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Text(
                          "Missing Ingredients: Click to view",
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: NudePalette.darkBrown,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(color: Colors.black38, blurRadius: 10, spreadRadius: 2),
          ],
        ),
        margin: const EdgeInsets.all(15),
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          selectedItemColor: NudePalette.lightCream,
          unselectedItemColor: NudePalette.lightCream.withOpacity(0.6),
          currentIndex: _selectedIndex,
          onTap: _onBottomNavTapped,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: "Home",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.kitchen),
              label: "Kitchen",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.medical_services),
              label: "Medicines",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.favorite),
              label: "Health",
            ),
            // BottomNavigationBarItem(
            //  icon: Icon(Icons.rss_feed),
            //  label: "Feed",
            //),
          ],
        ),
      ),
    );
  }
}
