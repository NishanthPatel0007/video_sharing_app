import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/video.dart';
import 'screens/dashboard_screen.dart';
import 'screens/landing_screen.dart';  // New import
import 'screens/login_screen.dart';
import 'screens/player_screen.dart';
import 'services/auth_service.dart';
import 'services/video_url_service.dart';

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
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 1,
          ),
        ),
        home: const AppEntryPoint(),
        onGenerateRoute: (settings) {
          // Extract video code from the URL path
          final uri = Uri.parse(settings.name ?? '');
          final pathSegments = uri.pathSegments;
          
          if (pathSegments.isNotEmpty) {
            final potentialVideoCode = pathSegments.last;
            // Check if it's a 6-character video code
            if (potentialVideoCode.length == 6) {
              return MaterialPageRoute(
                builder: (context) => TransitionPage(videoCode: potentialVideoCode),
              );
            }
          }
          return null;
        },
      ),
    );
  }
}

class AppEntryPoint extends StatefulWidget {
  const AppEntryPoint({Key? key}) : super(key: key);

  @override
  State<AppEntryPoint> createState() => _AppEntryPointState();
}

class _AppEntryPointState extends State<AppEntryPoint> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snapshot.hasData ? const DashboardScreen() : const LandingScreen();
      },
    );
  }
}

class TransitionPage extends StatefulWidget {
  final String videoCode;

  const TransitionPage({Key? key, required this.videoCode}) : super(key: key);

  @override
  State<TransitionPage> createState() => _TransitionPageState();
}

class _TransitionPageState extends State<TransitionPage> {
  bool _showPlayer = false;
  Video? _video;

  @override
  void initState() {
    super.initState();
    _loadVideo();
  }

  Future<void> _loadVideo() async {
    try {
      final videoUrlService = VideoUrlService();
      final videoId = await videoUrlService.getVideoId(widget.videoCode);
      
      if (videoId != null) {
        final doc = await FirebaseFirestore.instance
            .collection('videos')
            .doc(videoId)
            .get();

        if (doc.exists) {
          setState(() => _video = Video.fromFirestore(doc));
          // Wait for 2 seconds then show the video player
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) {
            setState(() => _showPlayer = true);
          }
        }
      }
    } catch (e) {
      print('Error loading video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading video: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showPlayer && _video != null) {
      return PlayerScreen(video: _video!);
    }

    // Show landing page with loading indicator
    return LandingScreen(
      isTransitioning: true,
      transitionMessage: _video != null 
          ? 'Loading video: ${_video!.title}'
          : 'Loading video...',
    );
  }
}