import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uni_links/uni_links.dart';

import 'screens/dashboard_screen.dart';
import 'screens/landing_page.dart';
import 'services/auth_service.dart';
import 'services/url_handler_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyDC2U3n6TFc0QIlAp6e64PJjVnPYhdb8qI",
      authDomain: "latestuploadvideo.firebaseapp.com",
      projectId: "latestuploadvideo",
      storageBucket: "latestuploadvideo.appspot.com",
      messagingSenderId: "373248236240",
      appId: "1:373248236240:web:e47887865d55d0a0bfdcd5",
      measurementId: "G-KXQVNS2Q9P",
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _urlHandler = UrlHandlerService();
  Widget? _initialScreen;

  @override
  void initState() {
    super.initState();
    _handleInitialUrl();
    _handleIncomingLinks();
  }

  Future<void> _handleInitialUrl() async {
    try {
      final initialUrl = await getInitialLink();
      if (initialUrl != null) {
        final screen = await _urlHandler.handleUrl(initialUrl);
        setState(() => _initialScreen = screen);
      }
    } catch (e) {
      debugPrint('Error handling initial url: $e');
    }
  }

  void _handleIncomingLinks() {
    linkStream.listen(
      (String? url) async {
        if (url != null && mounted) {
          try {
            final screen = await _urlHandler.handleUrl(url);
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => screen),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to open link: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
      },
      onError: (err) {
        debugPrint('Link handling error: $err');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to process link'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
      ],
      child: MaterialApp(
        title: 'For10Cloud',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          primaryColor: Colors.blue,
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF121212),
            elevation: 0,
          ),
          scaffoldBackgroundColor: const Color(0xFF121212),
        ),
        home: _initialScreen ?? StreamBuilder(
          stream: AuthService().authStateChanges,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            return snapshot.hasData ? const DashboardScreen() : const LandingPage();
          },
        ),
      ),
    );
  }
}