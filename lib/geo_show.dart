import 'package:flutter/material.dart';
import 'package:flutter_foreground/utils.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:map_launcher/map_launcher.dart';

class GeoShow extends StatelessWidget {
  final List<String> locations;

  GeoShow({required this.locations});

  void openMapsSheet(BuildContext context, List<Coords> pathPoints) async {
    try {
      final availableMaps = await MapLauncher.installedMaps;
      final googleMap = availableMaps.firstWhere(
        (map) => map.mapType == MapType.google,
      );

      await googleMap.showDirections(
        destination: pathPoints.last,
        origin: pathPoints.first,
      );
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    List geoaxis = convertToList(locations);

    if (geoaxis.isEmpty) {
      return Center(
        child: Text("No location data available."),
      );
    }

    final List<Coords> pathPoints = geoaxis
        .map((point) => Coords(point['latitude'], point['longitude']))
        .toList();

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter:
                  LatLng(pathPoints.first.latitude, pathPoints.first.longitude),
              initialZoom: 15.0,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: ['a', 'b', 'c'],
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: pathPoints
                        .map((coord) => LatLng(coord.latitude, coord.longitude))
                        .toList(),
                    strokeWidth: 4.0,
                    color: Colors.blue,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(
                        pathPoints.first.latitude, pathPoints.first.longitude),
                    child: Icon(
                      Icons.location_on,
                      color: Colors.green,
                      size: 40,
                    ),
                  ),
                  Marker(
                    point: LatLng(
                        pathPoints.last.latitude, pathPoints.last.longitude),
                    child: Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 40,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => openMapsSheet(context, pathPoints),
        child: Icon(Icons.directions),
      ),
    );
  }
}
