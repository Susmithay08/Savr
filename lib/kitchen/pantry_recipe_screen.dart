import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'kitchen_screen.dart';
import 'package:savr/screens/home_screen.dart';
import 'package:flutter/services.dart';
import 'package:savr/themes/colors.dart';

class PantryRecipeScreen extends StatefulWidget {
  @override
  _PantryRecipeScreenState createState() => _PantryRecipeScreenState();
}

class _PantryRecipeScreenState extends State<PantryRecipeScreen> {
  static const String apiKey = "AIzaSyC8RV1M4_yLHiOnBudsYehJrBXJs09jysg";
  static const String apiUrl =
      "https://generativelanguage.googleapis.com/v1/models/gemini-1.5-pro:generateContent?key=$apiKey";
  String selectedMealType = "Breakfast";
  String selectedDietOption = "None";
  String selectedNutritionalPreference = "None";
  List<String> allergies = [];

  String? recipeTitle;
  String? recipeDetails;
  bool isLoading = false;
  Map<String, bool> expandedState = {}; // Track expansion per recipe

  int _selectedIndex = 1;

  List<String> allergyOptions = [
    "Peanuts",
    "Dairy",
    "Shellfish",
    "Soy",
    "Gluten",
    "Eggs",
    "Tree Nuts"
  ];
  final TextEditingController caloriesController = TextEditingController();
  final TextEditingController mainIngredientController =
      TextEditingController();
  final TextEditingController cuisineController = TextEditingController();
  final TextEditingController timeToPrepareController = TextEditingController();

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

  final List<Map<String, dynamic>> nutritionPreferences = [
    {"label": "None", "icon": Icons.cancel},
    {"label": "Gluten Free", "icon": Icons.grain},
    {"label": "Low Carb", "icon": Icons.balance},
    {"label": "Low Sugar", "icon": Icons.icecream},
    {"label": "Lactose Free", "icon": Icons.local_cafe},
    {"label": "Low Cholesterol", "icon": Icons.monitor_heart},
    {"label": "Organic", "icon": Icons.eco},
    {"label": "Low Fat", "icon": Icons.local_pizza},
    {"label": "High Protein", "icon": Icons.fitness_center},
    {"label": "Dairy Free", "icon": Icons.emoji_food_beverage},
  ];

  /// Fetches pantry items from Firestore.
  Future<List<String>> fetchPantryItems() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .collection("pantryItems")
          .get();

