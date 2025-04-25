import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:savr/screens/home_screen.dart';
import 'saved_lists_screen.dart' hide SavedList;
import 'kitchen_screen.dart';
import 'package:savr/themes/colors.dart';

/// Data model for a grocery item.
class GroceryItem {
  String id;
  String name;
  String quantity;

  GroceryItem({
    required this.id,
    required this.name,
    required this.quantity,
  });

  factory GroceryItem.fromDocument(DocumentSnapshot doc) {
    return GroceryItem(
      id: doc.id,
      name: doc['name'] ?? '',
      quantity: doc['quantity'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'quantity': quantity,
    };
  }
}

/// Data model for a saved list.
class SavedList {
  String id;
  String name;
  SavedList({required this.id, required this.name});
  factory SavedList.fromDocument(DocumentSnapshot doc) {
    return SavedList(
      id: doc.id,
      name: doc['name'] ?? '',
    );
  }
  Map<String, dynamic> toMap() {
    return {
      'name': name,
    };
  }
}

class GroceryScreen extends StatefulWidget {
  const GroceryScreen({Key? key}) : super(key: key);

  @override
  _GroceryScreenState createState() => _GroceryScreenState();
}

class _GroceryScreenState extends State<GroceryScreen> {
  List<GroceryItem> groceryItems = [];
  List<GroceryItem> filteredItems = [];
  TextEditingController searchController = TextEditingController();

  int currentBottomIndex = 1;

  @override
  void initState() {
    super.initState();
    _fetchGroceryItems();
  }

  Future<void> _clearGroceryItems() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .collection("groceryItems")
          .get();

      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }

