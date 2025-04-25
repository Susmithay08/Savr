import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:savr/screens/home_screen.dart';
import 'package:savr/kitchen/kitchen_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'meal_screen.dart';
import 'package:savr/themes/colors.dart';

class MealPlannerScreen extends StatefulWidget {
  final bool showCheatMeal;
  const MealPlannerScreen({this.showCheatMeal = false}); // ✅ Add this

  @override
  _MealPlannerScreenState createState() => _MealPlannerScreenState();
}

class _MealPlannerScreenState extends State<MealPlannerScreen>
    with WidgetsBindingObserver {
  int _selectedIndex = 1;
  int totalPoints = 0;
  Set<String> _selectedDays = {};
  DateTime _startOfWeek = DateTime.now();
  Map<String, bool> _expandedDays = {};
  Set<String> _selectedMeals = {};
  final ScrollController _scrollController =
      ScrollController(); // ✅ for auto scroll
  Map<String, Map<String, dynamic>> _assignedRecipes = {};
  final TextEditingController _recipeTitleController = TextEditingController();
  final TextEditingController _recipeDetailsController =
      TextEditingController();
  final TextEditingController _mealKindController = TextEditingController();
  final TextEditingController _ingredientController = TextEditingController();
  String? selectedDay;
  Future<String> fetchGeminiResponse(String prompt) async {
    const apiKey = "AIzaSyC8RV1M4_yLHiOnBudsYehJrBXJs09jysg";
    const url =
        "https://generativelanguage.googleapis.com/v1/models/gemini-1.5-pro:generateContent?key=$apiKey";

    final response = await http.post(
      Uri.parse(url),
      headers: {"Content-Type": "application/json"},
      body: '''
    {
      "contents": [{
        "parts": [{"text": "$prompt"}]
      }]
    }
    ''',
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final text = json['candidates'][0]['content']['parts'][0]['text'];
      return text;
    } else {
      throw Exception("Failed to get AI response: ${response.body}");
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // ✅ observe app lifecycle
    _startOfWeek = _findMonday(DateTime.now());
    fetchUserPoints();
    loadMealPlanFromFirestore();
    if (widget.showCheatMeal) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 600),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // ✅ remove observer
    _recipeTitleController.dispose();
    _recipeDetailsController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      loadMealPlanFromFirestore(); // ✅ reload on resume
    }
  }

  DateTime _findMonday(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  void _changeWeek(int direction) {
    setState(() {
      _startOfWeek = _startOfWeek.add(Duration(days: 7 * direction));
    });

    // ✅ Reload meals for new week after changing
    loadMealPlanFromFirestore();
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
        //Navigator.pushReplacementNamed(context, '/feed');
        break;
    }
  }

  Future<void> fetchUserPoints() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final startOfWeek = _findMonday(DateTime.now());
    final weekId = DateFormat('yyyy-MM-dd').format(startOfWeek);

    try {
      final doc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .collection("points")
          .doc(weekId)
          .get();

      if (doc.exists) {
        final data = doc.data();
        setState(() {
          totalPoints = data?["total"] ?? 0;
        });
      } else {
        setState(() {
          totalPoints = 0;
        });
      }
    } catch (e) {
      print("❌ Error fetching weekly points: $e");
    }
  }

  void _cloneRecipe(Map<String, dynamic> recipe) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        List<DateTime> weekDays =
            List.generate(7, (i) => _startOfWeek.add(Duration(days: i)));
        String? selectedDay;
        String? selectedMealType;

        return StatefulBuilder(
          builder: (context, setSheetState) => Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Clone to...",
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                SizedBox(height: 15),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: weekDays.map((day) {
                    final key = DateFormat('yyyy-MM-dd').format(day);
                    return ChoiceChip(
                      label: Text(DateFormat('E, d MMM').format(day)),
                      selected: selectedDay == key,
                      onSelected: (_) {
                        setSheetState(() => selectedDay = key);
                      },
                    );
                  }).toList(),
                ),
                SizedBox(height: 15),
                Wrap(
                  spacing: 10,
                  children: ["Breakfast", "Lunch", "Dinner"].map((meal) {
                    return ChoiceChip(
                      label: Text(meal),
                      selected: selectedMealType == meal,
                      onSelected: (_) {
                        setSheetState(() => selectedMealType = meal);
                      },
                    );
                  }).toList(),
                ),
                SizedBox(height: 20),
                Center(
                  child: ElevatedButton(
                    onPressed: selectedDay != null && selectedMealType != null
                        ? () async {
                            final key = "$selectedDay-$selectedMealType";
                            setState(() {
                              _assignedRecipes[key] = recipe;
                            });
                            await saveMealPlanToFirestore();
                            if (mounted && Navigator.canPop(context)) {
                              Navigator.pop(
                                  context); // ✅ safely close loading dialog
                            }
                          }
                        : null,
                    child: Text("Clone Meal"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFE45F36),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding:
                          EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                    ),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> saveMealPlanToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final recipesToSave =
          Map<String, Map<String, dynamic>>.from(_assignedRecipes);

      for (var entry in recipesToSave.entries) {
        final key = entry.key;
        final parts = key.split('-');
        final dayKey = "${parts[0]}-${parts[1]}-${parts[2]}";
        final mealType = parts.sublist(3).join('-');

        await FirebaseFirestore.instance
            .collection("users")
            .doc(user.uid)
            .collection("mealPlans")
            .doc(dayKey)
            .collection("meals")
            .doc(mealType)
            .set(entry.value);
      }
    } catch (e) {
      print("❌ Failed to save meal plan: $e");
    }
  }

  Future<void> loadMealPlanFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      for (int i = 0; i < 7; i++) {
        final day = _startOfWeek.add(Duration(days: i));
        final dayKey = DateFormat('yyyy-MM-dd').format(day);

        final mealsSnapshot = await FirebaseFirestore.instance
            .collection("users")
            .doc(user.uid)
            .collection("mealPlans")
            .doc(dayKey)
            .collection("meals")
            .get();

        for (var doc in mealsSnapshot.docs) {
          final mealType = doc.id;
          final key = "$dayKey-$mealType";

          _assignedRecipes[key] = doc.data();
        }
      }

      setState(() {});
    } catch (e) {
      print("❌ Failed to load meal plan: $e");
    }
  }

  Future<List<Map<String, dynamic>>> fetchRecipesByMealType(
      String mealType) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .collection("secretRecipeVault")
          .where("categories", arrayContains: mealType)
          .get();

      return snapshot.docs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        return {
          "id": doc.id,
          "recipeTitle": data["recipeTitle"] ?? "Unnamed",
          "mealType": data["mealType"] ?? "Unknown",
          "recipeDetails": data["recipeDetails"] ?? "No details",
        };
      }).toList();
    } catch (e) {
      print("Error fetching recipes: \$e");
      return [];
    }
  }

  void _showAddMealPopup(BuildContext context) {
    DateTime startOfWeek = _startOfWeek;
    List<DateTime> weekDays =
        List.generate(7, (i) => startOfWeek.add(Duration(days: i)));

    TextEditingController titleController = TextEditingController();
    TextEditingController detailsController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: NudePalette.lightCream,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Add Custom Meal",
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: NudePalette.darkBrown)),
                          IconButton(
                            icon:
                                Icon(Icons.close, color: NudePalette.darkBrown),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      SizedBox(height: 15),

                      // Recipe Title Input
                      TextField(
                        controller: titleController,
                        decoration: InputDecoration(
                          labelText: "Recipe Title",
                          filled: true,
                          fillColor: NudePalette.paleBlush,
                          labelStyle: TextStyle(color: NudePalette.darkBrown),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: NudePalette.mauveBrown),
                          ),
                        ),
                      ),
                      SizedBox(height: 10),

                      // Recipe Steps Input
                      TextField(
                        controller: detailsController,
                        maxLines: 5,
                        decoration: InputDecoration(
                          labelText: "Recipe Steps",
                          filled: true,
                          fillColor: NudePalette.paleBlush,
                          labelStyle: TextStyle(color: NudePalette.darkBrown),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: NudePalette.mauveBrown),
                          ),
                        ),
                      ),
                      SizedBox(height: 15),

                      // Meal Type Chips
                      Text("Meal Type:",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: NudePalette.darkBrown)),
                      SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        children: ["Breakfast", "Lunch", "Dinner"].map((meal) {
                          final selected = _selectedMeals.contains(meal);
                          return ChoiceChip(
                            label: Text(meal),
                            selected: selected,
                            selectedColor: NudePalette.mauveBrown,
                            backgroundColor: NudePalette.paleBlush,
                            labelStyle: TextStyle(
                                color: selected
                                    ? Colors.white
                                    : NudePalette.darkBrown),
                            onSelected: (_) {
                              setDialogState(() {
                                selected
                                    ? _selectedMeals.remove(meal)
                                    : _selectedMeals.add(meal);
                              });
                            },
                          );
                        }).toList(),
                      ),
                      SizedBox(height: 15),

                      // Day Selector
                      Text("Choose Days:",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: NudePalette.darkBrown)),
                      SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: weekDays.map((day) {
                          final key = DateFormat('yyyy-MM-dd').format(day);
                          final selected = _selectedDays.contains(key);
                          return GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                selected
                                    ? _selectedDays.remove(key)
                                    : _selectedDays.add(key);
                              });
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 16),
                              decoration: BoxDecoration(
                                color: selected
                                    ? NudePalette.mauveBrown
                                    : NudePalette.paleBlush,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: NudePalette.mauveBrown, width: 1.2),
                              ),
                              child: Column(
                                children: [
                                  Text(DateFormat('E').format(day),
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: selected
                                              ? Colors.white
                                              : NudePalette.darkBrown)),
                                  Text(DateFormat('d MMM').format(day),
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: selected
                                              ? Colors.white70
                                              : NudePalette.darkBrown
                                                  .withOpacity(0.6))),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      SizedBox(height: 25),

                      // Submit Button
                      Center(
                        child: ElevatedButton(
                          onPressed: () async {
                            final title = titleController.text.trim();
                            final details = detailsController.text.trim();

                            if (title.isEmpty ||
                                details.isEmpty ||
                                _selectedDays.isEmpty ||
                                _selectedMeals.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          "Please fill all fields properly")));
                              return;
                            }

                            final user = FirebaseAuth.instance.currentUser;
                            if (user == null) return;

                            for (String day in _selectedDays) {
                              for (String mealType in _selectedMeals) {
                                final key = "$day-$mealType";
                                final recipe = {
                                  "recipeTitle": title,
                                  "recipeDetails": details,
                                  "mealType": mealType,
                                  "isCustom": true,
                                  "createdAt": Timestamp.now(),
                                };

                                setState(() {
                                  _assignedRecipes[key] = recipe;
                                  _expandedDays[day] = true;
                                });

                                await FirebaseFirestore.instance
                                    .collection("users")
                                    .doc(user.uid)
                                    .collection("mealPlans")
                                    .doc(day)
                                    .collection("meals")
                                    .doc(mealType)
                                    .set(recipe);
                              }
                            }

                            if (mounted && Navigator.canPop(context)) {
                              Navigator.pop(context);
                            }

                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content:
                                    Text("✅ Custom meal added successfully")));
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: NudePalette.mauveBrown,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30)),
                            padding: EdgeInsets.symmetric(
                                horizontal: 30, vertical: 12),
                          ),
                          child:
                              Text("Add Meal", style: TextStyle(fontSize: 16)),
                        ),
                      )
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showRecipePopupForDay(String mealType, String dayKey) async {
    List<Map<String, dynamic>> recipes = await fetchRecipesByMealType(mealType);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$mealType Recipes',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              recipes.isEmpty
                  ? Text("No recipes found for $mealType.")
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: recipes.length,
                      itemBuilder: (context, index) {
                        final recipe = recipes[index];
                        return Card(
                          elevation: 3,
                          child: ListTile(
                            title: Text(recipe['recipeTitle']),
                            subtitle: Text(recipe['recipeDetails'],
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                            onTap: () async {
                              setState(() {
                                final key = "$dayKey-$mealType";
                                _assignedRecipes[key] = recipe;
                              });

                              await saveMealPlanToFirestore(); // 🔥 this is the line you need

                              if (mounted && Navigator.canPop(context)) {
                                Navigator.pop(
                                    context); // ✅ safely close loading dialog
                              }
                            },
                          ),
                        );
                      },
                    ),
            ],
          ),
        );
      },
    );
  }

  void _showAIMealPlanPopup() {
    String selectedDiet = '';
    String allergyInfo = '';
    String healthGoal = '';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: EdgeInsets.all(20),
            child: StatefulBuilder(
              builder: (context, setState) {
                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("AI Meal Plan Preferences",
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black)),
                      SizedBox(height: 20),

                      // 🍽️ Diet dropdown
                      Text("Diet Preference",
                          style: TextStyle(fontWeight: FontWeight.w500)),
                      DropdownButton<String>(
                        value: selectedDiet.isEmpty ? null : selectedDiet,
                        hint: Text("Choose diet type"),
                        isExpanded: true,
                        items: [
                          "Vegetarian",
                          "Keto",
                          "High Protein",
                          "Low Carb",
                          "Vegan"
                        ]
                            .map((diet) => DropdownMenuItem(
                                  value: diet,
                                  child: Text(diet),
                                ))
                            .toList(),
                        onChanged: (val) {
                          setState(() => selectedDiet = val ?? '');
                        },
                      ),
                      SizedBox(height: 15),

                      // 🚫 Allergy info
                      Text("Allergies",
                          style: TextStyle(fontWeight: FontWeight.w500)),
                      TextField(
                        onChanged: (val) => allergyInfo = val,
                        decoration: InputDecoration(
                          hintText: "E.g., nuts, dairy",
                          filled: true,
                          fillColor: Colors.grey[200],
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none),
                        ),
                      ),
                      SizedBox(height: 15),

                      // 🩺 Health goals
                      Text("Health Goal",
                          style: TextStyle(fontWeight: FontWeight.w500)),
                      TextField(
                        onChanged: (val) => healthGoal = val,
                        decoration: InputDecoration(
                          hintText: "E.g., PCOS, weight loss",
                          filled: true,
                          fillColor: Colors.grey[200],
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none),
                        ),
                      ),
                      SizedBox(height: 20),

                      // ✅ Submit
                      Center(
                        child: ElevatedButton(
                          onPressed: () {
                            if (mounted && Navigator.canPop(context)) {
                              Navigator.pop(
                                  context); // ✅ safely close loading dialog
                            }
                            _generateAIPlan(
                              diet: selectedDiet,
                              allergies: allergyInfo,
                              goal: healthGoal,
                            );
                          },
                          child: Text("Generate Plan"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFFE45F36),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            padding: EdgeInsets.symmetric(
                                horizontal: 30, vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _generateAIPlan({
    required String diet,
    required String allergies,
    required String goal,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _selectedDays.isEmpty) return;

    final prompt = '''
You are a meal planning assistant. Generate a healthy meal plan with 3 meals per day (Breakfast, Lunch, Dinner) for the following selected days:
Days: ${_selectedDays.join(", ")}
Diet Preference: $diet
Allergies: $allergies
Health Goal: $goal

Please respond with meals in this format:
Day: yyyy-MM-dd
Breakfast: Recipe title - Steps...
Lunch: Recipe title - Steps...
Dinner: Recipe title - Steps...
''';

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => Dialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFFE45F36)),
                SizedBox(width: 20),
                Text("Creating meal plan...",
                    style: TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      );

      final response = await http.post(
        Uri.parse(
          "https://generativelanguage.googleapis.com/v1/models/gemini-1.5-pro:generateContent?key=AIzaSyC8RV1M4_yLHiOnBudsYehJrBXJs09jysg",
        ),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {"text": prompt}
              ]
            }
          ]
        }),
      );

      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context); // ✅ safely close loading dialog
      } // Hide loading dialog

      final data = jsonDecode(response.body);
      final text =
          data["candidates"]?[0]?["content"]?["parts"]?[0]?["text"] ?? "";

      final lines = text.split('\n');

      String currentDay = "";

      for (final line in lines) {
        if (line.startsWith("Day:")) {
          currentDay = line.replaceAll("Day:", "").trim();
        } else if (line.startsWith("Breakfast:") ||
            line.startsWith("Lunch:") ||
            line.startsWith("Dinner:")) {
          final parts = line.split(":");
          final mealType = parts[0].trim();
          final mealContent = parts.sublist(1).join(":").trim();

          final titleAndSteps = mealContent.split(" - ");
          final recipeTitle = titleAndSteps[0].trim();
          final recipeSteps = titleAndSteps.length > 1
              ? titleAndSteps.sublist(1).join(" - ").trim()
              : "No details provided.";

          final key = "$currentDay-$mealType";
          final recipe = {
            "recipeTitle": recipeTitle,
            "recipeDetails": recipeSteps,
            "mealType": mealType,
            "isAI": true,
          };

          setState(() {
            _assignedRecipes[key] = recipe;

            final dayKeyOnly = key.split('-').sublist(0, 3).join('-');
            _expandedDays[dayKeyOnly] = true;
          });

          // Save to Firestore
          await FirebaseFirestore.instance
              .collection("users")
              .doc(user.uid)
              .collection("mealPlans")
              .doc(currentDay)
              .collection("meals")
              .doc(mealType)
              .set(recipe);
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("AI meal plan generated 🍱")),
      );
    } catch (e) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context); // ✅ safely close loading dialog
      } // Ensure loading dialog is removed
      print("❌ Error generating AI plan: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to generate AI plan 😢")),
      );
    }
  }

  void _showRecipeDetailsDialog(Map<String, dynamic> recipe) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(recipe['recipeTitle']),
          content: SingleChildScrollView(
            child: Text(recipe['recipeDetails']),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close'),
            ),
            TextButton(
              onPressed: () {
                if (mounted && Navigator.canPop(context)) {
                  Navigator.pop(context); // ✅ safely close loading dialog
                }
                _cloneRecipe(recipe);
              },
              child: Text('Clone to...'),
            ),
          ],
        );
      },
    );
  }

  void _showImportWeekPopup() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final savedWeeksSnap = await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .collection("savedWeekPlans")
        .orderBy("savedAt", descending: true)
        .get();

    if (savedWeeksSnap.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No saved week plans available!")),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Import From Saved Week"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: savedWeeksSnap.docs.map((doc) {
              final weekId = doc.id; // Format: yyyy-MM-dd
              return ListTile(
                title: Text("Week of $weekId"),
                onTap: () async {
                  final mealsSnap =
                      await doc.reference.collection("meals").get();

                  // 🔁 Map old saved week (Mon–Sun) to current week (Mon–Sun)
                  final oldStartDate = DateFormat('yyyy-MM-dd').parse(doc.id);

                  for (final mealDoc in mealsSnap.docs) {
                    final mealData = mealDoc.data();
                    final parts =
                        mealDoc.id.split('-'); // e.g., 2025-03-24-Breakfast

                    final oldDay =
                        DateTime.parse("${parts[0]}-${parts[1]}-${parts[2]}");
                    final mealType = parts.sublist(3).join('-');

                    // ✅ Find which weekday it is (0 to 6 offset from oldStartDate)
                    final offset = oldDay.difference(oldStartDate).inDays;

                    // ✅ Apply same offset to new week's start date
                    final newDay = _startOfWeek.add(Duration(days: offset));
                    final newDayKey = DateFormat('yyyy-MM-dd').format(newDay);
                    final newKey = "$newDayKey-$mealType";

                    setState(() {
                      _assignedRecipes[newKey] = mealData;
                      _expandedDays[newDayKey] = true;
                    });

                    await FirebaseFirestore.instance
                        .collection("users")
                        .doc(user.uid)
                        .collection("mealPlans")
                        .doc(newDayKey)
                        .collection("meals")
                        .doc(mealType)
                        .set(mealData);
                  }

                  if (mounted && Navigator.canPop(context)) {
                    Navigator.pop(context); // ✅ safely close loading dialog
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("✅ Week imported successfully!")),
                  );
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NudePalette.lightCream,
      appBar: AppBar(
        backgroundColor: NudePalette.lightCream,

        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false, // we manually define back button
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: NudePalette.darkBrown),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const MealScreen()),
            );
          },
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () => _changeWeek(-1),
              child:
                  const Icon(Icons.chevron_left, color: NudePalette.darkBrown),
            ),
            const SizedBox(width: 4),
            const Text(
              "This Week",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => _changeWeek(1),
              child:
                  const Icon(Icons.chevron_right, color: NudePalette.darkBrown),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: SingleChildScrollView(
          controller: _scrollController, // ✅ ADD THIS LINE

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: NudePalette.lightCream,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text(
                      "Ready to plan this week?",
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(7, (i) {
                        final label = DateFormat('E')
                            .format(_startOfWeek.add(Duration(days: i)))
                            .substring(0, 2);
                        return _dayCircle(label, i);
                      }),
                    ),
                    SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () => _showAIMealPlanPopup(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFE45F36),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding:
                            EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                      ),
                      child:
                          Text("Start My Plan", style: TextStyle(fontSize: 16)),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: 7,
                itemBuilder: (context, index) {
                  final currentDay = _startOfWeek.add(Duration(days: index));
                  final dayKey = DateFormat('yyyy-MM-dd').format(currentDay);
                  final dayName = DateFormat('EEE').format(currentDay);
                  final dayDate = DateFormat('MMM d').format(currentDay);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("$dayName, $dayDate",
                                style: TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 16)),
                            (_assignedRecipes
                                        .containsKey("$dayKey-Breakfast") &&
                                    _assignedRecipes
                                        .containsKey("$dayKey-Lunch") &&
                                    _assignedRecipes
                                        .containsKey("$dayKey-Dinner"))
                                ? TextButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _expandedDays[dayKey] =
                                            !(_expandedDays[dayKey] ?? false);
                                      });
                                    },
                                    icon: Icon(
                                      _expandedDays[dayKey] ?? false
                                          ? Icons.keyboard_arrow_up
                                          : Icons.keyboard_arrow_down,
                                      color: Colors.black,
                                    ),
                                    label: Text(
                                      "Recipes Picked",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: NudePalette.darkBrown,
                                      ),
                                    ),
                                    style: TextButton.styleFrom(
                                      backgroundColor: Colors.orange.shade100,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                    ),
                                  )
                                : ElevatedButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _expandedDays[dayKey] =
                                            !(_expandedDays[dayKey] ?? false);
                                      });
                                    },
                                    icon: Icon(Icons.add, size: 18),
                                    label: Text("Pick Recipe"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.black,
                                      side: BorderSide(color: Colors.black),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                  ),
                          ],
                        ),
                      ),
                      if (_expandedDays[dayKey] ?? false)
                        Padding(
                          padding: const EdgeInsets.only(left: 15, bottom: 10),
                          child: Column(
                            children:
                                ["Breakfast", "Lunch", "Dinner"].map((meal) {
                              final key = "$dayKey-$meal";
                              final recipe = _assignedRecipes[key];

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        meal,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.add_circle_outline,
                                            color: Color(0xFFE45F36)),
                                        onPressed: () => _showRecipePopupForDay(
                                            meal, dayKey),
                                      ),
                                    ],
                                  ),
                                  if (recipe != null)
                                    Container(
                                      margin:
                                          EdgeInsets.only(top: 6, bottom: 12),
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: Color(0xFFF8F1EB),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                            color: Colors.orange.shade200),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: GestureDetector(
                                              onTap: () =>
                                                  _showRecipeDetailsDialog(
                                                      recipe),
                                              child: Text(
                                                recipe['recipeTitle'],
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              if (recipe['isAI'] == true ||
                                                  recipe['isCustom'] == true)
                                                IconButton(
                                                  icon: Icon(Icons.save_alt,
                                                      color: Colors.green),
                                                  onPressed: () async {
                                                    final user = FirebaseAuth
                                                        .instance.currentUser;
                                                    if (user == null) return;

                                                    final recipeData = {
                                                      "recipeTitle":
                                                          recipe["recipeTitle"],
                                                      "recipeDetails": recipe[
                                                          "recipeDetails"],
                                                      "mealType":
                                                          recipe["mealType"],
                                                      "isCustom":
                                                          recipe["isCustom"] ??
                                                              false,
                                                      "isAI": recipe["isAI"] ??
                                                          false,
                                                      "categories": [
                                                        recipe["mealType"]
                                                      ],
                                                      "savedAt":
                                                          Timestamp.now(),
                                                    };

                                                    await FirebaseFirestore
                                                        .instance
                                                        .collection("users")
                                                        .doc(user.uid)
                                                        .collection(
                                                            "secretRecipeVault")
                                                        .add(recipeData);

                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                      SnackBar(
                                                          content: Text(
                                                              "✅ Saved to Recipe Vault!")),
                                                    );
                                                  },
                                                ),
                                              IconButton(
                                                icon: Icon(Icons.delete,
                                                    color: Colors.redAccent),
                                                onPressed: () async {
                                                  final user = FirebaseAuth
                                                      .instance.currentUser;
                                                  if (user != null) {
                                                    final mealType =
                                                        key.split('-').last;
                                                    final dayKey = key
                                                        .split('-')
                                                        .sublist(0, 3)
                                                        .join('-');

                                                    await FirebaseFirestore
                                                        .instance
                                                        .collection("users")
                                                        .doc(user.uid)
                                                        .collection("mealPlans")
                                                        .doc(dayKey)
                                                        .collection("meals")
                                                        .doc(mealType)
                                                        .delete();

                                                    setState(() {
                                                      _assignedRecipes
                                                          .remove(key);

                                                      final hasAllMeals = _assignedRecipes
                                                              .containsKey(
                                                                  "$dayKey-Breakfast") &&
                                                          _assignedRecipes
                                                              .containsKey(
                                                                  "$dayKey-Lunch") &&
                                                          _assignedRecipes
                                                              .containsKey(
                                                                  "$dayKey-Dinner");

                                                      if (!hasAllMeals) {
                                                        _expandedDays[dayKey] =
                                                            true;
                                                      }
                                                    });

                                                    await saveMealPlanToFirestore();
                                                  }
                                                },
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                    ],
                  );
                },
              ),
              Center(
                child: OutlinedButton(
                  onPressed: () {
                    _showAddMealPopup(context);
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Color(0xFFE45F36)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  ),
                  child: Text("Add Custom Meal",
                      style: TextStyle(color: Color(0xFFE45F36), fontSize: 16)),
                ),
              ),
              SizedBox(height: 10),
              Center(
                child: ElevatedButton(
                  onPressed: () async {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user == null) return;

                    final now = DateTime.now();
                    final weekId =
                        DateFormat('yyyy-MM-dd').format(_startOfWeek);
                    final ref = FirebaseFirestore.instance
                        .collection("users")
                        .doc(user.uid)
                        .collection("savedWeekPlans")
                        .doc(weekId);

                    await ref.set({"savedAt": now});

                    for (var entry in _assignedRecipes.entries) {
                      await ref
                          .collection("meals")
                          .doc(entry.key)
                          .set(entry.value);
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("✅ Week plan saved successfully")),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFE45F36),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  ),
                  child: Text("Save This Week's Plan",
                      style: TextStyle(fontSize: 16)),
                ),
              ),
              SizedBox(height: 10),
              Center(
                child: OutlinedButton(
                  onPressed: _showImportWeekPopup,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Color(0xFFE45F36)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  ),
                  child: Text(
                    "Import From Week Plan",
                    style: TextStyle(color: Color(0xFFE45F36), fontSize: 16),
                  ),
                ),
              ),
              SizedBox(height: 10),
              if (totalPoints >= 21)
                Container(
                  margin: EdgeInsets.only(top: 20),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Cheat Meals for the week",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      SizedBox(height: 5),
                      Text(
                        "Let your calorie-counting pause for a day while your taste buds revel in sweet, savory freedom.",
                        style: TextStyle(
                            fontSize: 14, color: NudePalette.darkBrown),
                      ),
                      SizedBox(height: 15),
                      Center(
                          child: Image.asset("assets/planner.png", width: 200)),
                      SizedBox(height: 15),
                      Center(
                        child: totalPoints >= 21
                            ? ElevatedButton(
                                onPressed: _showCheatMealPopup,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFFE45F36),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 30, vertical: 12),
                                ),
                                child: Text("Get Ideas Here",
                                    style: TextStyle(fontSize: 16)),
                              )
                            : Column(
                                children: [
                                  Text(
                                    "😅 You need 21 points to unlock this cheat meal!",
                                    style: TextStyle(color: Colors.redAccent),
                                  ),
                                  SizedBox(height: 8),
                                  OutlinedButton(
                                    onPressed: () {},
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(color: Colors.grey),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                    child: Text("Cheat Meal Locked 🔒"),
                                  )
                                ],
                              ),
                      )
                    ],
                  ),
                )
              else
                Container(
                  margin: EdgeInsets.only(top: 20),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.shade100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Cheat Meal Locked 🔒",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      SizedBox(height: 5),
                      Text(
                        "Earn 21+ weekly points to unlock your cheat meal. Eat well, stay healthy and enjoy the reward 🍕",
                        style: TextStyle(
                            fontSize: 14, color: NudePalette.darkBrown),
                      ),
                      SizedBox(height: 15),
                      Center(
                        child: Text("Current Points: $totalPoints",
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.deepOrange)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.black,
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
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white60,
          currentIndex: _selectedIndex,
          onTap: _onBottomNavTapped,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
            BottomNavigationBarItem(
                icon: Icon(Icons.kitchen), label: "Kitchen"),
            BottomNavigationBarItem(
                icon: Icon(Icons.medical_services), label: "Medicines"),
            BottomNavigationBarItem(
                icon: Icon(Icons.favorite), label: "Health"),
            //BottomNavigationBarItem(icon: Icon(Icons.rss_feed), label: "Feed"),
          ],
        ),
      ),
    );
  }

  void _showCheatMealPopup() {
    final TextEditingController mealTypeController = TextEditingController();
    final TextEditingController ingredientController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Get Cheat Meal Idea 🍔",
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  SizedBox(height: 15),
                  Text("Meal Type (e.g., Breakfast, Dinner)",
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  SizedBox(height: 8),
                  TextField(
                    controller: mealTypeController,
                    decoration: InputDecoration(
                      hintText: "Enter meal type",
                      filled: true,
                      fillColor: Colors.grey[200],
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none),
                    ),
                  ),
                  SizedBox(height: 15),
                  Text("Main Ingredient",
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  SizedBox(height: 8),
                  TextField(
                    controller: ingredientController,
                    decoration: InputDecoration(
                      hintText: "E.g., chocolate, cheese",
                      filled: true,
                      fillColor: Colors.grey[200],
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none),
                    ),
                  ),
                  SizedBox(height: 20),
                  Center(
                    child: ElevatedButton(
                      onPressed: () async {
                        final mealType = mealTypeController.text.trim();
                        final ingredient = ingredientController.text.trim();

                        if (mealType.isEmpty || ingredient.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text("Please fill in all fields.")));
                          return;
                        }

                        Navigator.pop(dialogContext); // Close the form dialog

                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) => Dialog(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15)),
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(
                                      color: Color(0xFFE45F36)),
                                  SizedBox(width: 20),
                                  Text("Generating recipe...",
                                      style: TextStyle(
                                          fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                          ),
                        );

                        final prompt = '''
Give me a fun cheat meal recipe idea.
Meal Type: $mealType
Main Ingredient: $ingredient

Format:
Title: <recipe title>
Details: <step-by-step instructions>
''';

                        try {
                          final aiResponse = await fetchGeminiResponse(prompt);

                          if (Navigator.canPop(context)) Navigator.pop(context);

                          final lines = aiResponse.trim().split('\n');

                          String title = "Untitled Recipe";
                          StringBuffer steps = StringBuffer();

                          for (var line in lines) {
                            if (line.toLowerCase().startsWith("title:")) {
                              title = line.substring(6).trim();
                            } else if (line
                                .toLowerCase()
                                .startsWith("details:")) {
                              steps.writeln(line.substring(8).trim());
                            } else {
                              steps.writeln(line.trim());
                            }
                          }

                          final details = steps.toString().trim();

                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: Text("Cheat Meal Idea 🍽️"),
                              content: GestureDetector(
                                onTap: () {
                                  Navigator.pop(context); // Close preview
                                  _showFullCheatMealPopup(
                                      title, details, mealType);
                                  // Open full popup
                                },
                                child: Card(
                                  color: Colors.orange.shade50,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Text(
                                      title,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: Colors.deepOrange,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        } catch (e) {
                          if (Navigator.canPop(context)) Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content:
                                  Text("❌ Failed to generate recipe: $e")));
                        }
                      },
                      child: Text("OK"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFE45F36),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                        padding:
                            EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showFullCheatMealPopup(String title, String details, String mealType) {
    final cleanDetails = details
        .replaceAll(RegExp(r'\*\*'), '')
        .replaceAll(RegExp(r'[_*#>`~\-]'), '');

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.7, // ✅ Bigger height
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: NudePalette.darkBrown)),
              SizedBox(height: 10),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    cleanDetails,
                    style:
                        TextStyle(fontSize: 14, color: NudePalette.darkBrown),
                  ),
                ),
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text("Close"),
                  ),
                  SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () async {
                      // ✅ Moved inside
                      final user = FirebaseAuth.instance.currentUser;
                      if (user == null) return;

                      await FirebaseFirestore.instance
                          .collection("users")
                          .doc(user.uid)
                          .collection("secretRecipeVault")
                          .add({
                        "recipeTitle": title,
                        "recipeDetails": cleanDetails,
                        "mealType": mealType,
                        "isCheatMeal": true,
                        "savedAt": Timestamp.now(),
                        "categories": [mealType, "cheatmeals"],
                      });

                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text("✅ Cheat meal saved to your vault!")),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFE45F36),
                      foregroundColor: Colors.white,
                    ),
                    child: Text("Save to Vault"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mealOptionRow(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          Icon(Icons.add_circle_outline, color: Color(0xFFE45F36))
        ],
      ),
    );
  }

  Widget _dayCircle(String label, int index) {
    final selected = _selectedDays.contains(
      DateFormat('yyyy-MM-dd').format(_startOfWeek.add(Duration(days: index))),
    );

    return GestureDetector(
      onTap: () {
        setState(() {
          final selectedDate = DateFormat('yyyy-MM-dd')
              .format(_startOfWeek.add(Duration(days: index)));
          if (selected) {
            _selectedDays.remove(selectedDate);
          } else {
            _selectedDays.add(selectedDate);
          }
        });
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 5),
        width: 35,
        height: 35,
        decoration: BoxDecoration(
          color: selected ? Color(0xFFE45F36) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Color(0xFFE45F36), width: 2),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Color(0xFFE45F36),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
