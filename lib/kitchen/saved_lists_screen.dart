import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'saved_list_detail_screen.dart';

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

class SavedListsScreen extends StatefulWidget {
  const SavedListsScreen({Key? key}) : super(key: key);

  @override
  _SavedListsScreenState createState() => _SavedListsScreenState();
}

class _SavedListsScreenState extends State<SavedListsScreen> {
  List<SavedList> savedLists = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSavedLists();
  }

  Future<void> _fetchSavedLists() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .collection("savedLists")
        .get();
    setState(() {
      savedLists =
          snapshot.docs.map((doc) => SavedList.fromDocument(doc)).toList();
      isLoading = false;
    });
  }

  Future<void> _deleteSavedList(String listId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .collection("savedLists")
        .doc(listId)
        .delete();
    _fetchSavedLists();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Saved Lists"),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : savedLists.isEmpty
              ? const Center(child: Text("No saved lists"))
              : ListView.builder(
                  itemCount: savedLists.length,
                  itemBuilder: (context, index) {
                    final list = savedLists[index];
                    return ListTile(
                      title: Text(list.name),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          _deleteSavedList(list.id);
                        },
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  SavedListDetailScreen(savedList: list)),
                        );
                      },
                    );
                  },
                ),
    );
  }
}
