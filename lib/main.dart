import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/video.dart';
import 'screens/dashboard_screen.dart';
import 'screens/landing_page.dart';
import 'screens/login_screen.dart';
import 'screens/public_video_player.dart';
import 'screens/video_details_screen.dart';
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
        title: 'Video Sharing',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 1,
          ),
        ),
        initialRoute: '/',
        routes: {
          '/login': (context) => const LoginScreen(),
          '/dashboard': (context) => const DashboardScreen(),
        },
        onGenerateRoute: (settings) {
          if (settings.name == '/') {
            return MaterialPageRoute(
              builder: (_) => StreamBuilder(
                stream: AuthService().authStateChanges,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return snapshot.hasData ? const DashboardScreen() : const LandingPage();
                },
              ),
            );
          }

          // Handle video URLs (for10cloud.com/CODE)
          final uri = Uri.parse(settings.name ?? '');
          if (uri.pathSegments.length == 1) {
            final code = uri.pathSegments.first;
            return MaterialPageRoute(
              builder: (_) => _VideoPlayerWrapper(code: code),
            );
          }
          return null;
        },
      ),
    );
  }
}

class _VideoPlayerWrapper extends StatefulWidget {
  final String code;

  const _VideoPlayerWrapper({Key? key, required this.code}) : super(key: key);

  @override
  _VideoPlayerWrapperState createState() => _VideoPlayerWrapperState();
}

class _VideoPlayerWrapperState extends State<_VideoPlayerWrapper> {
  final VideoUrlService _urlService = VideoUrlService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  String? _error;
  Video? _video;

  @override
  void initState() {
    super.initState();
    _loadVideo();
  }

  Future<void> _loadVideo() async {
    try {
      setState(() => _isLoading = true);

      // Get video info from URL code
      final videoInfo = await _urlService.getVideoInfo(widget.code);
      if (videoInfo == null) {
        setState(() {
          _error = 'Video not found';
          _isLoading = false;
        });
        return;
      }

      // Fetch video document
      final doc = await FirebaseFirestore.instance
          .collection('videos')
          .doc(videoInfo['videoId'])
          .get();

      if (!doc.exists) {
        setState(() {
          _error = 'Video not found';
          _isLoading = false;
        });
        return;
      }

      // Create video object and check ownership
      final video = Video.fromFirestore(doc);
      final currentUser = _auth.currentUser;
      final isOwner = currentUser?.uid == video.userId;

      setState(() {
        _video = video;
        _isLoading = false;
      });

      // Route to appropriate screen based on ownership
      if (mounted) {
        if (isOwner) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => VideoDetailsScreen(
                video: video,
                onDelete: () => Navigator.pushReplacementNamed(context, '/'),
              ),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => PublicVideoPlayer(
                video: video,
                onBack: () => Navigator.pushReplacementNamed(context, '/'),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error loading video: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          leading: BackButton(
            onPressed: () => Navigator.pushReplacementNamed(context, '/'),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadVideo,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // This is just a fallback - routing should happen in _loadVideo
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}