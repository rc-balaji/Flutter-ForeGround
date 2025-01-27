import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart'; // Import your custom FlutterOverlayWindow class
import 'package:flutter_foreground_task/flutter_foreground_task.dart'; // For foreground notifications

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: StopwatchOverlay(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Duration _elapsed = Duration.zero; // To sync time between app and overlay

  @override
  void initState() {
    super.initState();
    // Initialize foreground service for notifications
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'stopwatch_channel',
        channelName: 'Stopwatch Notifications',
        channelDescription: 'Notifications for stopwatch actions',
        priority: NotificationPriority.HIGH,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: IOSNotificationOptions(
        showNotification: true,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(500),
        autoRunOnBoot: true,
        allowWakeLock: true,
      ),
    );
  }

  void _startStopwatch() {
    FlutterForegroundTask.startService(
      notificationTitle: "Stopwatch",
      notificationText: _formatDuration(_elapsed),
      callback: startCallback,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Stopwatch with Overlay'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _formatDuration(_elapsed),
                style:
                    const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _startStopwatch,
                    child: const Text("Start Stopwatch"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () {
                      FlutterOverlayWindow.showOverlay(
                        overlayTitle: "Stopwatch",
                        overlayContent: _formatDuration(_elapsed),
                        height: 800,
                        width: 1500,
                        enableDrag: true,
                        startPosition: OverlayPosition(0, -259),
                      );
                    },
                    child: const Text("Show Overlay"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }
}

@pragma("vm:entry-point")
void startCallback() {
  FlutterForegroundTask.setTaskHandler(StopwatchTaskHandler());
}

class StopwatchTaskHandler extends TaskHandler {
  late Timer _timer;
  Duration _elapsed = Duration.zero;

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _elapsed += const Duration(seconds: 1);
      FlutterForegroundTask.updateService(
        notificationTitle: "Stopwatch",
        notificationText: _formatDuration(_elapsed),
      );
      FlutterForegroundTask.sendDataToMain(_formatDuration(_elapsed));
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _startTimer();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    _timer.cancel();
  }

  @override
  void onReceiveData(Object data) {
    if (data == 'start') {
      _startTimer();
    }
  }

  @override
  void onNotificationButtonPressed(String id) {}
}

class StopwatchOverlay extends StatefulWidget {
  const StopwatchOverlay({Key? key}) : super(key: key);

  @override
  State<StopwatchOverlay> createState() => _StopwatchOverlayState();
}

class _StopwatchOverlayState extends State<StopwatchOverlay> {
  Duration _elapsed = Duration.zero;
  late Timer _timer;
  bool _isRunning = false;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _elapsed += const Duration(seconds: 1);
      });
      FlutterOverlayWindow.shareData({
        'overlayTitle': "Stopwatch",
        'overlayContent': _formatDuration(_elapsed),
      });
    });
    setState(() {
      _isRunning = true;
    });
  }

  void _stopTimer() {
    _timer.cancel();
    setState(() {
      _isRunning = false;
    });
  }

  void _resetTimer() {
    _timer.cancel();
    setState(() {
      _elapsed = Duration.zero;
      _isRunning = false;
    });
    FlutterOverlayWindow.shareData({
      'overlayTitle': "Stopwatch",
      'overlayContent': _formatDuration(_elapsed),
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          width: 300,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: _isExpanded ? 250 : 150,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.blueAccent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    _formatDuration(_elapsed),
                    style: const TextStyle(
                        fontSize: 36, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: EdgeInsets.all(5),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: _isRunning ? null : _startTimer,
                      child: const Text("Start"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _isRunning ? _stopTimer : null,
                      child: const Text("Stop"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _resetTimer,
                      child: const Text("Reset"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () {
                        FlutterOverlayWindow.closeOverlay();
                      },
                      child: const Text("Exit"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                child: Text(_isExpanded ? "Collapse" : "Expand"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
