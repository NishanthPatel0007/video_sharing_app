// lib/main.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/dashboard_screen.dart';
import 'screens/landing_page.dart';
import 'screens/login_screen.dart';
import 'screens/payment_settings_screen.dart';
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
          primaryColor: const Color(0xFF8257E5),
          scaffoldBackgroundColor: const Color(0xFF1E1B2C),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF2D2940),
            elevation: 0,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8257E5),
              foregroundColor: Colors.white,
            ),
          ),
        ),
        initialRoute: '/',
        // Handle initial route based on URL
        onGenerateInitialRoutes: (String initialRoute) {
          final uri = Uri.parse(initialRoute);
          
          // Handle video URLs
          if (uri.path.startsWith('/v/')) {
            final videoCode = uri.path.substring(3);
            return [
              MaterialPageRoute(
                builder: (context) => PublicVideoPage(videoCode: videoCode),
              ),
            ];
          }
          
          return [
            MaterialPageRoute(
              builder: (context) => const LandingPage(),
            ),
          ];
        },
        // Define routes
        routes: {
          '/login': (context) => const LoginScreen(),
          '/dashboard': (context) => _buildProtectedRoute(const DashboardScreen()),
          '/payment-settings': (context) => _buildProtectedRoute(
            const PaymentSettingsScreen(),
          ),
        },
        // Handle dynamic routes
        onGenerateRoute: (settings) {
          final uri = Uri.parse(settings.name ?? '/');
          print('Processing route: ${uri.path}');

          // Handle video share URLs
          if (uri.path.startsWith('/v/')) {
            final videoCode = uri.path.substring(3);
            return MaterialPageRoute(
              builder: (context) => PublicVideoPage(videoCode: videoCode),
            );
          }

          // Handle query parameter video URLs
          if (uri.queryParameters.containsKey('video')) {
            return MaterialPageRoute(
              builder: (context) => PublicVideoPage(
                videoCode: uri.queryParameters['video']!,
              ),
            );
          }

          // Handle other routes
          switch (uri.path) {
            case '/':
              return MaterialPageRoute(
                builder: (context) => const LandingPage(),
              );
            case '/login':
              return MaterialPageRoute(
                builder: (context) => const LoginScreen(),
              );
            case '/dashboard':
              return MaterialPageRoute(
                builder: (context) => _buildProtectedRoute(
                  const DashboardScreen(),
                ),
              );
            case '/payment-settings':
              return MaterialPageRoute(
                builder: (context) => _buildProtectedRoute(
                  const PaymentSettingsScreen(),
                ),
              );
            default:
              return MaterialPageRoute(
                builder: (context) => const LandingPage(),
              );
          }
        },
        // Handle 404 and errors
        onUnknownRoute: (settings) {
          return MaterialPageRoute(
            builder: (context) => Scaffold(
              appBar: AppBar(
                title: const Text('Page Not Found'),
              ),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.white54,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Page not found',
                      style: TextStyle(
                        fontSize: 24,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'The page you are looking for does not exist.',
                      style: TextStyle(
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, '/');
                      },
                      child: const Text('Go Home'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProtectedRoute(Widget child) {
    return Consumer<AuthService>(
      builder: (context, auth, _) {
        if (!auth.isLoggedIn) {
          return const LoginScreen();
        }
        return child;
      },
    );
  }
}