import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Privacy Policy"),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Privacy Policy",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              "Effective Date: April 11, 2025",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 20),
            Text(
              "1. Introduction",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              "SAVR (\"we,\" \"our,\" or \"us\") is committed to protecting your privacy. "
              "This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our mobile application (the \"App\").",
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 20),
            Text(
              "2. Information We Collect",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              "- Personal Information: name, email, age, gender, height, weight, diet preferences.\n"
              "- Health and Activity Data: food intake, water consumption, wellness logs.\n"
              "- Device and Usage Data: model, OS, IP address, session duration, feature usage.\n"
              "- Analytics: We use tools like Firebase/Google Analytics.\n"
              "- Push Notifications: Used for reminders; can be disabled via device settings.",
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 20),
            Text(
              "3. How We Use Your Information",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              "We use the collected data to personalize your experience, improve features, send reminders, provide support, and enhance app performance.",
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 20),
            Text(
              "4. Sharing of Your Information",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              "We do not sell your personal data. We may share data:\n"
              "- With trusted third-party providers under confidentiality\n"
              "- To comply with legal obligations\n"
              "- With your consent when explicitly given",
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 20),
            Text(
              "5. Data Retention and Security",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              "We store your data securely as long as needed to provide services or comply with regulations. While we employ strict security protocols, no method is 100% secure.",
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 20),
            Text(
              "6. Data Storage Location",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              "Data may be stored on secure servers in the United States or other jurisdictions depending on your location and usage.",
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 20),
            Text(
              "7. Your Rights",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              "You may have the right to access, correct, delete your data, object to processing, or withdraw consent. To exercise your rights, email us at thrivewithsavr@gmail.com.",
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 20),
            Text(
              "8. Children’s Privacy",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              "SAVR is not intended for children under 13. We do not knowingly collect personal information from users under this age.",
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 20),
            Text(
              "9. Changes to This Policy",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              "We may update this Privacy Policy from time to time. Material changes will be communicated through the app.",
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 20),
            Text(
              "10. Contact Us",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              "For any questions, concerns, or requests related to this Privacy Policy, please contact us at:\nEmail: thrivewithsavr@gmail.com",
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
