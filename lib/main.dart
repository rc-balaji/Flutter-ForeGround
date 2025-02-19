import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
  bool _isTracking = false;

  void _startFetchingLocation() {
    _isTracking = true;
    _saveTrackingStatus(true);

    _timer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      Position position = await _getCurrentLocation();
      String locationString =
          '${position.latitude}, ${position.longitude} at ${DateTime.now().toLocal()}';

      _locations.add(locationString);
      await _saveLocations();

      FlutterForegroundTask.updateService(
        notificationTitle: 'Tracking Location',
        notificationText: 'Total: ${_locations.length} | $locationString',
      );

      FlutterForegroundTask.sendDataToMain(_locations);
    });
  }

  Future<void> _saveLocations() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('locations', _locations);
  }

  Future<void> _loadLocations() async {
    final prefs = await SharedPreferences.getInstance();
    _locations = prefs.getStringList('locations') ?? [];
  }

  Future<void> _saveTrackingStatus(bool isTracking) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isTracking', isTracking);
  }

  Future<bool> _loadTrackingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isTracking') ?? false;
  }

  Future<Position> _getCurrentLocation() async {
    return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
  }

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await _loadLocations();
    _isTracking = await _loadTrackingStatus();
    if (_isTracking) {
      _startFetchingLocation();
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    _timer.cancel();
  }

  @override
  void onReceiveData(Object data) {
    if (data == 'stop') {
      _timer.cancel();
      _saveTrackingStatus(false);
    } else if (data == 'start') {
      _startFetchingLocation();
    } else if (data == 'clear') {
      _locations.clear();
      _saveLocations();
      FlutterForegroundTask.updateService(
        notificationTitle: 'Tracking Location',
        notificationText: 'Location data cleared.',
      );
    }
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'start') {
      _startFetchingLocation();
    } else if (id == 'stop') {
      _timer.cancel();
      _saveTrackingStatus(false);
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {}
}

class LocationApp extends StatelessWidget {
  const LocationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: HomePage(),
    );
  }
}

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

class LocationPage extends StatefulWidget {
  @override
  _LocationPageState createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  List<String> _locations = [];
  bool _isTracking = false;
  late final Function(Object) _taskDataCallback;

  @override
  void initState() {
    super.initState();
    _taskDataCallback = (data) {
      setState(() {
        _locations = List<String>.from(data as List);
      });
    };

    _loadSavedLocations();
    _loadTrackingStatus();

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
        autoRunOnBoot: true,
        allowWakeLock: true,
      ),
    );

    FlutterForegroundTask.startService(
      notificationTitle: 'Location Tracker',
      notificationText: 'Fetching live location...',
      callback: startCallback,
      // notificationButtons: [
      //   NotificationButton(id: 'start', text: 'Start'),
      //   NotificationButton(id: 'stop', text: 'Stop'),
      // ],
    );

    FlutterForegroundTask.addTaskDataCallback(_taskDataCallback);
  }

  Future<void> _loadSavedLocations() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _locations = prefs.getStringList('locations') ?? [];
    });
  }

  Future<void> _loadTrackingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isTracking = prefs.getBool('isTracking') ?? false;
    });
  }

  void _clearLocations() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('locations');
    setState(() {
      _locations.clear();
    });

    FlutterForegroundTask.sendDataToTask('clear');
  }

  void _exitApp() {
    FlutterForegroundTask.stopService();
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
          Text('Total Locations Stored: ${_locations.length}',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Expanded(
            child: ListView.builder(
              itemCount: _locations.length,
              itemBuilder: (context, index) {
                return ListTile(title: Text(_locations[index]));
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                  onPressed: _isTracking
                      ? null
                      : () => FlutterForegroundTask.sendDataToTask('start'),
                  child: const Text('Start')),
              ElevatedButton(
                  onPressed: _isTracking
                      ? () => FlutterForegroundTask.sendDataToTask('stop')
                      : null,
                  child: const Text('Stop')),
              ElevatedButton(
                  onPressed: _clearLocations, child: const Text('Clear')),
              ElevatedButton(onPressed: _exitApp, child: const Text('Exit')),
            ],
          ),
        ],
      ),
    );
  }
}
