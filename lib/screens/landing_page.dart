import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/login_screen.dart';
import '../services/auth_service.dart';

class LandingPage extends StatelessWidget {
 const LandingPage({Key? key}) : super(key: key);

 @override
 Widget build(BuildContext context) {
   final authService = Provider.of<AuthService>(context);
   
   // Check auth and redirect
   if (authService.isLoggedIn) {
     WidgetsBinding.instance.addPostFrameCallback((_) {
       Navigator.pushReplacementNamed(context, '/dashboard');
     });
   }

   return Scaffold(
     backgroundColor: const Color(0xFF1A1A1A),
     appBar: AppBar(
       backgroundColor: Colors.transparent,
       elevation: 0,
       title: const Text(
         'For10Cloud',
         style: TextStyle(
           color: Colors.white,
           fontWeight: FontWeight.bold,
         ),
       ),
       actions: [
         TextButton(
           onPressed: () {
             Navigator.push(
               context,
               MaterialPageRoute(builder: (context) => const LoginScreen()),
             );
           },
           child: const Text(
             'Login',
             style: TextStyle(color: Colors.white),
           ),
         ),
         const SizedBox(width: 16),
       ],
     ),
     body: SingleChildScrollView(
       child: Column(
         children: [
           // Hero Section
           Container(
             height: MediaQuery.of(context).size.height * 0.7,
             decoration: BoxDecoration(
               gradient: LinearGradient(
                 begin: Alignment.topCenter,
                 end: Alignment.bottomCenter,
                 colors: [
                   const Color(0xFF2C2C2C),
                   Colors.black.withOpacity(0.9),
                 ],
               ),
             ),
             child: Center(
               child: Padding(
                 padding: const EdgeInsets.symmetric(horizontal: 24),
                 child: Column(
                   mainAxisAlignment: MainAxisAlignment.center,
                   children: const [
                     Text(
                       'Share Your Videos\nWith The World\nAnd Earn Money',
                       style: TextStyle(
                         fontSize: 48,
                         fontWeight: FontWeight.bold,
                         color: Colors.white,
                         height: 1.2,
                       ),
                       textAlign: TextAlign.center,
                     ),
                     SizedBox(height: 24),
                     Text(
                       'Upload, share, and manage your videos easily and Earn Money',
                       style: TextStyle(
                         fontSize: 20,
                         color: Colors.grey,
                       ),
                       textAlign: TextAlign.center,
                     ),
                   ],
                 ),
               ),
             ),
           ),

           // Features Section  
           Padding(
             padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
             child: Column(
               children: [
                 const Text(
                   'Features',
                   style: TextStyle(
                     fontSize: 32,
                     fontWeight: FontWeight.bold,
                     color: Colors.white,
                   ),
                 ),
                 const SizedBox(height: 48),
                 LayoutBuilder(
                   builder: (context, constraints) {
                     final width = MediaQuery.of(context).size.width;
                     int crossAxisCount = 3;

                     if (width < 600) {
                       crossAxisCount = 1;
                     } else if (width < 900) {
                       crossAxisCount = 2;
                     }

                     return GridView.count(
                       shrinkWrap: true,
                       physics: const NeverScrollableScrollPhysics(),
                       crossAxisCount: crossAxisCount,
                       crossAxisSpacing: 24,
                       mainAxisSpacing: 24,
                       children: const [
                         _FeatureCard(
                           icon: Icons.cloud_upload,
                           title: 'Easy Upload',
                           description: 'Simple drag and drop video upload',
                         ),
                         _FeatureCard(
                           icon: Icons.share,
                           title: 'Quick Share',
                           description: 'Share videos with anyone instantly',
                         ),
                         _FeatureCard(
                           icon: Icons.devices,
                           title: 'Multi-Platform',
                           description: 'Works on all devices and browsers',
                         ),
                       ],
                     );
                   },
                 ),
               ],
             ),
           ),

           // Footer
           Container(
             padding: const EdgeInsets.all(24),
             color: const Color(0xFF2C2C2C),
             child: const Row(
               mainAxisAlignment: MainAxisAlignment.center,
               children: [
                 Text(
                   '© 2024 For10Cloud. All rights reserved.',
                   style: TextStyle(
                     color: Colors.grey,
                   ),
                 ),
               ],
             ),
           ),
         ],
       ),
     ),
   );
 }
}

class _FeatureCard extends StatelessWidget {
 final IconData icon;
 final String title;
 final String description;

 const _FeatureCard({
   required this.icon,
   required this.title,
   required this.description,
 });

 @override
 Widget build(BuildContext context) {
   return Container(
     padding: const EdgeInsets.all(24),
     decoration: BoxDecoration(
       color: const Color(0xFF2C2C2C),
       borderRadius: BorderRadius.circular(16),
       boxShadow: [
         BoxShadow(
           color: Colors.black.withOpacity(0.2),
           blurRadius: 10,
           offset: const Offset(0, 5),
         ),
       ],
     ),
     child: Column(
       mainAxisAlignment: MainAxisAlignment.center,
       children: [
         Icon(
           icon,
           size: 48,
           color: Colors.blue,
         ),
         const SizedBox(height: 16),
         Text(
           title,
           style: const TextStyle(
             fontSize: 20,
             fontWeight: FontWeight.bold,
             color: Colors.white,
           ),
           textAlign: TextAlign.center,
         ),
         const SizedBox(height: 8),
         Text(
           description,
           style: const TextStyle(
             color: Colors.grey,
             height: 1.5,
           ),
           textAlign: TextAlign.center,
         ),
       ],
     ),
   );
 }
}