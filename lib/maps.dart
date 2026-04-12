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
import 'package:flutter/services.dart';  
import 'package:share_plus/share_plus.dart'; 


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

  String? _lastMappedTarget;

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
    setState(() {
        _isSearching = false;
      });
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
  bool targetChanged = _targetUser != _lastMappedTarget;

  final url = 'https://router.project-osrm.org/route/v1/driving/'
      '${_myLocation!.longitude},${_myLocation!.latitude};'
      '${destination.longitude},${destination.latitude}?overview=full&geometries=geojson';

  try {
    final res = await http.get(Uri.parse(url));
    if (res.statusCode == 200) {
      final data = json.decode(res.body); 
      if (data['routes'] != null && data['routes'].isNotEmpty) {
        final List coords = data['routes'][0]['geometry']['coordinates']; 
        setState(() {
          _routePoints = coords.map((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList();
          _distance = (data['routes'][0]['distance'] as num).toDouble();
          _lastMappedTarget = _targetUser;  
        });
      }
    }
  } catch (e) {
    debugPrint("Routing Error: $e");
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
            accountEmail: Text("Session: ${_currentSessionId ?? 'None'}"),
            decoration: const BoxDecoration(color: Colors.blueAccent),
          ), 
          const ListTile(
            title: Text("Group Members", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: _teamLocations.isEmpty 
              ? const Center(child: Text("No one joined yet"))
              : ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: _teamLocations.length,
                  itemBuilder: (context, index) {
                    String name = _teamLocations.keys.elementAt(index);
                    return ListTile(
                      title: Text(name),
                      leading: const Icon(Icons.person, color: Colors.red),
                      onTap: () {
                          setState(() {
                            _routePoints = [];
                            _targetUser = name;  
                          }); 
                        if (_teamLocations.containsKey(name)) {
                          _updateRoadRoute(_teamLocations[name]!); 
                          _mapController.move(_teamLocations[name]!, 15);
                        } 
                          Navigator.pop(context); 
                          _mapController.move(_teamLocations[name]!, 15);  
                        },
                    );
                  },
                ),
          ), 
          const Divider(),
          ListTile(
            leading: const Icon(Icons.share, color: Colors.blueAccent),
            title: const Text("Invite Friends to App"),
            subtitle: const Text("Share download link"),
            onTap: () { 
              const String appLink = "https://play.google.com/store/apps/details?id=com.yourapp.id";
              Share.share(
                "Hey! Download this GPS Tracker app so we can see each other on the map: $appLink",
                subject: "Download GPS Tracker",
              );
            }, 
          ),
          const SizedBox(height: 10), 
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
          icon: const Icon(Icons.join_full),
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
      Container(color: Colors.white, child: Text(label, style: const TextStyle(fontSize: 18))),
      Icon(Icons.location_on, color: color, size: 50),
    ]);
  }
    
  void _showSessionDialog() {
    TextEditingController sessionCtrl = TextEditingController();  
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Location Sharing"),
        content: SingleChildScrollView(  
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [ 
              if (_currentSessionId != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      const Text("Active Group Code", style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
                      const SizedBox(height: 5),
                      SelectableText( // Allows user to manually highlight if they want
                        _currentSessionId!, 
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 3, color: Colors.blue),
                      ),
                      const SizedBox(height: 5),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.copy_all, size: 18),
                        label: const Text("Copy & Share"),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _currentSessionId!));
                          Share.share("Track me on GPS Tracker! Group Code: $_currentSessionId");
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Code copied!")),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const Divider(height: 30),
              ],

              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 45)),
                icon: const Icon(Icons.group_add),
                label: const Text("Create New Group"),
                onPressed: () {
                  String newId = const Uuid().v4().substring(0, 6).toUpperCase();
                  Navigator.pop(context);
                  _joinSession(newId, true);
                  
                  // We show the share sheet immediately after creating
                  Share.share("Join my location group! Code: $newId");
                },
              ),
              
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 15),
                child: Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text("OR JOIN", style: TextStyle(fontSize: 10, color: Colors.grey)),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
              ),

              TextField(
                controller: sessionCtrl,
                textAlign: TextAlign.center,
                maxLength: 6,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2),
                decoration: InputDecoration(
                  hintText: "CODE",
                  counterText: "", // Hide character counter
                  hintStyle: const TextStyle(letterSpacing: 0, fontWeight: FontWeight.normal),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
          ElevatedButton(
            onPressed: () {
              if (sessionCtrl.text.length == 6) {
                _joinSession(sessionCtrl.text.toUpperCase(), false);
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please enter a 6-digit code")),
                );
              }
            },
            child: const Text("Join Now"),
          )
        ],
      ),
    );
  }

  Widget _buildDistanceCard() { 
    bool isTrackingOthers = _targetUser != null && _teamLocations.containsKey(_targetUser);
    
    if (_myLocation == null) {
      return const SizedBox();
    } 
    final displayLocation = isTrackingOthers ? _teamLocations[_targetUser]! : _myLocation!;
    final displayName = isTrackingOthers ? _targetUser : "My Location (Solo)";

    return Positioned(
      bottom: 20,
      left: 10,
      right: 10,
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isTrackingOthers ? Colors.green : Colors.blueAccent,
              child: Icon(
                isTrackingOthers ? Icons.navigation : Icons.person_pin_circle, 
                color: Colors.white
              ),
            ),
            title: Text(
              displayName!,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                if (isTrackingOthers)
                  Text(
                    "Distance: ${_distance < 1000 ? '${_distance.toStringAsFixed(0)} m' : '${(_distance / 1000).toStringAsFixed(2)} km'}",
                    style: const TextStyle(color: Colors.black87),
                  )
                else
                  const Text("Not tracking anyone else", style: TextStyle(color: Colors.grey)), 
                const SizedBox(height: 2), 
                Text(
                  "Lat: ${displayLocation.latitude.toStringAsFixed(5)}, Lng: ${displayLocation.longitude.toStringAsFixed(5)}",
                  style: TextStyle(fontSize: 11, color: Colors.grey[600], fontFamily: 'monospace'),
                ),
              ],
            ),
            trailing: Builder(
              builder: (context) { 
                return IconButton(
                  icon: const Icon(Icons.people_alt_rounded, color: Colors.blueAccent),
                  onPressed: () {
                    Scaffold.of(context).openDrawer();
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}