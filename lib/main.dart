import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  FlutterForegroundTask.initCommunicationPort();
  runApp(const LocationApp());
}

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(LocationTaskHandler());
}

class LocationTaskHandler extends TaskHandler {
  late Timer _timer;
  List<String> _locations = [];

  void _startFetchingLocation() {
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      Position position = await _getCurrentLocation();
      String locationString =
          '${position.latitude}, ${position.longitude} at ${DateTime.now().toLocal()}';

      _locations.add(locationString);
      FlutterForegroundTask.updateService(
        notificationTitle: 'Tracking Location',
        notificationText: 'Total: ${_locations.length} | $locationString',
      );
      FlutterForegroundTask.sendDataToMain(_locations);
    });
  }

  void _stopFetchingLocation() {
    _timer.cancel();
  }

  Future<Position> _getCurrentLocation() async {
    return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
  }

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _startFetchingLocation();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    _stopFetchingLocation();
  }

  @override
  void onReceiveData(Object data) {
    if (data == 'stop') {
      _stopFetchingLocation();
    } else if (data == 'start') {
      _startFetchingLocation();
    }
  }
}

class LocationApp extends StatelessWidget {
  const LocationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: LocationPage(),
    );
  }
}

class LocationPage extends StatefulWidget {
  @override
  _LocationPageState createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  List<String> _locations = [];
  late final Function(Object) _taskDataCallback;

  @override
  void initState() {
    super.initState();
    _taskDataCallback = (data) {
      setState(() {
        _locations = List<String>.from(data as List);
      });
    };

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'location_channel',
        channelName: 'Location Tracking',
        channelDescription: 'Tracks live location every 2 seconds',
        onlyAlertOnce: true,
        priority: NotificationPriority.HIGH,
      ),
      iosNotificationOptions: IOSNotificationOptions(
        showNotification: true,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(2000),
        autoRunOnBoot: false,
        allowWakeLock: true,
      ),
    );

    FlutterForegroundTask.startService(
      notificationTitle: 'Location Tracker',
      notificationText: 'Fetching live location...',
      callback: startCallback,
      notificationButtons: [
        NotificationButton(id: 'start', text: 'Start'),
        NotificationButton(id: 'stop', text: 'Stop'),
      ],
    );

    FlutterForegroundTask.addTaskDataCallback(_taskDataCallback);
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
    return Scaffold(
      appBar: AppBar(title: const Text('Live Location Tracker')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Total Locations Stored: ${_locations.length}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _locations.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(_locations[index]),
                );
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () => FlutterForegroundTask.sendDataToTask('start'),
                child: const Text('Start'),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () => FlutterForegroundTask.sendDataToTask('stop'),
                child: const Text('Stop'),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _exitApp,
                child: const Text('Exit'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
