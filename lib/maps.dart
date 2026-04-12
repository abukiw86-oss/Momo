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
  String? _targetUser;

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
 
  void _startMyLocalTracking() {
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high, 
        distanceFilter: 5  
      ),
    ).listen((position) {
      if (mounted) {
        LatLng newPos = LatLng(position.latitude, position.longitude);
        setState(() => _myLocation = newPos);
         
        if (_currentSessionId != null) {
          FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: _dbUrl)
              .ref("sessions/$_currentSessionId/users/$_userName")
              .update({ // Use update to only change lat/lng/time
            "lat": position.latitude,
            "lng": position.longitude,
            "last_seen": ServerValue.timestamp,
          });
        }
      }
    });
  }
    
  void _handleSearchSubmit(String val )  async{
  if (val.isEmpty) return;
   
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
   
  void _joinSession(String sessionId, bool isCreatingSession) async {
  final dbRef = FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: _dbUrl);

  if (!isCreatingSession) {
    final snapshot = await dbRef.ref("sessions/$sessionId").get();
    if (!snapshot.exists) { 
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid Code!"), backgroundColor: Colors.red),
        );
      } 
      return; 
    }
  }

  setState(() {
    _currentSessionId = sessionId;
    _teamLocations.clear(); 
    _targetUser = null; 
  });

  if (_myLocation != null) {
    await dbRef.ref("sessions/$sessionId/users/$_userName").set({
      "name": _userName,
      "lat": _myLocation!.latitude,
      "lng": _myLocation!.longitude,
      "last_seen": ServerValue.timestamp,
    });
  }

  dbRef.ref("sessions/$sessionId/users").onValue.listen((event) {
    final data = event.snapshot.value as Map?;
    if (data != null && mounted) {
      Map<String, LatLng> newTeam = {};
      data.forEach((key, value) {
        if (key != _userName) {
          newTeam[key] = LatLng(
            (value['lat'] as num).toDouble(),
            (value['lng'] as num).toDouble(),
          );
        }
      });

      setState(() {
        _teamLocations = newTeam;
         
        if (_targetUser == null && newTeam.isNotEmpty) {
          _targetUser = newTeam.keys.first;
        } 
        if (_targetUser != null && newTeam.containsKey(_targetUser)) {
          _updateRoadRoute(newTeam[_targetUser]!);
        }
      });
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
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(_userName),
              accountEmail: Text("Session: ${_currentSessionId ?? 'No Active Session'}"),
              currentAccountPicture: const CircleAvatar(child: Icon(Icons.person)),
              decoration: const BoxDecoration(color: Colors.blueAccent),
            ),
            const ListTile(
              title: Text("Joined Members", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: _teamLocations.isEmpty 
                ? const Center(child: Text("No one else has joined yet"))
                : ListView.builder(
                    itemCount: _teamLocations.length,
                    itemBuilder: (context, index) {
                      String name = _teamLocations.keys.elementAt(index);
                      bool isTarget = _targetUser == name;

                      return ListTile(
                        leading: Icon(Icons.circle, color: isTarget ? Colors.green : Colors.red, size: 12),
                        title: Text(name),
                        subtitle: Text(isTarget ? "Currently Tracking" : "Tap to track"),
                        trailing: isTarget ? const Icon(Icons.location_searching, color: Colors.blue) : null,
                        selected: isTarget,
                        onTap: () {
                          setState(() {
                            _targetUser = name;
                            _updateRoadRoute(_teamLocations[name]!);
                          });
                          Navigator.pop(context);  
                          _mapController.move(_teamLocations[name]!, 15); 
                        },
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    appBar: AppBar(
      title:  _isSearching 
    ? TextField(
        autofocus: true,
        style: const TextStyle(color: Colors.black),
        decoration: const InputDecoration(
          hintText: "Search places...",
          hintStyle: TextStyle(color: Colors.black),
          border: InputBorder.none,
        ), 
        onSubmitted: (val) => _handleSearchSubmit(val),  
      )
        : Text("Hi, $_userName ${_currentSessionId != null ? '($_currentSessionId)' : ''}"),
      actions: [
        IconButton(
          icon: Icon(_isSearching ? Icons.close : Icons.search),
          onPressed: () {
            setState(() {
              _isSearching = !_isSearching; 
            });
          },
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
              MarkerLayer(
                markers: [
                  // 1. My Marker
                  if (_myLocation != null)
                    Marker(
                      point: _myLocation!,
                      width: 80, height: 80,
                      child: _markerWidget("Me", Colors.blue),
                    ), 
                  ..._teamLocations.entries.map((entry) {
                      bool isTracked = entry.key == _targetUser;
                      return Marker(
                        point: entry.value,
                        width: 80, height: 80,
                        child: Column(
                          children: [
                            // Name Tag
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: isTracked ? Colors.green : Colors.black54,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(entry.key, style: const TextStyle(color: Colors.white, fontSize: 10)),
                            ),
                            // The Marker Icon
                            Icon(
                              Icons.location_on, 
                              size: isTracked ? 45 : 35,
                              color: isTracked ? Colors.green : Colors.red
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                ],),
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
  
  Widget _markerWidget(String label, Color color) {
    return Column(children: [
      Container(color: Colors.white, child: Text(label, style: const TextStyle(fontSize: 10))),
      Icon(Icons.location_on, color: color, size: 30),
    ]);
  }
    
  void _showSessionDialog() {
  TextEditingController sessionCtrl = TextEditingController(); 
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Location Sharing"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [ 
          if (_currentSessionId != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  const Text("Your Current Group Code:", style: TextStyle(fontSize: 12)),
                  Text(_currentSessionId!, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  TextButton.icon(
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text("Copy & Share"),
                    onPressed: () {  
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Code copied!")));
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 30),
          ],

          ElevatedButton.icon(
            icon: const Icon(Icons.group_add),
            label: const Text("Create New Group"),
            onPressed: () {
              String newId = const Uuid().v4().substring(0, 6).toUpperCase();
              Navigator.pop(context);
              _joinSession(newId,true);  
               
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Group $newId Created! Share it with friends.")),
              );
            },
          ),
          
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 15),
            child: Text("OR JOIN EXISTING", style: TextStyle(fontSize: 10, color: Colors.grey)),
          ),

          TextField(
            controller: sessionCtrl,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: "Enter 6-digit Code",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: () {
            if (sessionCtrl.text.length == 6) {
              _joinSession(sessionCtrl.text.toUpperCase(),false);
              Navigator.pop(context);
            }
          },
          child: const Text("Join"),
        )
      ],
    ),
  );
}

Widget _buildDistanceCard() {
  if (_targetUser == null || !_teamLocations.containsKey(_targetUser)) {
    return const SizedBox();
  } 
  return Positioned(
    bottom: 20,
    left: 10,
    right: 10,
    child: Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        leading: const Icon(Icons.navigation, color: Colors.blueAccent),
        title: Text("Tracking: $_targetUser"),
        subtitle: Text(
          "Distance: ${_distance < 1000 ? '${_distance.toStringAsFixed(0)} m' : '${(_distance / 1000).toStringAsFixed(2)} km'}"
        ),
        trailing: IconButton(
          icon: const Icon(Icons.people),
          onPressed: () => Scaffold.of(context).openDrawer(), 
        ),
      ),
    ),
  );
}
}