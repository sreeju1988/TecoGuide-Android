import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io';
import 'firebase_api.dart';
import 'second_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<StatefulWidget> createState() => StartState();
}

class StartState extends State<SplashScreen> {
  late String _firebaseToken;
  late FirebaseAPI firebase;

  Future<void> initializeApp() async {
    firebase = FirebaseAPI();
    await firebase.initializeFirebase();
    String? token = await firebase.getToken();
    _firebaseToken = token ?? "";
    
    // Artificial delay for splash screen visibility
    await Future.delayed(const Duration(seconds: 2));
    
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => SecondScreen(_firebaseToken)),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    initializeApp();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/ic_logo_border.png',
              width: 150,
              height: 150,
            ),
            const SizedBox(height: 24),
            Platform.isIOS
                ? const CupertinoActivityIndicator(
                    color: Colors.blue,
                    radius: 15,
                  )
                : const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
          ],
        ),
      ),
    );
  }
}
