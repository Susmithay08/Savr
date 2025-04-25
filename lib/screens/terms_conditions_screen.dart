import 'package:flutter/material.dart';

class TermsConditionsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Terms & Conditions"),
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
              "Terms & Conditions",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              "Effective Date: April 11, 2025\n\nBy accessing or using the SAVR app, you agree to the following Terms and Conditions.",
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 20),
            Text(
              "1. Acceptance of Terms",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              "By using SAVR, you agree to comply with and be legally bound by these terms. If you do not agree, you may not use the app.",
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 20),
            Text(
              "2. Eligibility",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              "You must be at least 13 years old to use SAVR. By using the App, you confirm that you meet this requirement.",
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 20),
            Text(
              "3. Purpose of the App",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              "SAVR is intended for informational and lifestyle management purposes. It is not a substitute for medical advice. Consult a healthcare professional before making any health-related decisions.",
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 20),
            Text(
              "4. User Responsibilities",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              "- Ensure accuracy of all personal, health, and activity data you provide.\n"
              "- Do not upload harmful or unauthorized content.\n"
              "- Do not misuse or attempt to disrupt the normal operation of the app.",
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 20),
            Text(
              "5. User-Generated Content",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              "You retain ownership of any content you input (such as logs or notes), but you grant SAVR permission to store and display this content to operate the app effectively.",
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 20),
            Text(
              "6. Intellectual Property Rights",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              "All content, branding, design, and code in SAVR are protected by intellectual property laws. You may not copy or redistribute any portion without written consent.",
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 20),
            Text(
              "7. Feedback",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              "By submitting suggestions or feedback, you allow us to use them without compensation or obligation.",
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 20),
            Text(
              "8. Limitation of Liability",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              "SAVR is not liable for indirect, incidental, or consequential damages resulting from app usage or inability to use the app.",
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 20),
            Text(
              "9. Account Termination",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              "We reserve the right to suspend or terminate your account if you violate these terms or engage in harmful conduct.",
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 20),
            Text(
              "10. Changes to Terms",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              "These Terms may be updated periodically. Continued use of the app implies acceptance of the updated terms.",
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 20),
            Text(
              "11. Governing Law",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              "These Terms are governed by the laws of the United States, regardless of your location.",
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 20),
            Text(
              "12. Contact Us",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              "For questions regarding these Terms & Conditions, please contact us at:\nEmail: thrivewithsavr@gmail.com",
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