      return snapshot.docs.map((doc) => doc['name'] as String).toList();
    } catch (e) {
      print("Error fetching pantry items: $e");
      return [];
    }
  }

  /// Calls AI to generate a recipe based on pantry items.
  Future<void> _fetchRecipe() async {
    setState(() {
      isLoading = true;
      recipeTitle = null;
      recipeDetails = null;
    });

    List<String> pantryItems = await fetchPantryItems();
    if (pantryItems.isEmpty) {
      setState(() {
        recipeTitle = "No pantry items found!";
        recipeDetails =
            "Please add items to your pantry before generating a recipe.";
        isLoading = false;
      });
      return;
    }

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {
                  "text": "ONLY use these pantry ingredients to generate a $selectedMealType recipe: ${pantryItems.join(', ')}. "
                      "I follow a $selectedDietOption diet and prefer $selectedNutritionalPreference nutrition. "
                      "I am allergic to: ${allergies.isEmpty ? "None" : allergies.join(', ')}. "
                      "${caloriesController.text.isNotEmpty ? "Limit calories to ${caloriesController.text}. " : ""}"
                      "${mainIngredientController.text.isNotEmpty ? "Use ${mainIngredientController.text} as main ingredient. " : ""}"
                      "${cuisineController.text.isNotEmpty ? "Cuisine type should be ${cuisineController.text}. " : ""}"
                      "${timeToPrepareController.text.isNotEmpty ? "It should take around ${timeToPrepareController.text} to prepare. " : ""}"
                      "DO NOT ask for more ingredients or information. JUST provide ONE detailed recipe with: recipe title, ingredients, nutritional info, and step-by-step instructions."
                }
              ]
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data.containsKey("candidates") && data["candidates"].isNotEmpty) {
          final content = data["candidates"][0]["content"]["parts"];
          if (content.isNotEmpty && content[0].containsKey("text")) {
            setState(() {
              String rawText = content[0]["text"];

              // Remove asterisks (*)
              rawText = rawText.replaceAll("*", "");

              // Remove unnecessary intro text
              rawText = rawText
                  .replaceAll(RegExp(r'Since your pantry.*?Enjoy!'), '')
                  .trim();

              recipeTitle =
                  rawText.split("\n")[0]; // Extract the first line as title
              recipeDetails = rawText; // Store cleaned recipe details
              isLoading = false;
            });

            return;
          }
        }

        // If response structure is unexpected
        setState(() {
          recipeTitle = "Error fetching recipe";
          recipeDetails = "Invalid API response structure.";
          isLoading = false;
        });
      } else {
        setState(() {
          recipeTitle = "Error fetching recipe";
          recipeDetails = "API Error: ${response.body}";
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        recipeTitle = "Error";
        recipeDetails = "Something went wrong: $e";
        isLoading = false;
      });
    }
  }

  /// Saves the recipe in the Secret Recipe Vault under multiple categories
  Future<void> _saveRecipe() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || recipeTitle == null) return;

    try {
      final userDoc =
          FirebaseFirestore.instance.collection("users").doc(user.uid);
      final recipeRef = userDoc.collection("secretRecipeVault").doc();

      // Collect categories
      List<String> categories = [selectedMealType];
      if (selectedDietOption != "None") categories.add(selectedDietOption);
      if (selectedNutritionalPreference != "None")
        categories.add(selectedNutritionalPreference);

      // Save recipe under multiple categories
      await recipeRef.set({
        'recipeId': recipeRef.id,
        'mealType': selectedMealType,
        'dietOption': selectedDietOption,
        'nutritionPreference': selectedNutritionalPreference,
        'recipeTitle': recipeTitle,
        'recipeDetails': recipeDetails,
        'categories': categories, // 🔥 Stores all categories as a list
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Recipe saved to Secret Recipe Vault!")),
      );
    } catch (e) {
      print("Error saving recipe: $e");
    }
  }

  void _onBottomNavTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/home');
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/kitchen');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: NudePalette.lightCream,
        elevation: 0,
        title: const Text(
          "Pantry Magic",
          style: TextStyle(
            color: NudePalette.darkBrown,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: NudePalette.darkBrown),
      ),

      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Meal Type Selection
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
                        color: NudePalette.mauveBrown, width: 2),
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
                        color: NudePalette.mauveBrown, width: 2),
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
                        color: NudePalette.mauveBrown, width: 2),
                  ),
                ),
                items: nutritionPreferences
                    .map((pref) => DropdownMenuItem<String>(
                          value: pref["label"] as String,
                          child: Text(pref["label"] as String),
                        ))
                    .toList(),
              ),

              SizedBox(height: 15),

              SizedBox(height: 10),
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
                  labelText: "Calories (e.g., 300-500)",
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
                        color: NudePalette.mauveBrown, width: 2),
                  ),
                ),
              ),
              SizedBox(height: 10),
              TextField(
                controller: mainIngredientController,
                decoration: InputDecoration(
                  labelText: "Main Ingredient (Optional)",
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
                        color: NudePalette.mauveBrown, width: 2),
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
                        color: NudePalette.mauveBrown, width: 2),
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
                        color: NudePalette.mauveBrown, width: 2),
                  ),
                ),
              ),
              SizedBox(height: 15),

              // Buttons: Get Meal & Save Recipe (Side by Side)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: _fetchRecipe,
                    icon: const Icon(Icons.fastfood),
                    label: const Text("Get Meal"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: NudePalette.mauveBrown,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _saveRecipe,
                    icon: const Icon(Icons.bookmark),
                    label: const Text("Save Recipe"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: NudePalette.mauveBrown,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
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
                          color: NudePalette.paleBlush,
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
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 5),
                            AnimatedCrossFade(
                              duration: Duration(milliseconds: 300),
                              firstChild: SizedBox.shrink(),
                              secondChild: Padding(
                                padding: EdgeInsets.only(top: 10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SelectableText(
                                      recipeDetails ?? "",
                                      style: TextStyle(fontSize: 16),
                                    ),
                                    SizedBox(
                                        height: 10), // Space before copy button
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            Clipboard.setData(ClipboardData(
                                                text: recipeDetails ?? ""));
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                  content:
                                                      Text("Recipe copied!")),
                                            );
                                          },
                                          icon: Icon(Icons.copy, size: 18),
                                          label: Text("Copy",
                                              style: TextStyle(fontSize: 14)),
                                          style: ElevatedButton.styleFrom(
                                            foregroundColor: Colors.black,
                                            backgroundColor:
                                                NudePalette.roseBlush,
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 8),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              crossFadeState: (expandedState[
                                          recipeTitle ?? "Generated Meal"] ??
                                      false)
                                  ? CrossFadeState.showSecond
                                  : CrossFadeState.showFirst,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ], // **👈 This bracket properly closes the children list of `Column`**
          ),
        ),
      ),

      // Bottom Navigation Bar (Same as Kitchen Screen)
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
          unselectedItemColor:
              NudePalette.lightCream.withAlpha((0.6 * 255).round()),
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
            //BottomNavigationBarItem(
            //  icon: Icon(Icons.rss_feed),
            //  label: "Feed",
            // ),
          ],
        ),
      ),
    );
  }
}
