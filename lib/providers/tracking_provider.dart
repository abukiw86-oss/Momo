import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:gps_tracker/config/imports.dart';

class TrackingProvider extends ChangeNotifier {
  final String _dbUrl = dotenv.get(
    'DB_URL',
    fallback: 'Fallback URL if not found',
  );

  LatLng? _myLocation;
  Map<String, LatLng> _teamLocations = {};
  List<LatLng> _routePoints = [];
  double _distance = 0.0;
  String? _targetUser;
  String _userName = "";
  String? _currentSessionId;
  bool _isSearching = false;
  bool _isLoadingTeam = false;
  bool _isRequiredName = false;

  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<DatabaseEvent>? _sessionSubscription;

  // Getters
  LatLng? get myLocation => _myLocation;
  Map<String, LatLng> get teamLocations => _teamLocations;
  List<LatLng> get routePoints => _routePoints;
  double get distance => _distance;
  String? get targetUser => _targetUser;
  String get userName => _userName;
  String? get currentSessionId => _currentSessionId;
  bool get isSearching => _isSearching;
  bool get isRequiredName => _isRequiredName;
  bool get isLoadingTeam => _isLoadingTeam;

  void toggleSearching() {
    _isSearching = !_isSearching;
    notifyListeners();
  }

  void setSearching(bool val) {
    _isSearching = val;
    notifyListeners();
  }

  Future<void> initialData({required VoidCallback onNameRequired}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? savedName = prefs.getString('user_name');
      if (savedName == null) {
        onNameRequired();
        _isRequiredName = true;
        notifyListeners();
      } else {
        _userName = savedName;
        notifyListeners();
        startLocalTracking();
      }
    } catch (e) {
      debugPrint("Error in loading data: $e");
    }
  }

  Future<void> initializeTracking() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      LatLng currentLatLng = LatLng(position.latitude, position.longitude);
      _myLocation = currentLatLng;
      notifyListeners();
    } catch (e) {
      debugPrint("Error in initializeTracking: $e");
    }
  }

  Future<void> setSavedUserName(String name) async {
    if (name.isEmpty) return;
    _userName = name;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', name);
    } catch (e) {
      debugPrint("Error saving user name: $e");
    }
    startLocalTracking();
  }

  void startLocalTracking() {
    _positionSubscription?.cancel();

    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
          ),
        ).listen((position) {
          _myLocation = LatLng(position.latitude, position.longitude);
          notifyListeners();

          if (_currentSessionId != null && _userName.isNotEmpty) {
            _isLoadingTeam = false;
            notifyListeners();
            FirebaseDatabase.instanceFor(
              app: Firebase.app(),
              databaseURL: _dbUrl,
            ).ref("sessions/$_currentSessionId/users/$_userName").update({
              "lat": position.latitude,
              "lng": position.longitude,
              "last_seen": ServerValue.timestamp,
            });
          }
        });
  }

  Future<bool> joinOrCreateSession(
    String sessionId, {
    required bool isCreatingSession,
  }) async {
    _isLoadingTeam = true;
    notifyListeners();
    final dbRef = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: _dbUrl,
    );

    if (!isCreatingSession) {
      final snapshot = await dbRef.ref("sessions/$sessionId").get();
      if (!snapshot.exists) {
        _isLoadingTeam = false;
        notifyListeners();
        return false;
      }
    }

    _sessionSubscription?.cancel();

    _currentSessionId = sessionId;
    _teamLocations.clear();
    _targetUser = null;
    _routePoints.clear();
    _distance = 0.0;
    _isSearching = false;
    _isLoadingTeam = false;
    notifyListeners();

    if (_myLocation != null && _userName.isNotEmpty) {
      await dbRef.ref("sessions/$sessionId/users/$_userName").set({
        "name": _userName,
        "lat": _myLocation!.latitude,
        "lng": _myLocation!.longitude,
        "last_seen": ServerValue.timestamp,
      });
    }

    _sessionSubscription = dbRef
        .ref("sessions/$sessionId/users")
        .onValue
        .listen((event) {
          final data = event.snapshot.value as Map?;
          if (data != null && _userName.isNotEmpty) {
            Map<String, LatLng> newTeam = {};
            data.forEach((key, value) {
              if (key != _userName) {
                newTeam[key] = LatLng(
                  (value['lat'] as num).toDouble(),
                  (value['lng'] as num).toDouble(),
                );
              }
            });

            _teamLocations = newTeam;
            _isLoadingTeam = false;
            if (_targetUser == null && newTeam.isNotEmpty) {
              _targetUser = newTeam.keys.first;
            }

            if (_targetUser != null && newTeam.containsKey(_targetUser)) {
              updateRoadRoute(newTeam[_targetUser]!);
            } else {
              notifyListeners();
            }
          }
        });

    return true;
  }

  void selectTargetUser(String name) {
    if (!_teamLocations.containsKey(name)) return;
    _routePoints.clear();
    _targetUser = name;
    notifyListeners();
    updateRoadRoute(_teamLocations[name]!);
  }

  Future<void> updateRoadRoute(LatLng destination) async {
    if (_myLocation == null) return;

    final url =
        'https://router.project-osrm.org/route/v1/driving/'
        '${_myLocation!.longitude},${_myLocation!.latitude};'
        '${destination.longitude},${destination.latitude}?overview=full&geometries=geojson';

    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final List coords = data['routes'][0]['geometry']['coordinates'];
          _routePoints = coords
              .map((c) => LatLng(c[1].toDouble(), c[0].toDouble()))
              .toList();
          _distance = (data['routes'][0]['distance'] as num).toDouble();
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("Routing Error: $e");
    }
  }

  Future<LatLng?> searchPlace(String query) async {
    if (query.isEmpty) return null;

    try {
      final snapshot = await FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: _dbUrl,
      ).ref("places").get();

      final data = snapshot.value as Map?;
      if (data != null) {
        for (var entry in data.entries) {
          final v = entry.value as Map;
          if (v['name'].toString().toLowerCase().contains(
            query.toLowerCase(),
          )) {
            LatLng target = LatLng(
              (v['lat'] as num).toDouble(),
              (v['lng'] as num).toDouble(),
            );
            _isSearching = false;
            notifyListeners();
            updateRoadRoute(target);
            return target;
          }
        }
      }
    } catch (e) {
      debugPrint("Search error: $e");
    }
    return null;
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _sessionSubscription?.cancel();
    super.dispose();
  }
}
