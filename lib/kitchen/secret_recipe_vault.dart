import 'package:flutter/material.dart';
import 'package:savr/screens/home_screen.dart';
import 'package:savr/kitchen/kitchen_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:savr/themes/colors.dart';

class SecretRecipeVaultScreen extends StatefulWidget {
  const SecretRecipeVaultScreen({Key? key}) : super(key: key);

  @override
  _SecretRecipeVaultScreenState createState() =>
      _SecretRecipeVaultScreenState();
}

class _SecretRecipeVaultScreenState extends State<SecretRecipeVaultScreen> {
  int _selectedIndex = 1; // Kitchen is selected by default

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

  String? selectedCategory;

  // List of meal types with images (Faded effect applied)
  final List<Map<String, String>> mealTypes = [
    {"image": "assets/box1.png", "label": "Breakfast"},
    {"image": "assets/box2.png", "label": "Lunch"},
    {"image": "assets/box3.png", "label": "Snack"},
    {"image": "assets/box4.png", "label": "Dinner"},
  ];

  // Other diet options (Icons instead of images)
  final List<Map<String, dynamic>> otherDiets = [
    {"label": "Mediterranean", "icon": Icons.local_dining},
    {"label": "Keto", "icon": Icons.restaurant},
    {"label": "Paleo", "icon": Icons.eco},
    {"label": "Atkins", "icon": Icons.no_food},
    {"label": "Dash", "icon": Icons.fitness_center},
    {"label": "Whole30", "icon": Icons.health_and_safety},
    {"label": "Hindu", "icon": Icons.temple_hindu},
  ];

  final List<Map<String, dynamic>> diets = [
    {"label": "Vegan", "icon": Icons.spa},
    {"label": "Classic", "icon": Icons.food_bank},
    {"label": "Vegetarian", "icon": Icons.emoji_nature},
    {"label": "Pescetarian", "icon": Icons.set_meal},
    {"label": "Flexitarian", "icon": Icons.eco},
  ];

