import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:savr/screens/home_screen.dart';
import 'pantry_screen.dart';
import 'grocery_screen.dart';
import 'meal_screen.dart';
import 'remedies_screen.dart';
import 'package:savr/themes/colors.dart';

class KitchenScreen extends StatefulWidget {
  const KitchenScreen({Key? key}) : super(key: key);

  @override
  _KitchenScreenState createState() => _KitchenScreenState();
}

class _KitchenScreenState extends State<KitchenScreen> {
  int _selectedIndex = 1;
  int expiredCount = 0;
  int expiringSoonCount = 0;
  int freshCount = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPantryExpiryData();
  }

  Future<void> _fetchPantryExpiryData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .collection("pantryItems")
          .get();

      int expired = 0, expiringSoon = 0, fresh = 0;
      DateTime now = DateTime.now();

      for (var doc in snapshot.docs) {
        DateTime expiryDate = (doc['expiryDate'] as Timestamp).toDate();
        if (expiryDate.isBefore(now)) {
          expired++;
        } else if (expiryDate.isBefore(now.add(const Duration(days: 3)))) {
          expiringSoon++;
        } else {
          fresh++;
        }
      }

      setState(() {
        expiredCount = expired;
        expiringSoonCount = expiringSoon;
        freshCount = fresh;
        isLoading = false;
      });
    } catch (e) {
      print("Error fetching pantry expiry data: $e");
    }
  }

  Widget _buildPantryAlert() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (expiredCount == 0 && expiringSoonCount == 0 && freshCount == 0) {
      return const Center(
        child: Text(
          "No items in pantry.",
          style: TextStyle(fontSize: 16, color: Colors.black54),
        ),
      );
    }

    return Column(
      children: [
        if (expiredCount > 0)
          _buildAlertRow("Expired: $expiredCount items", Colors.red),
        if (expiringSoonCount > 0)
          _buildAlertRow(
              "Expiring Soon: $expiringSoonCount items", Colors.orange),
        if (freshCount > 0)
          _buildAlertRow("Fresh: $freshCount items", Colors.green),
      ],
    );
  }

  Widget _buildAlertRow(String text, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.warning, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomeScreen()),
        );
        return false;
      },
      child: Scaffold(
        backgroundColor: NudePalette.lightCream,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  "Manage Your Kitchen",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: NudePalette.darkBrown,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  "Track your pantry, groceries, meals, and remedies in one place.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
                const SizedBox(height: 20),
                _buildPantryAlert(),
                const SizedBox(height: 20),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                    children: [
                      _buildOption(
                        imagePath: 'assets/pantry.png',
                        title: "Pantry",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const PantryScreen()),
                          ).then((_) => _fetchPantryExpiryData());
                        },
                      ),
                      _buildOption(
                        imagePath: 'assets/bag.png',
                        title: "Grocery",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const GroceryScreen()),
                          );
                        },
                      ),
                      _buildOption(
                        imagePath: 'assets/meals.png',
                        title: "Meals",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => MealScreen()),
                          );
                        },
                      ),
                      _buildOption(
                        imagePath: 'assets/remedy.png',
                        title: "Remedy",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const RemediesScreen()),
                          );
                        },
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
            color: NudePalette.darkBrown,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: NudePalette.darkBrown.withOpacity(0.4),
                blurRadius: 10,
                spreadRadius: 2,
              ),
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
            onTap: (index) {
              setState(() {
                _selectedIndex = index;
              });

              if (index == 0) {
                Navigator.pushReplacementNamed(context, '/home');
              } else if (index == 1) {
                // Stay
              } else if (index == 2) {
                Navigator.pushReplacementNamed(context, '/medicines');
              } else if (index == 3) {
                Navigator.pushReplacementNamed(context, '/health');
              } else if (index == 4) {
                // TODO: Navigate to Feed screen
              }
            },
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
              BottomNavigationBarItem(
                  icon: Icon(Icons.kitchen), label: "Kitchen"),
              BottomNavigationBarItem(
                  icon: Icon(Icons.medical_services), label: "Medicines"),
              BottomNavigationBarItem(
                  icon: Icon(Icons.favorite), label: "Health"),
              //BottomNavigationBarItem(
              //icon: Icon(Icons.rss_feed), label: "Feed"),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOption({
    required String imagePath,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: NudePalette.paleBlush,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(imagePath, width: 70),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: NudePalette.darkBrown,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
