import 'package:flutter/material.dart';
import 'dart:async'; // Import Timer for auto-refresh
import 'dart:math'; // For randomizing cooking tips
import 'kitchen_screen.dart';
import 'package:savr/screens/home_screen.dart';
import 'secret_recipe_vault.dart';
import 'pantry_recipe_screen.dart';
import 'freestyle_screen.dart';
import 'mealplanner_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:savr/themes/colors.dart';

class MealScreen extends StatefulWidget {
  const MealScreen({Key? key}) : super(key: key);

  @override
  _MealScreenState createState() => _MealScreenState();
}

class _MealScreenState extends State<MealScreen> {
  int _selectedIndex = 1; // Kitchen is at index 1 in the bottom nav
  int mealsCooked = 7; // Sample meal count (Replace with actual data)

  List<String> cookingTips = [
    "Always preheat your pan before adding ingredients for the best flavor!",
    "Use fresh herbs at the end of cooking for a burst of flavor.",
    "Let meat rest after cooking to keep it juicy and flavorful.",
    "A pinch of salt enhances the sweetness in desserts!",
    "Toast your spices before using them to bring out their full aroma.",
    "A sharp knife is safer than a dull one—keep your knives sharp!"
  ];
  String tipOfTheDay = "";
  Timer? _tipTimer;

  @override
  void initState() {
    super.initState();
    _generateRandomCookingTip();
    _tipTimer = Timer.periodic(Duration(seconds: 60), (timer) {
      _generateRandomCookingTip();
    });
  }

  @override
  void dispose() {
    _tipTimer?.cancel(); // Cancel timer when the screen is closed
    super.dispose();
  }

  void _generateRandomCookingTip() {
    final random = Random();
    setState(() {
      tipOfTheDay = cookingTips[random.nextInt(cookingTips.length)];
    });
  }

  void _onBottomNavTapped(int index) {
    if (index == 1) {
      if (ModalRoute.of(context)?.settings.name != "/kitchen") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const KitchenScreen()),
        );
      }
    } else {
      setState(() {
        _selectedIndex = index;
      });

      if (index == 0) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomeScreen()),
        );
      }
    }
  }

  Widget _buildTipCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: NudePalette.paleBlush,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.tips_and_updates, color: Colors.orange),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Tip of the Day: $tipOfTheDay",
              style: const TextStyle(
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                  color: NudePalette.darkBrown),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NudePalette.lightCream,
// Matches Kitchen Screen background
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 10),

// Back Button + Header Title
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back,
                        color: NudePalette.darkBrown),
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const KitchenScreen()),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      "MasterChef Mode",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: NudePalette.darkBrown,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48), // Balance spacing
                ],
              ),

              const SizedBox(height: 5),
              Text(
                "Create meals, plan your food journey, and save delicious recipes.",
                style: TextStyle(
                  fontSize: 16,
                  color: NudePalette.darkBrown.withAlpha((0.6 * 255).round()),
                ),
              ),
              const SizedBox(height: 30),
              const SizedBox(height: 10),
              _buildTipCard(),

              const SizedBox(height: 30),

              // Meal Options (Centered in Page)
              Expanded(
                child: Center(
                  child: GridView.count(
                    shrinkWrap: true,
                    crossAxisCount: 2, // Two items per row
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                    children: [
                      _buildOption(
                        imagePath: 'assets/one.png',
                        title: "Pantry Magic",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  PantryRecipeScreen(), // Ensure this screen exists
                            ),
                          );
                        },
                      ),
                      _buildOption(
                        imagePath: 'assets/two.png',
                        title: "Freestyle Feast",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => FreestyleScreen()),
                          );
                        },
                      ),
                      _buildOption(
                        imagePath: 'assets/three.png',
                        title: "Secret Recipe Vault",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const SecretRecipeVaultScreen(),
                            ),
                          );
                        },
                      ),
                      _buildOption(
                        imagePath: 'assets/four.png',
                        title: "Meal Planner 3000",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => MealPlannerScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });

            if (index == 0) {
              Navigator.pushReplacementNamed(context, '/home');
            } else if (index == 1) {
              Navigator.pushReplacementNamed(context, '/kitchen');
            } else if (index == 2) {
              Navigator.pushReplacementNamed(context, '/medicines');
            } else if (index == 3) {
              Navigator.pushReplacementNamed(context, '/health');
            } //else if (index == 4) {
            //Navigator.pushReplacementNamed(context, '/feed');
            //}
          },
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
            // label: "Feed",
            // ),
          ],
        ),
      ),
    );
  }

  /// Function to display "Your Cooking Stats" (No Box)

  /// Function to build meal options
  Widget _buildOption(
      {required String imagePath,
      required String title,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Image.asset(imagePath, width: 100),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: NudePalette.darkBrown,
            ),
          ),
        ],
      ),
    );
  }
}
