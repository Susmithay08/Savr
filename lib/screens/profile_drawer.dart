import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:savr/providers/theme_provider.dart';
import 'package:savr/screens/login_screen.dart';
import 'package:savr/themes/colors.dart';

class ProfileDrawer extends StatefulWidget {
  const ProfileDrawer({Key? key}) : super(key: key);

  @override
  _ProfileDrawerState createState() => _ProfileDrawerState();
}

class _ProfileDrawerState extends State<ProfileDrawer> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? user = FirebaseAuth.instance.currentUser;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  final TextEditingController heightController = TextEditingController();
  final TextEditingController weightController = TextEditingController();
  final TextEditingController allergiesController = TextEditingController();
  final TextEditingController diseasesController = TextEditingController();
  final TextEditingController currentPasswordController =
      TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  bool aboutMeExpanded = false;
  bool passwordExpanded = false;
  bool appearanceExpanded = false;
  bool editingAboutMe = false;
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;

  @override
  void initState() {
    super.initState();
    loadUserData();
  }

  Future<void> loadUserData() async {
    if (user != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();
      if (userDoc.exists) {
        setState(() {
          nameController.text =
              userDoc['displayName'] ?? user?.displayName ?? '';
          ageController.text = userDoc['age']?.toString() ?? '';
          heightController.text = userDoc['height']?.toString() ?? '';
          weightController.text = userDoc['weight']?.toString() ?? '';
          allergiesController.text =
              (userDoc['allergies'] as List<dynamic>?)?.join(', ') ?? '';
          diseasesController.text =
              (userDoc['medicalConditions'] as List<dynamic>?)?.join(', ') ??
                  '';
        });
      }
    }
  }

  Future<void> updateAboutMe() async {
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .update({
        'displayName': nameController.text.trim(),
        'age': int.tryParse(ageController.text.trim()),
        'height': double.tryParse(heightController.text.trim()),
        'weight': double.tryParse(weightController.text.trim()),
        'allergies': allergiesController.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        'medicalConditions': diseasesController.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Profile updated.")));
    }
  }

  Future<void> changePassword() async {
    if (user != null && user!.email != null) {
      try {
        AuthCredential credential = EmailAuthProvider.credential(
          email: user!.email!,
          password: currentPasswordController.text.trim(),
        );
        await user!.reauthenticateWithCredential(credential);

        if (newPasswordController.text.trim() ==
            confirmPasswordController.text.trim()) {
          await user!.updatePassword(newPasswordController.text.trim());
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Password changed successfully.")));
          currentPasswordController.clear();
          newPasswordController.clear();
          confirmPasswordController.clear();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("New passwords do not match.")));
        }
      } catch (e) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: \${e.toString()}")));
      }
    }
  }

  Future<void> logout() async {
    try {
      await _auth.signOut();
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (context) => LoginScreen()));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Logout failed: \${e.toString()}")));
    }
  }

  Future<void> deleteAccount() async {
    bool confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Confirm Account Deletion"),
        content: Text(
            "Are you sure you want to delete your account? This action cannot be undone."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text("Cancel")),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text("Delete")),
        ],
      ),
    );

    if (confirmed && user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .delete();
      await user!.delete();
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (context) => LoginScreen()));
    }
  }

  String currentUserEmail() => user?.email ?? "user@example.com";

  InputDecoration _minimalInput(String label) => InputDecoration(
        labelText: label,
        border: UnderlineInputBorder(),
        filled: true,
        fillColor: NudePalette.lightCream,
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: NudePalette.darkBrown),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: NudePalette.lightCream,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(20),
          children: [
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: NudePalette.softTaupe,
                    child: Icon(Icons.person, size: 40, color: Colors.white),
                  ),
                  SizedBox(height: 10),
                  Text(
                    nameController.text,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    currentUserEmail(),
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                ],
              ),
            ),
            SizedBox(height: 30),
            ExpansionTile(
              title: Text("About Me",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              initiallyExpanded: aboutMeExpanded,
              onExpansionChanged: (val) =>
                  setState(() => aboutMeExpanded = val),
              children: [
                TextField(
                    controller: nameController,
                    decoration: _minimalInput("Name")),
                TextField(
                    controller: ageController,
                    decoration: _minimalInput("Age"),
                    keyboardType: TextInputType.number),
                Row(
                  children: [
                    Expanded(
                        child: TextField(
                            controller: heightController,
                            decoration: _minimalInput("Height (cm)"),
                            keyboardType: TextInputType.number)),
                    SizedBox(width: 10),
                    Expanded(
                        child: TextField(
                            controller: weightController,
                            decoration: _minimalInput("Weight (kg)"),
                            keyboardType: TextInputType.number)),
                  ],
                ),
                TextField(
                    controller: allergiesController,
                    decoration: _minimalInput("Allergies")),
                TextField(
                  controller: diseasesController,
                  decoration: _minimalInput("Diseases"),
                ),
                SizedBox(height: 10),
                Center(
                  child: ElevatedButton(
                    onPressed: updateAboutMe,
                    child: Text("Save"),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: NudePalette.mauveBrown,
                        foregroundColor: Colors.white),
                  ),
                ),
              ],
            ),
            ExpansionTile(
              title: Text("Change Password",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              initiallyExpanded: passwordExpanded,
              onExpansionChanged: (val) =>
                  setState(() => passwordExpanded = val),
              children: [
                Row(
                  children: [
                    Expanded(
                        child: TextField(
                            controller: currentPasswordController,
                            decoration: _minimalInput("Current Password"),
                            obscureText: true)),
                    SizedBox(width: 10),
                    Expanded(
                        child: TextField(
                            controller: newPasswordController,
                            decoration: _minimalInput("New Password"),
                            obscureText: true)),
                  ],
                ),
                TextField(
                    controller: confirmPasswordController,
                    decoration: _minimalInput("Confirm New Password"),
                    obscureText: true),
                SizedBox(height: 10),
                Center(
                  child: ElevatedButton(
                    onPressed: changePassword,
                    child: Text("Update Password"),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: NudePalette.mauveBrown,
                        foregroundColor: Colors.white),
                  ),
                ),
              ],
            ),
            ExpansionTile(
              title: Text("Appearance",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              initiallyExpanded: appearanceExpanded,
              onExpansionChanged: (val) =>
                  setState(() => appearanceExpanded = val),
              children: [
                Consumer<ThemeProvider>(
                  builder: (context, themeProvider, _) => Column(
                    children: [
                      Text(
                          "Font Size: ${themeProvider.fontSize.toStringAsFixed(0)}"),
                      Slider(
                        value: themeProvider.fontSize,
                        min: 12,
                        max: 24,
                        divisions: 6,
                        onChanged: (value) {
                          themeProvider.setFontSize(value);
                          setState(() {});
                        },
                      )
                    ],
                  ),
                )
              ],
            ),
            SizedBox(height: 20),
            Divider(),
            ListTile(
              title:
                  Text("Logout", style: TextStyle(fontWeight: FontWeight.w500)),
              onTap: logout,
            ),
            ListTile(
              title: Text("Delete Account",
                  style: TextStyle(
                      color: Colors.red, fontWeight: FontWeight.bold)),
              onTap: deleteAccount,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: NudePalette.darkBrown,
            ),
          ),
        ),
        Container(
          padding: EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 6,
                offset: Offset(0, 2),
              )
            ],
          ),
          child: content,
        )
      ],
    );
  }

  Widget _buildAboutMeSection() {
    return editingAboutMe
        ? Column(
            children: [
              _buildTextField(nameController, "Name"),
              _buildTextField(ageController, "Age", isNumber: true),
              _buildTextField(heightController, "Height (cm)", isNumber: true),
              _buildTextField(weightController, "Weight (kg)", isNumber: true),
              _buildTextField(
                  allergiesController, "Allergies (comma separated)"),
              _buildTextField(diseasesController, "Diseases (comma separated)"),
              ElevatedButton(
                onPressed: updateAboutMe,
                child: Text("Save"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: NudePalette.mauveBrown,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          )
        : ListTile(
            title: Text("Edit Profile"),
            onTap: () => setState(() => editingAboutMe = true),
          );
  }

  Widget _buildPasswordSection() {
    return Column(
      children: [
        _buildTextField(currentPasswordController, "Current Password",
            isPassword: true),
        _buildTextField(newPasswordController, "New Password",
            isPassword: true),
        _buildTextField(confirmPasswordController, "Confirm New Password",
            isPassword: true),
        ElevatedButton(
          onPressed: changePassword,
          child: Text("Update Password"),
          style: ElevatedButton.styleFrom(
            backgroundColor: NudePalette.mauveBrown,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _buildAppearanceSection() {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) => Column(
        children: [
          Text("Font Size: ${themeProvider.fontSize.toStringAsFixed(0)}"),
          Slider(
            value: themeProvider.fontSize,
            min: 12,
            max: 24,
            divisions: 6,
            onChanged: (value) {
              themeProvider.setFontSize(value);
              setState(() {}); // Forces the UI to refresh
            },
          )
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {bool isNumber = false, bool isPassword = false}) {
    bool isCurrent = label == "Current Password";
    bool isNew = label == "New Password";
    bool isConfirm = label == "Confirm New Password";

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    (isCurrent && _showCurrentPassword) ||
                            (isNew && _showNewPassword) ||
                            (isConfirm && _showConfirmPassword)
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      if (isCurrent) {
                        _showCurrentPassword = !_showCurrentPassword;
                      } else if (isNew) {
                        _showNewPassword = !_showNewPassword;
                      } else if (isConfirm) {
                        _showConfirmPassword = !_showConfirmPassword;
                      }
                    });
                  },
                )
              : null,
        ),
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        obscureText: isPassword
            ? !(isCurrent && _showCurrentPassword) &&
                !(isNew && _showNewPassword) &&
                !(isConfirm && _showConfirmPassword)
            : false,
      ),
    );
  }
}
