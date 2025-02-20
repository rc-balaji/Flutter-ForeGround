import 'package:flutter/material.dart';
import 'package:flutter_foreground/LocationPage.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    _checkServiceStatus();
  }

  void _checkServiceStatus() async {
    bool isRunning = await FlutterForegroundTask.isRunningService;
    if (isRunning) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (context) => LocationPage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home Page')),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(context,
                MaterialPageRoute(builder: (context) => LocationPage()));
          },
          child: const Text('Go to Live Location Tracker'),
        ),
      ),
    );
  }
}
