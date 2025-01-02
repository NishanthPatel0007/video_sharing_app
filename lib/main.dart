import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/video.dart';
import 'screens/dashboard_screen.dart';
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
       onGenerateRoute: (settings) {
          // Handle video share URLs
          if (settings.name?.startsWith('/player/') ?? false) {
            final code = settings.name!.substring(8); // Remove '/player/'
            return MaterialPageRoute(
              builder: (context) => _buildSharedVideoPage(code),
            );
          }
          return null;
        },
        home: StreamBuilder(
          stream: AuthService().authStateChanges,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            return snapshot.hasData ? const DashboardScreen() : const LoginScreen();
          },
        ),
      ),
    );
  }

  // Handle shared video loading
  Widget _buildSharedVideoPage(String code) {
    return FutureBuilder<Video?>(
      future: _loadSharedVideo(code),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }

        final video = snapshot.data;
        if (video == null) {
          return const Scaffold(
            body: Center(child: Text('Video not found')),
          );
        }

        return PlayerScreen(video: video);
      },
    );
  }

  Future<Video?> _loadSharedVideo(String code) async {
    try {
      final videoUrlService = VideoUrlService();
      final videoId = await videoUrlService.getVideoId(code);
      if (videoId == null) return null;

      // Get video data from Firestore
      final doc = await FirebaseFirestore.instance
          .collection('videos')
          .doc(videoId)
          .get();

      if (!doc.exists) return null;
      
      return Video.fromFirestore(doc);
    } catch (e) {
      print('Error loading shared video: $e');
      return null;
    }
  }
}