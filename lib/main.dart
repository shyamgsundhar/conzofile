import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:myapp/screens/dummy.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:page_transition/page_transition.dart';
import 'package:provider/provider.dart';
import 'package:myapp/screens/bt_provider.dart';
import 'package:myapp/screens/home.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BluetoothProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Conzo',
      theme: ThemeData(
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  void initState() {
    super.initState();
    requestPermissions();
    Timer(
      const Duration(
          seconds: 2), // Increased to give the splash screen more visibility
      () => Navigator.of(context).pushReplacement(
        PageTransition(
          child: HomeScreen(),
          type: PageTransitionType.fade,
        ),
      ),
    );
  }

  /// Request Permissions for Bluetooth, Location
  Future<void> requestPermissions() async {
    Map<Permission, PermissionStatus> statuses;

    // Platform-specific permissions
    if (Platform.isAndroid) {
      statuses = await [
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ].request();
    } else if (Platform.isIOS) {
      statuses = await [
        Permission.locationWhenInUse,
      ].request();
    } else {
      return; // No additional permissions needed for other platforms
    }

    // Handle denied permissions
    if (statuses.values.any((status) => status.isDenied)) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Permissions Required'),
            content: const Text(
              'Bluetooth and Location permissions are necessary for the app to function properly.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ScreenUtil.init(context);
    return Scaffold(
      backgroundColor: const Color(0xffF2F2F2),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            Center(
              child: Image.asset("assets/logo.png"),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        color: const Color(0xffF2F2F2),
        height: 180,
        child: Column(
          children: [
            Text(
              'from',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
            SizedBox(
              height: 10.h,
            ),
            Center(
              child: Image.asset('assets/mainlogo.png'),
            ),
          ],
        ),
      ),
    );
  }
}
