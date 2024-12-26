// main.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/dashboard_screen.dart';
import 'screens/landing_page.dart';
import 'screens/login_screen.dart';
import 'screens/public_player_screen.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyDC2U3n6TFc0QIlAp6e64PJjVnPYhdb8qI",
      authDomain: "latestuploadvideo.firebaseapp.com",
      projectId: "latestuploadvideo",
      storageBucket: "latestuploadvideo.firebasestorage.app",
      messagingSenderId: "373248236240",
      appId: "1:373248236240:web:e47887865d55d0a0bfdcd5",
      measurementId: "G-KXQVNS2Q9P"
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'For10Cloud',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          brightness: Brightness.light,
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => const LandingPage(),
          '/login': (context) => const LoginScreen(),
          '/dashboard': (context) => _buildProtectedRoute(const DashboardScreen()),
        },
        onGenerateRoute: (settings) {
          final path = settings.name ?? '/';
          print('Processing route: $path');

          // Handle video share URLs
          if (path.startsWith('/v/')) {
            final code = path.substring(3);
            return MaterialPageRoute(
              builder: (context) => PublicVideoPage(videoCode: code),
            );
          }
          return null;
        },
      ),
    );
  }

  Widget _buildProtectedRoute(Widget child) {
    return Consumer<AuthService>(
      builder: (context, auth, _) {
        if (auth.currentUser == null) {
          return const LoginScreen();
        }
        return child;
      },
    );
  }
}