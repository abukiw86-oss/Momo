import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:gps_tracker/config/imports.dart';

class TrackingProvider extends ChangeNotifier {
  final dbRef = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: dotenv.get('DB_URL', fallback: 'Fallback URL if not found'),
  );

  LatLng? _myLocation;
  Map<String, Map<String, dynamic>> _teamLocations = {};
  List<LatLng> _routePoints = [];
  double _distance = 0.0;
  String? _targetUser;
  String _userName = "";
  String _email = "";
  String _userId = "";
  String? _currentSessionId;
  bool _isLoadingTeam = false;
  bool _isRequiredData = false;

  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<DatabaseEvent>? _sessionSubscription;

  // Getters
  LatLng? get myLocation => _myLocation;
  Map<String, Map<String, dynamic>> get teamLocations => _teamLocations;
  List<LatLng> get routePoints => _routePoints;
  double get distance => _distance;
  String? get targetUser => _targetUser;
  String get userName => _userName;
  String get email => _email;
  String get userId => _userId;
  String? get currentSessionId => _currentSessionId;
  bool get isRequiredData => _isRequiredData;
  bool get isLoadingTeam => _isLoadingTeam;

  Future<void> initialData({VoidCallback? onDataRequired}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? savedName = prefs.getString('user_name');
      String? savedEmail = prefs.getString('email');
      String? savedUserId = prefs.getString('user_id');
      initializeTracking();
      if (savedName == null || savedEmail == null || savedUserId == null) {
        if (onDataRequired == null) {
          ShowRegisterDialogue().showDialog();
        } else {
          onDataRequired();
        }
        _isRequiredData = true;
        notifyListeners();
      } else {
        _userName = savedName;
        _email = savedEmail;
        _userId = savedUserId;
        notifyListeners();
        startLocalTracking();
      }
    } catch (e) {
      debugPrint("Error in loading data: $e");
    }
  }

  Future<void> initializeTracking() async {
    try {
      Position? lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        _myLocation = LatLng(lastKnown.latitude, lastKnown.longitude);
        notifyListeners();
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );

      _myLocation = LatLng(position.latitude, position.longitude);
      notifyListeners();
    } catch (e) {
      debugPrint("Error in initializeTracking: $e");
      if (_myLocation == null) {
        _myLocation = const LatLng(9.0054, 38.7636);
        notifyListeners();
      }
    }
  }

  Future<void> saveUserData(
    String name, {
    required String email,
    bool isLogin = false,
  }) async {
    if (isLogin && email.isEmpty) return;
    if (!isLogin && name.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();

    if (isLogin) {
      final snapshot = await dbRef
          .ref("users")
          .orderByChild("email")
          .equalTo(email)
          .get();

      if (snapshot.exists) {
        final userData = snapshot.children.first;
        final userId = userData.key!;

        await dbRef.ref("users/$userId").update({
          "last_login": ServerValue.timestamp,
        });

        _userName = userData.child("name").value.toString();
        _email = email;
        _userId = userId;
        notifyListeners();
        await prefs.setString('user_name', _userName);
        await prefs.setString('email', email);
        await prefs.setString('user_id', userId);
      } else {
        await initialData(onDataRequired: ShowRegisterDialogue().showDialog);
        ShowSnackbar().show(message: "your email was not found");
      }
    } else {
      final snapshot = await dbRef
          .ref("users")
          .orderByChild("email")
          .equalTo(email)
          .get();

      if (snapshot.exists) {
        initialData(onDataRequired: ShowRegisterDialogue().showDialog);
        ShowSnackbar().show(message: "Email already registered");
      } else {
        final newUserRef = dbRef.ref("users").push();
        await newUserRef.set({
          "name": name,
          "email": email,
          "created_at": ServerValue.timestamp,
          "last_login": ServerValue.timestamp,
        });

        _userName = name;
        _email = email;
        _userId = newUserRef.key!;
        notifyListeners();
        await prefs.setString('user_name', name);
        await prefs.setString('email', email);
        await prefs.setString('user_id', newUserRef.key!);
      }
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
          dbRef.ref("users/$_userId").update({
            "lat": position.latitude,
            "lng": position.longitude,
            "last_seen": ServerValue.timestamp,
          });
          notifyListeners();
          if (_currentSessionId != null && _email.isNotEmpty) {
            _isLoadingTeam = false;
            notifyListeners();
            dbRef.ref("sessions/$_currentSessionId/users/$_userId/").update({
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
    if (!isCreatingSession) {
      final snapshot = await dbRef.ref("sessions/$sessionId").get();
      print(snapshot.value);
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
    _isLoadingTeam = false;
    notifyListeners();

    if (_myLocation != null && _userName.isNotEmpty && _email.isNotEmpty) {
      await dbRef.ref("sessions/$sessionId/users/$_userId").set({
        "email": _email,
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
          if (data != null && _userId.isNotEmpty) {
            Map<String, Map<String, dynamic>> newTeam = {};
            data.forEach((key, value) {
              if (key != _userId) {
                final userMap = value as Map;
                newTeam[key] = {
                  'name': userMap['name']?.toString() ?? 'Unknown',
                  'email': userMap['email']?.toString() ?? '',
                  'lat': (userMap['lat'] as num).toDouble(),
                  'lng': (userMap['lng'] as num).toDouble(),
                  'last_seen': userMap['last_seen'],
                };
              }
            });

            _teamLocations = newTeam;
            _isLoadingTeam = false;

            if (_targetUser == null && newTeam.isNotEmpty) {
              _targetUser = newTeam.keys.first;
            }
            notifyListeners();
          }
        });

    return true;
  }

  void selectTargetUser(String userId) {
    if (!_teamLocations.containsKey(userId)) return;
    _routePoints.clear();
    _targetUser = userId;
    notifyListeners();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _sessionSubscription?.cancel();
    super.dispose();
  }
}
