import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class FreeTrackerMap extends StatefulWidget {
  const FreeTrackerMap({super.key});

  @override
  State<FreeTrackerMap> createState() => _FreeTrackerMapState();
}

class _FreeTrackerMapState extends State<FreeTrackerMap> {
  final MapController _mapController = MapController();
  final String _dbUrl = "https://gps-tracker-de7dc-default-rtdb.europe-west1.firebasedatabase.app";
  
  LatLng? _myLocation;
  Map<String, LatLng> _teamLocations = {};
  List<LatLng> _routePoints = [];
  double _distance = 0.0;
  
  String _userName = "";
  String? _currentSessionId;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _setupUserAndTracking();
  }
 
Future<void> _setupUserAndTracking() async { 
  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  } 
  Position position = await Geolocator.getCurrentPosition(
    desiredAccuracy: LocationAccuracy.high
  );
  
  LatLng currentLatLng = LatLng(position.latitude, position.longitude);

  setState(() {
    _myLocation = currentLatLng;
  }); 
  Future.delayed(const Duration(milliseconds: 500), () {
    _mapController.move(currentLatLng, 15);
  }); 
  final prefs = await SharedPreferences.getInstance();
  String? savedName = prefs.getString('user_name');
  if (savedName == null) {
    _showNameDialog();
  } else {
    setState(() => _userName = savedName);
    _startMyLocalTracking();
  }
}

  void _showNameDialog() {
    TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Enter Your Name"),
        content: TextField(controller: controller, decoration: const InputDecoration(hintText: "e.g. Abuki")),
        actions: [
          TextButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('user_name', controller.text);
                setState(() => _userName = controller.text);
                Navigator.pop(context);
                _startMyLocalTracking();
              }
            },
            child: const Text("Save"),
          )
        ],
      ),
    );
  }
 
  void _startMyLocalTracking() {
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5),
    ).listen((position) {
      if (mounted) {
        LatLng newPos = LatLng(position.latitude, position.longitude);
        setState(() => _myLocation = newPos);
        
        // If in a session, update Firebase
        if (_currentSessionId != null) {
          FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: _dbUrl)
              .ref("sessions/$_currentSessionId/users/$_userName")
          .set({
            "lat": position.latitude,
            "lng": position.longitude,
            "name": _userName,
            "timestamp": ServerValue.timestamp,
          });
        }
      }
    });
  }

  void _joinSession(String sessionId) async {
    setState(() => _currentSessionId = sessionId);
    if (_myLocation != null) {
    await FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: _dbUrl)
        .ref("sessions/$sessionId/users/$_userName")
        .set({
      "lat": _myLocation!.latitude,
      "lng": _myLocation!.longitude,
      "name": _userName,
      "timestamp": ServerValue.timestamp,
        }); 
      }
      
    FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: _dbUrl)
        .ref("sessions/$sessionId/users")
        .onValue
        .listen((event) {
      final data = event.snapshot.value as Map?;
      if (data != null && mounted) {
        Map<String, LatLng> others = {};
        data.forEach((key, val) {
          if (key != _userName) {
            others[key] = LatLng((val['lat'] as num).toDouble(), (val['lng'] as num).toDouble());
          }
        });
        setState(() => _teamLocations = others);
        if (others.isNotEmpty) _updateRoadRoute(others.values.first);
      }
    });
  }
 
  Future<void> _updateRoadRoute(LatLng destination) async {
    if (_myLocation == null) return;
    final url = 'https://router.project-osrm.org/route/v1/driving/'
        '${_myLocation!.longitude},${_myLocation!.latitude};'
        '${destination.longitude},${destination.latitude}?overview=full&geometries=geojson';

    final res = await http.get(Uri.parse(url));
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      final List coords = data['routes'][0]['geometry']['coordinates'];
      setState(() {
        _routePoints = coords.map((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList();
        _distance = (data['routes'][0]['distance'] as num).toDouble();
      });
    }
  }
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching 
          ? _buildSearchBar() 
          : Text("Hi, $_userName ${_currentSessionId != null ? '($_currentSessionId)' : ''}"),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () => setState(() => _isSearching = !_isSearching),
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _showSessionDialog(),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
           options: MapOptions( 
                initialCenter: _myLocation ?? const LatLng(9.03, 38.74), 
                initialZoom: 15,
              ),
                        children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'
              ,userAgentPackageName: 'com.abuki.fleet_tracker_ethiopia',
              ),
              if (_routePoints.isNotEmpty)
                PolylineLayer(polylines: [
                  Polyline(points: _routePoints, color: Colors.red, strokeWidth: 4)
                ]),
              MarkerLayer(markers: _buildMarkers()),
            ],
          ),
          Positioned(bottom: 20, left: 10, right: 10, child: _buildDistanceCard()), 
          Positioned(
            right: 20,
            bottom: 110,  
            child: FloatingActionButton(
              backgroundColor: Colors.blueAccent,
              child: const Icon(Icons.my_location, color: Colors.white),
              onPressed: () {
                if (_myLocation != null) { 
                  _mapController.move(_myLocation!, 17);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Locating you...")),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Marker> _buildMarkers() {
    List<Marker> markers = [];
    if (_myLocation != null) {
      markers.add(Marker(point: _myLocation!, width: 60, height: 60, child: _markerWidget("Me", Colors.blue)));
    }
    _teamLocations.forEach((name, loc) {
      markers.add(Marker(point: loc, width: 60, height: 60, child: _markerWidget(name, Colors.red)));
    });
    return markers;
  }

  Widget _markerWidget(String label, Color color) {
    return Column(children: [
      Container(color: Colors.white, child: Text(label, style: const TextStyle(fontSize: 10))),
      Icon(Icons.location_on, color: color, size: 30),
    ]);
  }

  Widget _buildSearchBar() {
    return TextField(
      style: const TextStyle(color: Colors.white),
      decoration: const InputDecoration(
        hintText: "Search places...",
        hintStyle: TextStyle(color: Colors.white70),
        border: InputBorder.none,
      ),
      onSubmitted: (val) async {
        if (val.isEmpty) return; 
        try {
          final snapshot = await FirebaseDatabase.instanceFor(
            app: Firebase.app(),
            databaseURL: _dbUrl,
          ).ref("places").get();

          final data = snapshot.value as Map?;
          bool found = false;

          if (data != null) {
            data.forEach((k, v) { 
              if (v['name'].toString().toLowerCase().contains(val.toLowerCase())) {
                LatLng target = LatLng(
                  (v['lat'] as num).toDouble(),
                  (v['lng'] as num).toDouble(),
                );
                
                _mapController.move(target, 16);  
                _updateRoadRoute(target);
                
                found = true;
                setState(() {
                  _isSearching = false;
                });
              }
            });
          }

          if (!found) { 
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Place '$val' not found in database"),
                backgroundColor: Colors.orange,
              ),
            );
          }
        } catch (e) { 
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: ${e.toString()}")),
          );
        }
      },
    );
  }
    
  void _showSessionDialog() {
    TextEditingController sessionCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Session Sharing"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () {
                String newId = const Uuid().v4().substring(0, 6).toUpperCase();
                Navigator.pop(context);
                _joinSession(newId);
              }, 
              child: const Text("Create New Group")
            ),
            const Divider(),
            TextField(controller: sessionCtrl, decoration: const InputDecoration(hintText: "Enter 6-digit Code")),
          ],
        ),
        actions: [
          TextButton(onPressed: () {
            _joinSession(sessionCtrl.text.toUpperCase());
            Navigator.pop(context);
          }, child: const Text("Join"))
        ],
      ),
    );
  }

  Widget _buildDistanceCard() {
    if (_distance == 0) return const SizedBox();
    return Card(
      child: ListTile(
        leading: const Icon(Icons.directions),
        title: Text("Distance: ${(_distance / 1000).toStringAsFixed(2)} km"),
        trailing: IconButton(icon: const Icon(Icons.my_location), onPressed: () => _mapController.move(_myLocation!, 15)),
      ),
    );
  }
}