
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/incident_provider.dart';
import 'widgets/auth_wrapper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables.
  await dotenv.load(fileName: '.env');

  // Initialize Firebase.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Supabase with Firebase Authentication.
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    publishableKey: dotenv.env['SUPABASE_PUBLISHABLE_KEY']!,
    accessToken: () async {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        return null;
      }

      return await user.getIdToken();
    },
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => IncidentProvider(),
      child: const CampusCareApp(),
    ),
  );
}

class CampusCareApp extends StatelessWidget {
  const CampusCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ALU Campus Care',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8544C4),
        ),
        scaffoldBackgroundColor: const Color(0xFFFFFAFF),
      ),
      home: const AuthWrapper(),
    );
  }
}
