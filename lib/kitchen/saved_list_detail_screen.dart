import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'grocery_screen.dart' show GroceryItem;
import 'saved_lists_screen.dart' show SavedList;

class SavedListDetailScreen extends StatefulWidget {
  final SavedList savedList;
  const SavedListDetailScreen({Key? key, required this.savedList})
      : super(key: key);

  @override
  _SavedListDetailScreenState createState() => _SavedListDetailScreenState();
}

class _SavedListDetailScreenState extends State<SavedListDetailScreen> {
  List<GroceryItem> savedItems = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSavedItems();
  }

  Future<void> _fetchSavedItems() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .collection("savedLists")
        .doc(widget.savedList.id)
        .collection("items")
        .get();
    setState(() {
      savedItems =
          snapshot.docs.map((doc) => GroceryItem.fromDocument(doc)).toList();
      isLoading = false;
    });
  }

  Future<void> _addSavedItemsToGrocery() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    for (var item in savedItems) {
      await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .collection("groceryItems")
          .add(item.toMap());
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Items added to grocery list")),
    );
  }

  Future<void> _deleteSavedItem(GroceryItem item) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .collection("savedLists")
        .doc(widget.savedList.id)
        .collection("items")
        .doc(item.id)
        .delete();
    _fetchSavedItems();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.savedList.name),
        // Replace the text button with a plus IconButton.
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addSavedItemsToGrocery,
            tooltip: "Add All Items to Grocery List",
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : savedItems.isEmpty
              ? const Center(child: Text("No items in this saved list"))
              : ListView.builder(
                  itemCount: savedItems.length,
                  itemBuilder: (context, index) {
                    final item = savedItems[index];
                    return ListTile(
                      title: Text(item.name),
                      subtitle: Text("Quantity: ${item.quantity}"),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          _deleteSavedItem(item);
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
