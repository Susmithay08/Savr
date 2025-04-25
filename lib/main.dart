import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:savr/providers/theme_provider.dart';
import 'themes/nude_theme.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb

// ✅ Screens
import 'screens/splash_screen.dart';
import 'screens/start_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/name_input_screen.dart';
import 'screens/final_message_screen.dart';
import 'screens/details_screen.dart';
import 'screens/ideal_screen.dart';
import 'screens/diet_screen.dart';
import 'screens/allergy_screen.dart';
import 'screens/disease_screen.dart';
import 'screens/privacy_screen.dart';
import 'screens/create_screen.dart';
import 'screens/home_screen.dart';
import 'screens/processing_screen.dart';
import 'screens/goal_selection_screen.dart';
import 'screens/reason_selection_screen.dart';
import 'screens/point_screen.dart';
import 'package:savr/health/health_screen.dart';
import 'kitchen/kitchen_screen.dart';
import 'medicine/medicines_screen.dart';

// ✅ Local Notifications Plugin (Global)
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// ✅ Background notification handler (must be top-level)
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("📩 Background message: ${message.notification?.title}");
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Timezones for scheduled notifications
  tz.initializeTimeZones();

  // ✅ Firebase Init
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    print('Firebase already initialized: $e');
  }

  if (!kIsWeb) {
    FirebaseMessaging.instance.subscribeToTopic("all");
  }

  // ✅ Register Background Handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // ✅ Notification Service Init (after Firebase is ready)
  //await NotificationService.initialize();

  const AndroidInitializationSettings androidInit =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  final InitializationSettings initSettings =
      InitializationSettings(android: androidInit);
  await flutterLocalNotificationsPlugin.initialize(initSettings);

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider()..loadPreferences(),
      child: const SavrApp(),
    ),
  );
}

class SavrApp extends StatelessWidget {
  const SavrApp();

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SAVR',
      theme: nudeTheme.copyWith(
        textTheme: Theme.of(context).textTheme.apply(
              fontSizeFactor: themeProvider.fontSize / 16.0,
            ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => SplashScreen(),
        '/start': (context) => StartScreen(),
        '/onboarding': (context) => OnboardingScreen(),
        '/name_input': (context) => NameInputScreen(),
        '/final_message': (context) =>
            FinalMessageScreen(userName: "User", goal: "Default Goal"),
        '/details': (context) =>
            DetailsScreen(userName: "User", goal: "Default Goal"),
        '/ideal': (context) => IdealScreen(),
        '/diet': (context) => DietScreen(),
        '/allergy': (context) => AllergyScreen(),
        '/disease': (context) => DiseaseScreen(),
        '/privacy': (context) => PrivacyScreen(),
        '/create': (context) => CreateScreen(),
        '/home': (context) => HomeScreen(),
        '/processing': (context) => ProcessingScreen(),
        '/points': (context) => PointScreen(),
        '/kitchen': (context) => KitchenScreen(),
        '/medicines': (context) => MedicinesScreen(),
        '/health': (context) => HealthScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/goal_selection') {
          final args = settings.arguments as Map<String, String>;
          return MaterialPageRoute(
            builder: (context) =>
                GoalSelectionScreen(userName: args['userName']!),
          );
        }
        if (settings.name == '/reason_selection') {
          final args = settings.arguments as Map<String, String>;
          return MaterialPageRoute(
            builder: (context) => ReasonSelectionScreen(
              userName: args['userName']!,
              goal: args['goal']!,
            ),
          );
        }
        return null;
      },
    );
  }
}
