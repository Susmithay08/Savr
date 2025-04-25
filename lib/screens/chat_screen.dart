import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:savr/themes/colors.dart';

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  final String apiKey = "AIzaSyDXUcPiGbY1d9yDLO2Ps_Qxd2yzxkk7HYo";

  Future<void> _sendMessage() async {
    String userMessage = _messageController.text.trim();
    if (userMessage.isEmpty) return;

    setState(() {
      _messages.add({"text": userMessage, "isUser": true});
      _messageController.clear();
    });

    await _fetchGeminiResponse(userMessage);
  }

  Future<String> _fetchGeminiResponse(String message) async {
    setState(() {
      _messages
          .add({"text": "AI is typing...", "isUser": false, "isTyping": true});
    });

    try {
      final url = Uri.parse(
        "https://generativelanguage.googleapis.com/v1/models/gemini-1.5-pro:generateContent?key=$apiKey",
      );

      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {
                  "text": """
You are the AI assistant inside the SAVR app — a health-focused mobile and web app built with Flutter and Firebase.

Your job is to help users with any feature or question related to the SAVR app.

The SAVR app helps users manage:

🥗 PANTRY & MEALS
- Track pantry items and expiry dates.
- Generate meal plans using AI based on available ingredients, allergies, preferences, and health conditions.
- Suggest recipes using pantry items or external ingredients.
- Allow users to add custom meals and assign them to specific days.
- Store categorized recipes in a Secret Recipe Vault (breakfast, lunch, dinner).
- Export meal plans to image or PDF.
- Unlock "Cheat Meals" by earning health points from daily habits.

💊 MEDICATION
- Track medication expiry and dosage schedules.
- Remind users using local notifications (daily, every 8 hrs, specific days, or monthly once).
- Let users view, edit, or delete meds.
- Track medication logs with "Taken" and "Skipped" history.
- Display weekly adherence charts (full, partial, skipped).

💧 HEALTH & FITNESS
- Track hydration and show daily reminders.
- Log sleep and display sleep hours per day.
- Use AI to generate personalized workout plans (based on goal, type, and duration).
- Allow users to complete workouts with timers, GIFs, rest screens, and log progress.
- Include fitness challenges (e.g., 30-day abs challenge) with daily progression.
- Build and check off daily healthy habits (auto-reset every night).

🧘 WELLNESS
- Generate natural home remedies using pantry ingredients based on user’s health concerns.
- Share wellness tips in a card-flip format.

📊 BEHAVIOR TRACKING & POINTS
- Track behavior logs like hydration, sleep, workout, medication, and habits.
- Award points for healthy behavior.
- Unlock cheat meals once the user earns enough points weekly.

🧑‍💼 USER SETTINGS
- Profile includes name, date of birth, height, weight, allergies, and preferences.
- Support dark mode and adjustable font sizes.
- Data is securely stored per user in Firebase.

🚨 EMERGENCY SUPPORT
- Offers emergency contact access and first-aid help.

❌ If a user asks about anything **not related to the SAVR app**, respond with:
"Sorry, I can only help with questions about the SAVR app and its features."

Stay concise, polite, and relevant.

User: $message
"""
                }
              ]
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String rawText = data["candidates"][0]["content"]["parts"][0]["text"] ??
            "I couldn't understand that.";
        String cleanText = rawText.replaceAll(RegExp(r'[\*_#]'), '').trim();

        setState(() {
          _messages.removeWhere((msg) => msg["isTyping"] == true);
          _messages.add({"text": cleanText, "isUser": false});
        });

        return cleanText;
      } else {
        setState(() {
          _messages.removeWhere((msg) => msg["isTyping"] == true);
          _messages.add({"text": "Error: ${response.body}", "isUser": false});
        });
        return "Error: ${response.body}";
      }
    } catch (e) {
      setState(() {
        _messages.removeWhere((msg) => msg["isTyping"] == true);
        _messages.add({"text": "Error: $e", "isUser": false});
      });
      return "Error: $e";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NudePalette.lightCream,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(50),
        child: AppBar(
          backgroundColor: NudePalette.lightCream,
          elevation: 0,
          iconTheme: IconThemeData(color: NudePalette.darkBrown),
          title: Text("Ask SAVR AI",
              style: TextStyle(
                color: NudePalette.darkBrown,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              )),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: false,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                bool isUser = message["isUser"] ?? false;
                bool isTyping = message["isTyping"] ?? false;

                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.8),
                    decoration: BoxDecoration(
                      color: isUser
                          ? NudePalette.mauveBrown
                          : NudePalette.sandBeige,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 6,
                          offset: Offset(0, 3),
                        )
                      ],
                    ),
                    child: isTyping
                        ? Text("AI is typing...",
                            style: TextStyle(
                                color: NudePalette.darkBrown,
                                fontStyle: FontStyle.italic))
                        : Text(
                            message["text"],
                            style: TextStyle(
                              color:
                                  isUser ? Colors.white : NudePalette.darkBrown,
                              fontSize: 15,
                            ),
                          ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: NudePalette.sandBeige.withOpacity(0.3),
              border:
                  Border(top: BorderSide(color: Colors.black12, width: 0.5)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: TextStyle(fontSize: 15),
                    decoration: InputDecoration(
                      hintText: "Ask me something...",
                      hintStyle: TextStyle(
                          color: NudePalette.darkBrown.withOpacity(0.6)),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                CircleAvatar(
                  backgroundColor: NudePalette.mauveBrown,
                  child: IconButton(
                    icon: Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
