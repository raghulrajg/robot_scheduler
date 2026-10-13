import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens.dart';

void main() async {
  // Ensure background native channels are ready for SharedPreferences
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load saved users from disk before starting the app
  await MockDatabase.init();
  
  runApp(
    const RobotFleetApp()
  );
}

// --- Global Core State & Configuration ---
class MockDatabase {
  // Simulates an edge database storing local operator credentials
  static Map<String, Map<String, String>> users = {};
  
  // The secure Admin Secret Key tied to your Google Authenticator setup
  static const String adminSecretKey = "YBSKVOYLEQPCELN424U5FGCJTBNYPKDU";
  
  // Key for local storage
  static const String _storageKey = 'operator_users';

  // 1. Initialize from local storage
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final String? storedData = prefs.getString(_storageKey);
    
    if (storedData != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(storedData);
        decoded.forEach((key, value) {
          users[key] = Map<String, String>.from(value as Map);
        });
      } catch (e) {
        debugPrint("Error parsing local database storage: $e");
      }
    }
  }

  // 2. Save user to disk dynamically
  static Future<void> saveUser(String username, Map<String, String> userData) async {
    users[username] = userData;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(users));
  }
}

// --- MQTT broker configuration ---
// Replaces the old rosbridge WebSocket setup (ws://<ip>:9090 with rosbridge
// "op": "advertise"/"publish" envelopes). The app now speaks plain MQTT
// directly to the broker on its normal port -- same broker, same
// hmi/user_prompt topic, that reasoning_agent.py already subscribes to.
class MqttConfig {
  static const String brokerHost = "172.25.200.57";
  static const int brokerPort = 1883;
  static const String username = "raghulrajg";
  static const String password = "Gr2_nemam";
  static const String promptTopic = "hmi/user_prompt";
}

class RobotFleetApp extends StatelessWidget {
  const RobotFleetApp({super.key});

  // Global notifier to handle theme state transitions dynamically across all screens
  static final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        return MaterialApp(
          title: 'Fleet Scheduler',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          // Industrial Light Theme Config
          theme: ThemeData(
            brightness: Brightness.light,
            primarySwatch: Colors.blue,
            scaffoldBackgroundColor: Colors.grey[100],
            appBarTheme: const AppBarTheme(backgroundColor: Colors.blue, foregroundColor: Colors.white),
            inputDecorationTheme: const InputDecorationTheme(
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
            ),
          ),
          // Industrial Dark Theme Config
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primarySwatch: Colors.blue,
            scaffoldBackgroundColor: const Color(0xFF121212),
            appBarTheme: AppBarTheme(backgroundColor: Colors.grey[900], foregroundColor: Colors.white),
            inputDecorationTheme: const InputDecorationTheme(
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.black26,
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
            ),
          ),
          home: const LoginScreen(),
        );
      },
    );
  }
}