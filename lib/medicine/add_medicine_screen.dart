import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:savr/screens/home_screen.dart';
import 'package:savr/kitchen/kitchen_screen.dart';
import 'package:savr/medicine/medicines_screen.dart';
import 'package:savr/themes/colors.dart';

/// Data model for a medicine item.
class MedicineItem {
  String id;
  String name;
  DateTime boughtDate;
  DateTime expiryDate;
  DateTime createdAt;

  MedicineItem({
    required this.id,
    required this.name,
    required this.boughtDate,
    required this.expiryDate,
    required this.createdAt,
  });

  factory MedicineItem.fromDocument(DocumentSnapshot doc) {
    return MedicineItem(
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

class AddMedicineScreen extends StatefulWidget {
  const AddMedicineScreen({Key? key}) : super(key: key);

  @override
  _AddMedicineScreenState createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends State<AddMedicineScreen> {
  List<MedicineItem> medicineItems = [];
  List<MedicineItem> filteredItems = [];
  TextEditingController searchController = TextEditingController();
  int currentBottomIndex = 2;

  @override
  void initState() {
    super.initState();
    _fetchMedicineItems();
    searchController.addListener(_applyFilter);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NudePalette.lightCream,
      appBar: AppBar(
        backgroundColor: NudePalette.lightCream,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: NudePalette.darkBrown),
          onPressed: () {
            Navigator.pop(context); // ⬅️ Back to MedicinesScreen
          },
        ),
        title: Text(
          "Your Medicines",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: NudePalette.darkBrown,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  labelText: "Search Medicines",
                  labelStyle:
                      TextStyle(color: NudePalette.darkBrown.withOpacity(0.6)),
                  prefixIcon: Icon(Icons.search, color: NudePalette.darkBrown),
                  filled: true,
                  fillColor: NudePalette.paleBlush,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: NudePalette.mauveBrown, width: 2),
                  ),
                ),
              ),
            ),
            Expanded(
              child: filteredItems.isEmpty
                  ? const Center(child: Text("No medicines added yet"))
                  : ListView.builder(
                      itemCount: filteredItems.length,
                      itemBuilder: (context, index) {
                        MedicineItem item = filteredItems[index];
                        Color textColor = _getTextColor(item);
                        return ListTile(
                          title: Text(
                            item.name,
                            style: TextStyle(
                                color: textColor, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            "Bought: ${item.boughtDate.toShortDateString()}  -  Expiry: ${item.expiryDate.toShortDateString()}",
                            style: TextStyle(color: textColor),
                          ),
                          onTap: () => _showMedicineDetailsPopup(item),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit,
                                    color: Color.fromARGB(255, 5, 5, 5)),
                                onPressed: () => _showEditMedicineDialog(item),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete,
                                    color: Color.fromARGB(255, 5, 5, 5)),
                                onPressed: () => _deleteMedicineItem(item),
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
        onPressed: _showAddMedicineDialog,
        icon: const Icon(Icons.add),
        label: const Text("Add Your Medicine"),
        backgroundColor: NudePalette.mauveBrown,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Color _getTextColor(MedicineItem item) {
    DateTime now = DateTime.now();
    if (item.expiryDate.isBefore(now)) {
      return Colors.red; // Expired
    } else if (item.expiryDate.isBefore(now.add(const Duration(days: 3)))) {
      return Colors.orange; // Expiring soon
    } else {
      return Colors.green; // Fresh
    }
  }

  void _showMedicineDetailsPopup(MedicineItem item) async {
    var medicineDetails =
        //await MedicineApiService().fetchMedicineDetails(item.name);

        showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(item.name,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            // ✅ Wrap with scroll view
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // _infoRow("Ingredients:", medicineDetails?['ingredients']),
                //_infoRow("Uses:", medicineDetails?['uses']),
                //_infoRow("Side Effects:", medicineDetails?['sideEffects']),
                //_infoRow("Alternatives:", medicineDetails?['alternatives']),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text("Close"),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        );
      },
    );
  }

  Widget _infoRow(String title, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Text(
        "$title ${value ?? 'Not Available'}",
        style: const TextStyle(fontSize: 14),
      ),
    );
  }

  void _showAddMedicineDialog() async {
    String medicineName = "";
    DateTime? boughtDate;
    DateTime? expiryDate;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Add Your Medicine",
              style: TextStyle(
                color: NudePalette.darkBrown,
                fontWeight: FontWeight.bold,
              )),
          content: StatefulBuilder(
            builder: (context, setStateDialog) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: InputDecoration(
                      labelText: "Medicine Name",
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
                    onChanged: (value) {
                      medicineName = value;
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          boughtDate == null
                              ? "No bought date chosen"
                              : "Bought: ${boughtDate!.toShortDateString()}",
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          expiryDate == null
                              ? "No expiry date chosen"
                              : "Expires: ${expiryDate!.toShortDateString()}",
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
                ],
              );
            },
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
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text("Add"),
              onPressed: () {
                if (medicineName.isEmpty ||
                    boughtDate == null ||
                    expiryDate == null) return;

                final newItem = MedicineItem(
                  id: '',
                  name: medicineName,
                  boughtDate: boughtDate!,
                  expiryDate: expiryDate!,
                  createdAt: DateTime.now(),
                );

                _addMedicineItem(newItem);
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildBottomNavigation() {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      backgroundColor: NudePalette.darkBrown,
      selectedItemColor: NudePalette.lightCream,
      unselectedItemColor: NudePalette.lightCream.withOpacity(0.6),
      currentIndex: currentBottomIndex,
      onTap: (index) {
        setState(() => currentBottomIndex = index);

        switch (index) {
          case 0:
            Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (context) => HomeScreen()));
            break;
          case 1:
            Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (context) => KitchenScreen()));
            break;
          case 2:
            Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (context) => MedicinesScreen()));
            break;
          case 3:
            Navigator.pushReplacementNamed(context, '/health');
            break;
          case 4:
            Navigator.pushReplacementNamed(context, '/feed');
            break;
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
        BottomNavigationBarItem(icon: Icon(Icons.kitchen), label: "Kitchen"),
        BottomNavigationBarItem(
            icon: Icon(Icons.medical_services), label: "Medicines"),
        BottomNavigationBarItem(icon: Icon(Icons.favorite), label: "Health"),
        //BottomNavigationBarItem(icon: Icon(Icons.rss_feed), label: "Feed"),
      ],
    );
  }

  Future<void> _fetchMedicineItems() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .collection("medicines") // ✅ Correct path
          .orderBy('createdAt', descending: true)
          .get();

      List<MedicineItem> items =
          snapshot.docs.map((doc) => MedicineItem.fromDocument(doc)).toList();

      setState(() {
        medicineItems = items;
        _applyFilter();
      });
    } catch (e) {
      print("🔥 Error fetching medicine items: $e");
    }
  }

  void _applyFilter() {
    String query = searchController.text.toLowerCase();
    List<MedicineItem> temp = medicineItems
        .where((item) => item.name.toLowerCase().contains(query))
        .toList();

    // ✅ Sorting: Expired first, Expiring Soon second, Fresh last
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

  /// ✅ Returns expiry status for sorting:
  /// 0 = Expired, 1 = Expiring Soon (within 3 days), 2 = Fresh
  int _getExpiryStatus(MedicineItem item) {
    DateTime now = DateTime.now();
    if (item.expiryDate.isBefore(now)) {
      return 0;
    } else if (item.expiryDate.isBefore(now.add(const Duration(days: 3)))) {
      return 1;
    } else {
      return 2;
    }
  }

  Future<void> _addMedicineItem(MedicineItem item) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .collection("medicines") // ✅ Ensure this is the correct path
          .add(item.toMap());

      _fetchMedicineItems();
    } catch (e) {
      print("Error adding medicine item: $e");
    }
  }

  Future<void> _deleteMedicineItem(MedicineItem item) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .collection("medicines")
          .where("name", isEqualTo: item.name) // ✅ Find document by name
          .get();

      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }

      _fetchMedicineItems();
    } catch (e) {
      print("🔥 Error deleting medicine item: $e");
    }
  }

  void _showEditMedicineDialog(MedicineItem item) async {
    String medicineName = item.name;
    DateTime? boughtDate = item.boughtDate;
    DateTime? expiryDate = item.expiryDate;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Edit Medicine"),
          content: StatefulBuilder(
            builder: (context, setStateDialog) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: TextEditingController(text: medicineName),
                    decoration: InputDecoration(
                      labelText: "Medicine Name",
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
                    onChanged: (value) {
                      medicineName = value;
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          boughtDate == null
                              ? "No bought date chosen"
                              : "Bought: ${boughtDate!.toShortDateString()}",
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.calendar_today),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: boughtDate ?? DateTime.now(),
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          expiryDate == null
                              ? "No expiry date chosen"
                              : "Expires: ${expiryDate!.toShortDateString()}",
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.calendar_today),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: expiryDate ?? DateTime.now(),
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
                ],
              );
            },
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
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text("Save"),
              onPressed: () async {
                if (medicineName.isEmpty ||
                    boughtDate == null ||
                    expiryDate == null) return;

                final user = FirebaseAuth.instance.currentUser;
                if (user == null) return;

                try {
                  await FirebaseFirestore.instance
                      .collection("users")
                      .doc(user.uid)
                      .collection("medicines")
                      .doc(item.id)
                      .update({
                    'name': medicineName,
                    'boughtDate': Timestamp.fromDate(boughtDate!),
                    'expiryDate': Timestamp.fromDate(expiryDate!),
                  });

                  _fetchMedicineItems();
                  Navigator.pop(context);
                } catch (e) {
                  print("Error updating medicine: $e");
                }
              },
            ),
          ],
        );
      },
    );
  }
}

/// ✅ Extension method to format DateTime into a short date string.
extension DateFormatting on DateTime {
  String toShortDateString() {
    return "${this.day}/${this.month}/${this.year}";
  }
}