      setState(() {
        groceryItems.clear();
        filteredItems.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All grocery items cleared.")),
      );
    } catch (e) {
      print("Error clearing grocery items: $e");
    }
  }

  Future<void> _fetchGroceryItems() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .collection("groceryItems")
          .get();
      List<GroceryItem> items =
          snapshot.docs.map((doc) => GroceryItem.fromDocument(doc)).toList();
      setState(() {
        groceryItems = items;
        _applyFilter();
      });
    } catch (e) {
      print("Error fetching grocery items: $e");
    }
  }

  Future<void> _addGroceryItem(GroceryItem item) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .collection("groceryItems")
          .add(item.toMap());
      _fetchGroceryItems();
    } catch (e) {
      print("Error adding grocery item: $e");
    }
  }

  Future<void> _deleteGroceryItem(GroceryItem item) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .collection("groceryItems")
          .doc(item.id)
          .delete();
      _fetchGroceryItems();
    } catch (e) {
      print("Error deleting grocery item: $e");
    }
  }

  void _applyFilter() {
    String query = searchController.text.toLowerCase();
    List<GroceryItem> temp = groceryItems
        .where((item) => item.name.toLowerCase().contains(query))
        .toList();
    setState(() {
      filteredItems = temp;
    });
  }

  void _showAddItemDialog() async {
    final nameController = TextEditingController();
    final quantityController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Add Grocery Item"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Item Name"),
              ),
              TextField(
                controller: quantityController,
                decoration: const InputDecoration(
                    labelText: "Quantity (e.g. 1 lb, 1 pack)"),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              child: const Text("Add"),
              onPressed: () {
                if (nameController.text.trim().isEmpty ||
                    quantityController.text.trim().isEmpty) return;
                final newItem = GroceryItem(
                  id: '',
                  name: nameController.text.trim(),
                  quantity: quantityController.text.trim(),
                );
                _addGroceryItem(newItem);
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  /// Fetch saved lists for the current user.
  Future<List<SavedList>> _fetchSavedLists() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];
    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .collection("savedLists")
        .get();
    return snapshot.docs.map((doc) => SavedList.fromDocument(doc)).toList();
  }

  /// Create a new saved list with the provided name.
  Future<String?> _createSavedList(String name) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    DocumentReference ref = await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .collection("savedLists")
        .add({'name': name});
    return ref.id;
  }

  /// Add an item to the specified saved list.
  Future<void> _addItemToSavedList(GroceryItem item, String savedListId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .collection("savedLists")
          .doc(savedListId)
          .collection("items")
          .add(item.toMap());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Item added to saved list")),
      );
    } catch (e) {
      print("Error adding item to saved list: $e");
    }
  }

  /// Show dialog to choose or create a saved list for the given item.
  void _showSavedListSelectionDialog(GroceryItem item) async {
    List<SavedList> savedLists = await _fetchSavedLists();
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Select Saved List"),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                ...savedLists.map((list) => ListTile(
                      title: Text(list.name),
                      onTap: () {
                        Navigator.pop(context);
                        _addItemToSavedList(item, list.id);
                      },
                    )),
                ListTile(
                  leading: const Icon(Icons.add),
                  title: const Text("Create New List"),
                  onTap: () async {
                    Navigator.pop(context);
                    _showCreateNewSavedListDialog(item);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Dialog to create a new saved list and then add the item.
  void _showCreateNewSavedListDialog(GroceryItem item) async {
    final listNameController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Create New Saved List"),
          content: TextField(
            controller: listNameController,
            decoration: const InputDecoration(labelText: "List Name"),
          ),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              child: const Text("Create"),
              onPressed: () async {
                if (listNameController.text.trim().isEmpty) return;
                String? newListId =
                    await _createSavedList(listNameController.text.trim());
                if (newListId != null) {
                  Navigator.pop(context);
                  _addItemToSavedList(item, newListId);
                }
              },
            ),
          ],
        );
      },
    );
  }

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
          } // else if (index == 4) {
          // Navigator.pushReplacementNamed(context, '/feed');
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
          //),
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
            // Header with title, description, and refresh button.
            // Header with back icon, title, description, and refresh/clear buttons.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: NudePalette.lightCream,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back icon
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.black),
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const KitchenScreen()),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "Grocery List",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: NudePalette.darkBrown,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      "This page displays your grocery items and saved lists. Use the button below to refresh the list.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF3A2D28), // Or NudePalette.darkBrown
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: _fetchGroceryItems,
                        child: const Text(
                          "Refresh Page",
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                      const SizedBox(width: 20),
                      TextButton(
                        onPressed: _clearGroceryItems,
                        child: const Text(
                          "Clear Items",
                          style: TextStyle(fontSize: 16, color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Search bar.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Search Grocery List",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: "Type to search...",
                      filled: true,
                      fillColor: NudePalette.lightCream,
                      prefixIcon:
                          Icon(Icons.search, color: NudePalette.darkBrown),
                      border: UnderlineInputBorder(
                        borderSide: BorderSide(
                            color: NudePalette.darkBrown.withOpacity(0.4)),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide:
                            BorderSide(color: NudePalette.mauveBrown, width: 2),
                      ),
                      hintStyle: TextStyle(
                          color: NudePalette.darkBrown.withOpacity(0.5)),
                    ),
                    style: TextStyle(color: NudePalette.darkBrown),
                    onChanged: (value) {
                      _applyFilter();
                    },
                  ),
                ],
              ),
            ),

            // List of grocery items (without RefreshIndicator).
            Expanded(
              child: filteredItems.isEmpty
                  ? const Center(child: Text("No items in grocery list"))
                  : ListView.builder(
                      itemCount: filteredItems.length,
                      itemBuilder: (context, index) {
                        GroceryItem item = filteredItems[index];
                        return ListTile(
                          title: Text(
                            item.name,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text("Quantity: ${item.quantity}"),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Checkbox for removal.
                              Checkbox(
                                value: false,
                                onChanged: (bool? value) {
                                  if (value == true) {
                                    _deleteGroceryItem(item);
                                  }
                                },
                              ),
                              // Heart icon for adding to saved list.
                              IconButton(
                                icon: const Icon(Icons.favorite_border),
                                onPressed: () {
                                  _showSavedListSelectionDialog(item);
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
      // Floating action buttons.
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: "addItemFAB",
            onPressed: _showAddItemDialog,
            icon: const Icon(Icons.add),
            label: const Text("Add Item"),
            backgroundColor: NudePalette.mauveBrown,
            foregroundColor: Colors.white,
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: "savedListFAB",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const SavedListsScreen()),
              );
            },
            icon: const Icon(Icons.save),
            label: const Text("Saved List"),
            backgroundColor: NudePalette.mauveBrown,
            foregroundColor: Colors.white,
          ),
        ],
      ),

      bottomNavigationBar: _buildBottomNavigation(),
    );
  }
}
