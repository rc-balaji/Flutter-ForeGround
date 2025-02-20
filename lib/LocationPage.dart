import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_foreground/home_page.dart';
import 'package:flutter_foreground/pages/api_service.dart';
import 'package:flutter_foreground/pages/geo_show.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';

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
          '${position.latitude}, ${position.longitude} , ${DateTime.now().toLocal()}';

      print(locationString);

      _locations.add(locationString);
      await _saveLocations();

      FlutterForegroundTask.updateService(
        notificationTitle: 'Tracking Location',
        notificationText: 'Total: ${_locations.length} | $locationString',
      );

      FlutterForegroundTask.sendDataToMain(
          {'locations': _locations, 'isTracking': _isTracking});
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
      _isTracking = false;
      _saveTrackingStatus(false);
      FlutterForegroundTask.sendDataToMain(
          {'locations': _locations, 'isTracking': _isTracking});
    } else if (data == 'start') {
      _startFetchingLocation();
    } else if (data == 'clear') {
      _locations.clear();
      _saveLocations();
      FlutterForegroundTask.updateService(
        notificationTitle: 'Tracking Location',
        notificationText: 'Location data cleared.',
      );
      FlutterForegroundTask.sendDataToMain(
          {'locations': _locations, 'isTracking': _isTracking});
    }
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'start') {
      _startFetchingLocation();
    } else if (id == 'stop') {
      _timer.cancel();
      _isTracking = false;
      _saveTrackingStatus(false);
      FlutterForegroundTask.sendDataToMain(
          {'locations': _locations, 'isTracking': _isTracking});
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {}
}

// Global User ID
const String userId = "67a303c55e0bd56d2bdf48ff";

class LocationPage extends StatefulWidget {
  @override
  _LocationPageState createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  List<String> _locations = [];
  bool _isTracking = false;
  String _locationName = "";
  late final Function(Object) _taskDataCallback;

  TextEditingController _locationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _taskDataCallback = (data) {
      if (data is Map<String, dynamic>) {
        setState(() {
          _locations = List<String>.from(data['locations'] ?? []);
          _isTracking = data['isTracking'] ?? false;
        });
      }
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
      _locationController.clear();
    });
    FlutterForegroundTask.sendDataToTask('clear');
  }

  void _saveLocation() async {
    if (_locationName.isEmpty) {
      _showErrorDialog("Enter a location name first!");
      return;
    }
    if (_locations.isEmpty) {
      _showErrorDialog("Location is Empty!!!");
      return;
    }

    Future<bool> res =
        ApiService.saveLocation(userId, _locationName, _locations);

    if (await res) {
      await FlutterForegroundTask.stopService();
      _clearLocations();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomePage()),
      );

      const snackBar = SnackBar(
        content: Text('Saved Successfully',
            style: TextStyle(
              color: Color.fromARGB(255, 0, 0, 0),
            )),
        backgroundColor: Colors.lightGreenAccent,
      );
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    } else {
      _showErrorDialog("Unable to Store: Network Issues");
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Error"),
          content: Text(message),
          actions: [
            TextButton(
              child: Text("OK"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _exitApp() {
    FlutterForegroundTask.stopService();
  }

  @override
  void dispose() {
    FlutterForegroundTask.removeTaskDataCallback(_taskDataCallback);
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Live Location Tracker',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _locationController,
              decoration: InputDecoration(
                labelText: 'Enter Location Name',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _locationName = value;
                });
              },
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: _isTracking
                      ? null
                      : () => FlutterForegroundTask.sendDataToTask('start'),
                  child: Text('Start'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: _isTracking
                      ? () => FlutterForegroundTask.sendDataToTask('stop')
                      : null,
                  child: Text('Stop'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  onPressed: !_isTracking ? _saveLocation : null,
                  child: Text('Save'),
                ),
              ],
            ),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  onPressed: _clearLocations,
                  child: Text('Clear'),
                ),
                ElevatedButton(
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.black),
                  onPressed: _exitApp,
                  child: Text('Exit', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
            SizedBox(height: 20),
            Expanded(child: GeoShow(locations: _locations)),
          ],
        ),
      ),
    );
  }
}
