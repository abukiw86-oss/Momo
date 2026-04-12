import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class FreeTrackerMap extends StatefulWidget {
  const FreeTrackerMap({super.key});

  @override
  State<FreeTrackerMap> createState() => _FreeTrackerMapState();
}

class _FreeTrackerMapState extends State<FreeTrackerMap> {
  final MapController _mapController = MapController();
  LatLng? _myLocation;
  LatLng? _otherLocation;
  List<LatLng> _routePoints = [];  
  double _distance = 0.0;
  final String _dbUrl = "https://gps-tracker-de7dc-default-rtdb.europe-west1.firebasedatabase.app";

  @override
  void initState() {
    super.initState();
    _startTrackingLogic();
  }

  // Fetch the actual road path from OSRM (Free)
  Future<void> _updateRoadRoute() async {
    if (_myLocation == null || _otherLocation == null) return;

    final url = 'https://router.project-osrm.org/route/v1/driving/'
        '${_myLocation!.longitude},${_myLocation!.latitude};'
        '${_otherLocation!.longitude},${_otherLocation!.latitude}'
        '?overview=full&geometries=geojson';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List coords = data['routes'][0]['geometry']['coordinates'];
        
        setState(() {
          _routePoints = coords.map((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList();
          // Use OSRM's accurate road distance instead of straight-line distance
          _distance = (data['routes'][0]['distance'] as num).toDouble();
        });
      }
    } catch (e) {
      print("Routing error: $e");
    }
  }

  void _startTrackingLogic() {
    // 1. My Location (Hardware)
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5),
    ).listen((Position position) {
      if (mounted) {
        setState(() {
          _myLocation = LatLng(position.latitude, position.longitude);
        });
        _updateRoadRoute();
      }
    });

    // 2. Their Location (Firebase)
    FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: _dbUrl)
        .ref("drivers/driver_1")
        .onValue
        .listen((event) {
      final data = event.snapshot.value as Map?;
      if (data != null && mounted) {
        setState(() {
          _otherLocation = LatLng(
            (data['lat'] as num).toDouble(),
            (data['lng'] as num).toDouble(),
          );
        });
        _updateRoadRoute();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Live Fleet Tracker"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // THE MAP
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(9.03, 38.74),
              initialZoom: 13,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.gps_tracker',
              ),
              // THE ROAD ROUTE
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      color: Colors.blueAccent,
                      strokeWidth: 5,
                    ),
                  ],
                ),
              // MARKERS
              MarkerLayer(
                markers: [
                  if (_myLocation != null)
                    Marker(
                      point: _myLocation!,
                      width: 80,
                      height: 80,
                      child: _buildUserMarker("Me", Colors.blue),
                    ),
                  if (_otherLocation != null)
                    Marker(
                      point: _otherLocation!,
                      width: 80,
                      height: 80,
                      child: _buildUserMarker("Driver 1", Colors.red),
                    ),
                ],
              ),
            ],
          ),

          // DISTANCE OVERLAY CARD
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: _buildDistanceCard(),
          ),
        ],
      ),
    );
  }

  Widget _buildUserMarker(String label, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
          ),
          child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
        ),
        Icon(Icons.location_on, color: color, size: 45),
      ],
    );
  }

  Widget _buildDistanceCard() {
    return Card(
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Colors.blueAccent,
              child: Icon(Icons.directions_car, color: Colors.white),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Road Distance", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  Text(
                    _distance < 1000 
                        ? "${_distance.toStringAsFixed(0)} m" 
                        : "${(_distance / 1000).toStringAsFixed(2)} km",
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.my_location, color: Colors.blueAccent),
              onPressed: () {
                if (_myLocation != null) _mapController.move(_myLocation!, 15);
              },
            ),
          ],
        ),
      ),
    );
  }
}