  final List<Map<String, dynamic>> nutritionalPreferences = [
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NudePalette.lightCream,

      // ✅ Proper placement of AppBar
      appBar: AppBar(
        backgroundColor: NudePalette.lightCream,
        elevation: 0,
        centerTitle: true,
        foregroundColor: NudePalette.darkBrown,
        title: const Text(
          "Secret Recipe Vault",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle("Meal Type"),
            _buildMealTypeList(mealTypes),
            _buildSectionTitle("Other Diets"),
            _buildPlainTextList(otherDiets),
            _buildSectionTitle("Diets"),
            _buildPlainTextList(diets),
            _buildSectionTitle("Nutritional Preferences"),
            _buildPlainTextList(nutritionalPreferences),
            _buildSectionTitle("Cheat Meals"),
            _buildCheatMealCard(),
          ],
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
            //   icon: Icon(Icons.rss_feed),
            //   label: "Feed",
            // ),
          ],
        ),
      ),
    );
  }

  /// Widget for Cheat Meals Card
  Widget _buildCheatMealCard() {
    return GestureDetector(
      onTap: () async {
        List<Map<String, dynamic>> recipes = await fetchRecipes("cheatmeals");
        _showRecipeList("Cheat Meals", recipes);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        height: 80,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: NudePalette.paleBlush,
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 5, spreadRadius: 2),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Text(
                  "Cheat Meals",
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            ClipRRect(
              borderRadius:
                  const BorderRadius.horizontal(right: Radius.circular(12)),
              child: Image.asset("assets/cheatmeal.png",
                  width: 100, fit: BoxFit.cover),
            ),
          ],
        ),
      ),
    );
  }

  /// Function to create section titles
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: NudePalette.darkBrown),
      ),
    );
  }

  /// Function to build the Meal Type list with a click action
  Widget _buildMealTypeList(List<Map<String, String>> items) {
    return Column(
      children: items.map((item) {
        return GestureDetector(
          onTap: () async {
            List<Map<String, dynamic>> recipes =
                await fetchRecipes(item["label"]!);
            _showRecipeList(item["label"]!, recipes);
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: NudePalette.paleBlush, // ✅ matches SAVR card look
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 5,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Text(
                      item["label"]!,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                ClipRRect(
                  borderRadius:
                      const BorderRadius.horizontal(right: Radius.circular(12)),
                  child: Image.asset(item["image"]!,
                      width: 100, fit: BoxFit.cover),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPlainTextList(List<Map<String, dynamic>> items) {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        itemBuilder: (context, index) {
          String label = items[index]["label"];
          bool isSelected = selectedCategory == label;

          return GestureDetector(
            onTap: () async {
              setState(() => selectedCategory = label);
              List<Map<String, dynamic>> recipes = await fetchRecipes(label);
              _showRecipeList(label, recipes);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? NudePalette.darkBrown
                      : NudePalette.darkBrown.withOpacity(0.6),
                  fontSize: 16,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Fetches recipes based on the selected category (Meal Type, Diet, or Nutrition)
  Future<List<Map<String, dynamic>>> fetchRecipes(String category) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .collection("secretRecipeVault")
          .where("categories", arrayContains: category)
          .get();

      return snapshot.docs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        return {
          "id": doc.id,
          "recipeTitle":
              data["recipeTitle"] ?? "Unnamed Recipe", // 🔥 Prevent null
          "mealType":
              data["mealType"] ?? "Unknown Meal Type", // 🔥 Prevent null
          "recipeDetails": data["recipeDetails"] ?? "No details available",
        };
      }).toList();
    } catch (e) {
      print("Error fetching recipes: $e");
      return [];
    }
  }

  void _showRecipeList(String category, List<Map<String, dynamic>> recipes) {
    TextEditingController searchController = TextEditingController();
    List<Map<String, dynamic>> filteredRecipes =
        List.from(recipes); // Copy of recipes

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows full-screen height
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                height: MediaQuery.of(context).size.height *
                    0.85, // ✅ Constrain height
                child: Column(
                  children: [
                    // 🔎 Search Bar
                    TextField(
                      controller: searchController,
                      onChanged: (query) {
                        setState(() {
                          filteredRecipes = recipes
                              .where((recipe) => recipe['recipeTitle']
                                  .toLowerCase()
                                  .contains(query.toLowerCase()))
                              .toList();
                        });
                      },
                      decoration: InputDecoration(
                        hintText: "Search recipes...",
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 📌 Recipe List
                    Expanded(
                      child: filteredRecipes.isEmpty
                          ? Center(
                              child: Text("No recipes found in this category."),
                            )
                          : ListView.builder(
                              itemCount: filteredRecipes.length,
                              itemBuilder: (context, index) {
                                var recipe = filteredRecipes[index];
                                return Card(
                                  elevation: 5,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.all(12),
                                    title: Text(
                                      recipe['recipeTitle'] ?? "Unnamed Recipe",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    subtitle: Text(
                                      recipe['mealType'] ?? "Unknown Meal Type",
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.delete,
                                              color: Colors.red),
                                          onPressed: () {
                                            _confirmDeleteRecipe(recipe['id'],
                                                setState, filteredRecipes);
                                          },
                                        ),
                                        const Icon(Icons.arrow_forward_ios,
                                            size: 18),
                                      ],
                                    ),
                                    onTap: () {
                                      Navigator.pop(context);
                                      _showRecipeDetails(recipe);
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// 🚨 Function to Confirm & Delete Recipe
  void _confirmDeleteRecipe(String recipeId, Function setState,
      List<Map<String, dynamic>> filteredRecipes) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Delete Recipe"),
          content: Text("Are you sure you want to delete this recipe?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), // Cancel
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                await _deleteRecipe(recipeId, setState, filteredRecipes);
                Navigator.pop(context); // Close the confirmation dialog
              },
              child: Text("Delete", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  /// 🔥 Function to Delete Recipe from Firestore
  Future<void> _deleteRecipe(String recipeId, Function setState,
      List<Map<String, dynamic>> filteredRecipes) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .collection("secretRecipeVault")
          .doc(recipeId)
          .delete();

      // ✅ Remove the deleted recipe from the list dynamically
      setState(() {
        filteredRecipes.removeWhere((recipe) => recipe['id'] == recipeId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Recipe deleted successfully")),
      );
    } catch (e) {
      print("Error deleting recipe: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to delete recipe")),
      );
    }
  }

  void _showRecipeDetails(Map<String, dynamic> recipe) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "",
      transitionDuration: Duration(milliseconds: 300),
      pageBuilder: (context, _, __) {
        return AlertDialog(
          title: Text(recipe['recipeTitle']),
          content: SingleChildScrollView(
            child: Text(recipe['recipeDetails']),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Close"),
            ),
          ],
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: child,
        );
      },
    );
  }
}
