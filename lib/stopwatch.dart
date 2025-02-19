import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

void main() {
  FlutterForegroundTask.initCommunicationPort();
  runApp(const StopwatchApp());
}

@pragma('vm:entry-point')
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
        notificationTitle: 'Stopwatch Running',
        notificationText: _formatDuration(_elapsed),
      );
      FlutterForegroundTask.sendDataToMain(_formatDuration(_elapsed));
    });
  }

  void _stopTimer() {
    _timer.cancel();
  }

  void _resetTimer() {
    _elapsed = Duration.zero;
    FlutterForegroundTask.updateService(
      notificationTitle: 'Stopwatch Reset',
      notificationText: _formatDuration(_elapsed),
    );
    FlutterForegroundTask.sendDataToMain(_formatDuration(_elapsed));
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
    // _startTimer();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // This can be used for periodic updates if needed
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    _stopTimer();
  }

  @override
  void onReceiveData(Object data) {
    if (data == 'start') {
      _startTimer();
    } else if (data == 'stop') {
      _stopTimer();
    } else if (data == 'reset') {
      _resetTimer();
    }
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'start') {
      _startTimer();
    } else if (id == 'stop') {
      _stopTimer();
    } else if (id == 'reset') {
      _resetTimer();
    }
  }
}

class StopwatchApp extends StatelessWidget {
  const StopwatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: StopwatchPage(),
    );
  }
}

class StopwatchPage extends StatefulWidget {
  @override
  _StopwatchPageState createState() => _StopwatchPageState();
}

class _StopwatchPageState extends State<StopwatchPage> {
  Duration _elapsed = Duration.zero;
  late final Function(Object) _taskDataCallback;

  @override
  void initState() {
    super.initState();
    _taskDataCallback = (data) {
      setState(() {
        _elapsed = _parseDuration(data.toString());
      });
    };

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'stopwatch_channel',
        channelName: 'Stopwatch Notifications',
        channelDescription: 'Notifications for stopwatch actions',
        onlyAlertOnce: true,
        priority: NotificationPriority.HIGH,
      ),
      iosNotificationOptions: IOSNotificationOptions(
        showNotification: true,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction:
            ForegroundTaskEventAction.repeat(1000), // Update every second
        autoRunOnBoot: false,
        allowWakeLock: true,
      ),
    );

    // Start the foreground service
    FlutterForegroundTask.startService(
      notificationTitle: 'Stopwatch App',
      notificationText: 'Tap to open the app',
      callback: startCallback,
      notificationButtons: [
        NotificationButton(
          id: 'start',
          text: 'Start',
        ),
        NotificationButton(
          id: 'stop',
          text: 'Stop',
        ),
        NotificationButton(
          id: 'reset',
          text: 'Reset',
        ),
      ],
    );

    // Listen for data from the foreground task
    FlutterForegroundTask.addTaskDataCallback(_taskDataCallback);
  }

  Duration _parseDuration(String data) {
    final parts = data.split(':');
    if (parts.length == 3) {
      final hours = int.parse(parts[0]);
      final minutes = int.parse(parts[1]);
      final seconds = int.parse(parts[2]);
      return Duration(hours: hours, minutes: minutes, seconds: seconds);
    }
    return Duration.zero;
  }

  void _exitApp() {
    FlutterForegroundTask.stopService();
    exit(0);
  }

  @override
  void dispose() {
    FlutterForegroundTask.removeTaskDataCallback(_taskDataCallback);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(_elapsed.inHours);
    final minutes = twoDigits(_elapsed.inMinutes.remainder(60));
    final seconds = twoDigits(_elapsed.inSeconds.remainder(60));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stopwatch App'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$hours:$minutes:$seconds',
                style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    FlutterForegroundTask.sendDataToTask('start');
                  },
                  child: const Text('Start'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () {
                    FlutterForegroundTask.sendDataToTask('stop');
                  },
                  child: const Text('Stop'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () {
                    FlutterForegroundTask.sendDataToTask('reset');
                  },
                  child: const Text('Reset'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _exitApp,
                  child: const Text('Exit'),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
