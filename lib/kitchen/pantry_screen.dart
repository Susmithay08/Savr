import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:savr/screens/home_screen.dart';
import 'barcode_scanner_screen.dart';
import 'kitchen_screen.dart';
import 'package:savr/services/expiry_prediction_service.dart';
import 'package:savr/services/barcode_service.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:savr/themes/colors.dart';

/// Data model for a pantry item.
class PantryItem {
  String id;
  String name;
  DateTime boughtDate;
  DateTime expiryDate;
  DateTime createdAt;

  PantryItem({
    required this.id,
    required this.name,
    required this.boughtDate,
    required this.expiryDate,
    required this.createdAt,
  });

  factory PantryItem.fromDocument(DocumentSnapshot doc) {
    return PantryItem(
      id: doc.id,
      name: doc['name'] ?? '',
      boughtDate: (doc['boughtDate'] as Timestamp).toDate(),
      expiryDate: (doc['expiryDate'] as Timestamp).toDate(),
      createdAt: (doc['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'boughtDate': Timestamp.fromDate(boughtDate),
      'expiryDate': Timestamp.fromDate(expiryDate),
      'createdAt': Timestamp.now(),
    };
  }
}

class PantryScreen extends StatefulWidget {
  const PantryScreen({Key? key}) : super(key: key);

  @override
  _PantryScreenState createState() => _PantryScreenState();
}

class _PantryScreenState extends State<PantryScreen> {
  List<PantryItem> pantryItems = [];
  List<PantryItem> filteredItems = [];
  TextEditingController searchController = TextEditingController();

  // Bottom nav index for Kitchen layout (assuming index 1 is Kitchen)
  int currentBottomIndex = 1;

  @override
  void initState() {
    super.initState();
    _fetchPantryItems();
  }

  void _showAddToGroceryDialog(PantryItem item) {
    final quantityController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Add to Grocery List"),
          content: TextField(
            controller: quantityController,
            decoration: const InputDecoration(
              labelText: "Enter quantity (e.g. 1 kg, 2 packs)",
            ),
          ),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: NudePalette.mauveBrown,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text("Add"),
              onPressed: () {
                if (quantityController.text.trim().isEmpty) return;

                _addToGroceryList(item, quantityController.text.trim());
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _addToGroceryList(PantryItem item, String quantity) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .collection("groceryItems")
          .add({
        'name': item.name,
        'quantity': quantity, // User-entered quantity
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Item added to grocery list")),
      );
    } catch (e) {
      print("Error adding item to grocery list: $e");
    }
  }

  /// Fetches pantry items from Firestore for the current user.
  Future<void> _fetchPantryItems() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .collection("pantryItems")
          .get();

      List<PantryItem> items =
          snapshot.docs.map((doc) => PantryItem.fromDocument(doc)).toList();

      setState(() {
        pantryItems = items;
        _applyFilter();
      });
    } catch (e) {
      print("Error fetching pantry items: $e");
    }
  }

  /// Adds a new pantry item to Firestore.
  Future<void> _addPantryItem(PantryItem item) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .collection("pantryItems")
          .add(item.toMap());
      // Refresh local list
      _fetchPantryItems();
    } catch (e) {
      print("Error adding pantry item: $e");
    }
  }

  /// Deletes a pantry item from Firestore.
  Future<void> _deletePantryItem(PantryItem item) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .collection("pantryItems")
          .doc(item.id)
          .delete();
      // Refresh local list
      _fetchPantryItems();
    } catch (e) {
      print("Error deleting pantry item: $e");
    }
  }

  /// Applies the search filter and sorts items by expiry status.
  void _applyFilter() {
    String query = searchController.text.toLowerCase();
    List<PantryItem> temp = pantryItems
        .where((item) => item.name.toLowerCase().contains(query))
        .toList();

    // Sort items: expired (0), near expiry (1), fresh (2).
    temp.sort((a, b) {
      int statusA = _getExpiryStatus(a);
      int statusB = _getExpiryStatus(b);
      if (statusA != statusB) {
        return statusA.compareTo(statusB);
      } else {
        return a.expiryDate.compareTo(b.expiryDate);
      }
    });

    setState(() {
      filteredItems = temp;
    });
  }

  /// Returns a numerical status for sorting:
  /// 0 = expired, 1 = near expiry (within 3 days), 2 = fresh.
  int _getExpiryStatus(PantryItem item) {
    DateTime now = DateTime.now();
    if (item.expiryDate.isBefore(now)) {
      return 0; // expired
    } else if (item.expiryDate.isBefore(now.add(const Duration(days: 3)))) {
      return 1; // near expiry
    } else {
      return 2; // fresh
    }
  }

  /// Returns a text color based on the expiry status.
  Color _getTextColor(PantryItem item) {
    int status = _getExpiryStatus(item);
    if (status == 0) {
      return Colors.red;
    } else if (status == 1) {
      return Colors.orange;
    } else {
      return Colors.green;
    }
  }

  void _showAddItemDialog() async {
    final result = await showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Add Manually'),
            onTap: () {
              Navigator.pop(context);
              _showManualItemEntryDialog();
            },
          ),
          ListTile(
            leading: const Icon(Icons.qr_code_scanner),
            title: const Text('Scan Barcode'),
            onTap: () async {
              Navigator.pop(context);
              final barcode = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
              );

              if (barcode != null) {
                print('Scanned barcode: $barcode');
                String? productName =
                    await BarcodeService.fetchProductName(barcode);

                if (productName != null && productName.isNotEmpty) {
                  print("✅ Found product name: $productName");
                  _showManualItemEntryDialog(barcodeValue: productName);
                } else {
                  print(
                      "❌ No product name found for barcode. Allow manual entry.");
                  _showManualItemEntryDialog(barcodeValue: "Unknown Product");
                }
              }
            },
          ),
        ],
      ),
    );
  }

  void _showManualItemEntryDialog({String? barcodeValue}) async {
    String initialName = barcodeValue ?? '';
    final nameController = TextEditingController(text: initialName);
    final quantityController = TextEditingController();
    final notesController = TextEditingController();
    DateTime? boughtDate;
    DateTime? expiryDate;
    String calculatedExpiryText = "";

    // Default values for dropdowns
    String selectedCategory = "Grains & Cereals";
    String selectedCookedStatus = "Uncooked";
    String selectedSealedStatus = "Sealed";

    // Expiry values to display (from dataset.json or fallback from categories.json)
    String pantryExpiryDisplay = "Loading...";
    String fridgeExpiryDisplay = "Loading...";
    String freezeExpiryDisplay = "Loading...";

    // Dropdown options
    List<String> categoryOptions = [
      "Grains & Cereals",
      "Legumes & Beans",
      "Vegetables",
      "Fruits",
      "Meats",
      "Seafood",
      "Dairy",
      "Eggs",
      "Nuts & Seeds",
      "Breads & Bakery",
      "Oils & Fats",
      "Spices & Herbs",
      "Sauces & Condiments",
      "Processed Foods",
      "Beverages",
      "Snacks & Junk Food"
    ];

    List<String> cookedStatusOptions = ["Cooked", "Uncooked"];
    List<String> sealedStatusOptions = ["Sealed", "Opened"];

    // Ensure selected category is valid
    if (!categoryOptions.contains(selectedCategory)) {
      selectedCategory = categoryOptions[0];
    }

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            // Fetch expiry details based on the current product name and category.
            void fetchExpiry(String productName) async {
              if (productName.trim().isEmpty) return;

              final expiryDetails =
                  await ExpiryPredictionService.getExpiryDetails(
                      productName, selectedCategory);

              final bestExpiry =
                  await ExpiryPredictionService.getBestExpiryForItem(
                      productName, selectedCategory);
              final autoDays = bestExpiry['days'];
              final storage = bestExpiry['storage'];
              final DateTime previewBoughtDate = boughtDate ?? DateTime.now();
              final DateTime autoExpiryDate =
                  previewBoughtDate.add(Duration(days: autoDays));

              setStateDialog(() {
                pantryExpiryDisplay = expiryDetails["pantry"] ?? "0 days";
                fridgeExpiryDisplay = expiryDetails["fridge"] ?? "0 days";
                freezeExpiryDisplay = expiryDetails["freeze"] ?? "0 days";
                calculatedExpiryText =
                    "Expiry Date: ${autoExpiryDate.toLocal().toShortDateString()} ($storage)";
              });
            }

            // Initial check if a barcode provided a name.
            fetchExpiry(initialName);

            // Compute the best expiry if the user doesn't manually select one

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text("Add Pantry Item",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: NudePalette.darkBrown,
                  )),
              content: Container(
                width: MediaQuery.of(context).size.width * 0.95,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Item Name Field
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: "Item Name",
                          filled: true,
                          fillColor: NudePalette.paleBlush,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                                color: NudePalette.mauveBrown, width: 2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          labelStyle: TextStyle(color: NudePalette.darkBrown),
                        ),
                        onChanged: (value) {
                          fetchExpiry(value);
                        },
                      ),
                      const SizedBox(height: 10),
                      // Category Selection
                      DropdownButtonFormField<String>(
                        value: selectedCategory,
                        decoration: InputDecoration(
                          labelText: "Select Category",
                          filled: true,
                          fillColor: NudePalette.paleBlush,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                                color: NudePalette.mauveBrown, width: 2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          labelStyle: TextStyle(color: NudePalette.darkBrown),
                        ),
                        items: categoryOptions.map((String category) {
                          return DropdownMenuItem<String>(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          setStateDialog(() {
                            selectedCategory = newValue!;
                            // Re-fetch expiry based on the new category.
                            fetchExpiry(nameController.text);
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      // Cooked or Uncooked Selection
                      DropdownButtonFormField<String>(
                        value: selectedCookedStatus,
                        decoration: InputDecoration(
                          labelText: "Cooked or Uncooked",
                          filled: true,
                          fillColor: NudePalette.paleBlush,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                                color: NudePalette.mauveBrown, width: 2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          labelStyle: TextStyle(color: NudePalette.darkBrown),
                        ),
                        items: cookedStatusOptions.map((String status) {
                          return DropdownMenuItem<String>(
                            value: status,
                            child: Text(status),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          setStateDialog(() {
                            selectedCookedStatus = newValue!;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      // Sealed or Opened Selection
                      DropdownButtonFormField<String>(
                        value: selectedSealedStatus,
                        decoration: InputDecoration(
                          labelText: "Sealed or Opened",
                          filled: true,
                          fillColor: NudePalette.paleBlush,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                                color: NudePalette.mauveBrown, width: 2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          labelStyle: TextStyle(color: NudePalette.darkBrown),
                        ),
                        items: sealedStatusOptions.map((String status) {
                          return DropdownMenuItem<String>(
                            value: status,
                            child: Text(status),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          setStateDialog(() {
                            selectedSealedStatus = newValue!;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      // Quantity Field
                      TextField(
                        controller: quantityController,
                        decoration: InputDecoration(
                          labelText: "Quantity",
                          filled: true,
                          fillColor: NudePalette.paleBlush,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                                color: NudePalette.mauveBrown, width: 2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          labelStyle: TextStyle(color: NudePalette.darkBrown),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 10),
                      // Notes Field
                      TextField(
                        controller: notesController,
                        decoration: InputDecoration(
                          labelText: "Notes (Optional)",
                          filled: true,
                          fillColor: NudePalette.paleBlush,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                                color: NudePalette.mauveBrown, width: 2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          labelStyle: TextStyle(color: NudePalette.darkBrown),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Bought Date Field
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              boughtDate == null
                                  ? "No bought date chosen"
                                  : "Bought: ${boughtDate!.toLocal().toShortDateString()}",
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.calendar_today),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) {
                                setStateDialog(() => boughtDate = picked);
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Expiry Date Field (optional)
                      // Expiry Date Field (optional)
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              expiryDate == null
                                  ? calculatedExpiryText.isNotEmpty
                                      ? calculatedExpiryText
                                      : "No expiry date chosen (optional)"
                                  : "Expires: ${expiryDate!.toLocal().toShortDateString()}",
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.calendar_today),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime.now(),
                                lastDate: DateTime(DateTime.now().year + 5),
                              );
                              if (picked != null) {
                                setStateDialog(() => expiryDate = picked);
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Display expiry details (from dataset.json or category fallback)
                      Row(children: [
                        const Text("Pantry Max:",
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(pantryExpiryDisplay,
                                style: const TextStyle(color: Colors.grey))),
                      ]),
                      Row(children: [
                        const Text("Fridge Max:",
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(fridgeExpiryDisplay,
                                style: const TextStyle(color: Colors.grey))),
                      ]),
                      Row(children: [
                        const Text("Freeze Max:",
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(freezeExpiryDisplay,
                                style: const TextStyle(color: Colors.grey))),
                      ]),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  child: const Text("Cancel"),
                  onPressed: () => Navigator.pop(context),
                ),
                ElevatedButton(
                  child: const Text("Add"),
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty ||
                        boughtDate == null) return;

                    final bestExpiry =
                        await ExpiryPredictionService.getBestExpiryForItem(
                            nameController.text.trim(), selectedCategory);
                    final autoDays = bestExpiry['days'] ?? 0;

                    DateTime finalExpiry =
                        expiryDate ?? boughtDate!.add(Duration(days: autoDays));

                    final newItem = PantryItem(
                      id: '',
                      name: nameController.text.trim(),
                      boughtDate: boughtDate!,
                      expiryDate: finalExpiry,
                      createdAt: DateTime.now(),
                    );

                    _addPantryItem(newItem);
                    Navigator.pop(context);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Builds the bottom navigation bar matching your KitchenScreen.
  Widget _buildBottomNavigation() {
    return Container(
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
        currentIndex: currentBottomIndex,
        onTap: (index) {
          setState(() {
            currentBottomIndex = index;
          });

          if (index == 0) {
            Navigator.pushReplacementNamed(context, '/home');
          } else if (index == 1) {
            Navigator.pushReplacementNamed(context, '/kitchen');
          } else if (index == 2) {
            Navigator.pushReplacementNamed(context, '/medicines');
          } else if (index == 3) {
            Navigator.pushReplacementNamed(context, '/health');
          } else if (index == 4) {
            // TODO: Navigate to Feed screen
          }
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
          //BottomNavigationBarItem(
          //  icon: Icon(Icons.rss_feed),
          //  label: "Feed",
          // ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NudePalette.lightCream,
      body: SafeArea(
        child: Column(
          children: [
            // Custom white header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: NudePalette.lightCream,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  // Back icon
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
                  // Title
                  const Expanded(
                    child: Text("Add 'em, track 'em!",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: NudePalette.darkBrown,
                        )),
                  ),
                  const SizedBox(width: 48), // To balance the arrow's space
                ],
              ),
            ),

            // Search bar
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  labelText: "Search Pantry",
                  labelStyle:
                      TextStyle(color: NudePalette.darkBrown.withOpacity(0.6)),
                  prefixIcon: Icon(Icons.search, color: NudePalette.darkBrown),
                  filled: true,
                  fillColor: NudePalette.lightCream, // Match background
                  border: UnderlineInputBorder(
                    borderSide: BorderSide(
                        color: NudePalette.darkBrown.withOpacity(0.4)),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide:
                        BorderSide(color: NudePalette.mauveBrown, width: 2),
                  ),
                ),
                onChanged: (value) {
                  _applyFilter();
                },
              ),
            ),
            // List of pantry items
            Expanded(
              child: filteredItems.isEmpty
                  ? const Center(child: Text("No items in pantry"))
                  : ListView.builder(
                      itemCount: filteredItems.length,
                      itemBuilder: (context, index) {
                        PantryItem item = filteredItems[index];
                        Color textColor = _getTextColor(item);
                        return ListTile(
                          title: Text(
                            item.name,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            "Bought: ${item.boughtDate.toLocal().toShortDateString()}  -  Expires: ${item.expiryDate.toLocal().toShortDateString()}",
                            style: TextStyle(color: textColor),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.shopping_cart),
                                onPressed: () {
                                  _showAddToGroceryDialog(item);
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () {
                                  _deletePantryItem(item);
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddItemDialog,
        icon: const Icon(Icons.add),
        label: const Text("Add Item"),
        backgroundColor: NudePalette.mauveBrown, // MATCH SAVR THEME
        foregroundColor: Colors.white, // White text/icon
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }
}

/// Extension method to format DateTime into a short date string.
extension DateFormatting on DateTime {
  String toShortDateString() {
    return "${this.day}/${this.month}/${this.year}";
  }
}
