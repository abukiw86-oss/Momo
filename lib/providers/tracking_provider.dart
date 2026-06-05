import 'dart:async';
import 'package:latlong2/latlong.dart';
import 'package:gps_tracker/config/imports.dart';

class TrackingProvider extends ChangeNotifier {
  final dbRef = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: dotenv.get('DB_URL', fallback: 'Fallback URL if not found'),
  );
  final internetCheck = InternetChecker();
  static final Dio _dio = Dio();
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
  bool _isSessionCreator = false;
  bool _isRequiredData = false;

  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<DatabaseEvent>? _sessionSubscription;

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
  bool get isSessionCreator => _isSessionCreator;
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
        timeLimit: Duration(seconds: 7),
      );

      _myLocation = LatLng(position.latitude, position.longitude);
      notifyListeners();
    } catch (e) {
      debugPrint("Error in initializeTracking: $e");
      if (_myLocation == null) {
        _myLocation = const LatLng(9.0054, 38.7636);
        initializeTracking();
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
    bool isOnline = await internetCheck.quickCheck();
    if (!isOnline) {
      ShowSnackbar().show(message: 'Check Your Internet Connection ');
      return;
    }

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
    bool isOnline = await internetCheck.quickCheck();
    if (!isOnline) {
      ShowSnackbar().show(message: 'Check Your Internet Connection ');
      return false;
    }

    _isLoadingTeam = true;
    notifyListeners();

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
    _isLoadingTeam = false;
    notifyListeners();

    if (_myLocation != null && _userName.isNotEmpty && _email.isNotEmpty) {
      if (isCreatingSession) {
        final creatorSnapshot = await dbRef
            .ref("sessions/$sessionId/Creator")
            .get();

        if (!creatorSnapshot.exists) {
          await dbRef.ref("sessions/$sessionId/Creator").set({
            "user_id": _userId,
            "email": _email,
            "name": _userName,
            "created_at": ServerValue.timestamp,
          });
        }
      }
      await dbRef.ref("sessions/$sessionId/users/$_userId").set({
        "email": _email,
        "name": _userName,
        "lat": _myLocation!.latitude,
        "lng": _myLocation!.longitude,
        "last_seen": ServerValue.timestamp,
        "joined_at": ServerValue.timestamp,
      });
    }

    await checkIfUserIsCreator();

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
            selectTargetUser(_targetUser!);
          }
        });

    return true;
  }

  void selectTargetUser(String userId) {
    if (!_teamLocations.containsKey(userId)) return;
    _routePoints.clear();
    _targetUser = userId;
    notifyListeners();
    updateRoadRoute(
      LatLng(_teamLocations[userId]!['lat'], _teamLocations[userId]!['lng']),
    );
  }

  Future<void> deleteSession() async {
    if (_currentSessionId == null) {
      ShowSnackbar().show(message: "No active session to delete");
      return;
    }

    bool isOnline = await internetCheck.quickCheck();
    if (!isOnline) {
      ShowSnackbar().show(message: 'Check your internet connection');
      return;
    }

    _isLoadingTeam = true;
    notifyListeners();

    try {
      if (!_isSessionCreator) {
        _isLoadingTeam = false;
        notifyListeners();
        ShowSnackbar().show(
          message: "Only the session creator can delete this session",
        );
        return;
      }

      await dbRef.ref("sessions/$_currentSessionId").remove();

      _clearLocalSessionData();

      ShowSnackbar().show(message: "Session deleted successfully");
    } catch (e) {
      debugPrint("Error deleting session: $e");
      _isLoadingTeam = false;
      notifyListeners();
      ShowSnackbar().show(message: "Error deleting session: $e");
    }
  }

  Future<void> updateRoadRoute(LatLng destination) async {
    if (_myLocation == null) return;
    bool isOnline = await internetCheck.quickCheck();
    if (!isOnline) {
      ShowSnackbar().show(message: 'Check Your Internet Connection ');
      return;
    }
    final url =
        'https://router.project-osrm.org/route/v1/driving/'
        '${_myLocation!.longitude},${_myLocation!.latitude};'
        '${destination.longitude},${destination.latitude}?overview=full&geometries=geojson';

    try {
      final res = await _dio.get(url);
      if (res.statusCode == 200) {
        final data = res.data;
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

  Future<void> leaveSession() async {
    if (_currentSessionId == null) {
      ShowSnackbar().show(message: "No active session to leave");
      return;
    }
    final isOnline = await internetCheck.quickCheck();
    if (!isOnline) {
      ShowSnackbar().show(
        message:
            'No internet connection. You will be removed when back online.',
      );
      return;
    }
    if (_isSessionCreator) {
      await deleteSession();
    }

    _isLoadingTeam = true;
    notifyListeners();

    try {
      await dbRef.ref("sessions/$_currentSessionId/users/$_userId").remove();

      final remainingUsers = await dbRef
          .ref("sessions/$_currentSessionId/users")
          .get();
      if (!remainingUsers.exists ||
          (remainingUsers.value as Map?)?.isEmpty == true) {
        await deleteSession();
        debugPrint("Session deleted as no users remaining");
      }
      _clearLocalSessionData();
      ShowSnackbar().show(message: "Left session successfully");
    } catch (e) {
      debugPrint("Error leaving session: $e");
      _isLoadingTeam = false;
      notifyListeners();

      ShowSnackbar().show(
        message: "Left session locally. Will sync when online. $e",
      );
    }
  }

  Future<void> checkIfUserIsCreator() async {
    if (_currentSessionId == null) return;
    final creatorSnapshot = await dbRef
        .ref("sessions/$_currentSessionId/Creator")
        .get();

    if (creatorSnapshot.exists) {
      final creatorData = creatorSnapshot.value as Map;
      final creatorId = creatorData['user_id']?.toString();
      _isSessionCreator = (creatorId == _userId);
      notifyListeners();
    }
  }

  void _clearLocalSessionData() {
    _sessionSubscription?.cancel();
    _currentSessionId = null;
    _teamLocations.clear();
    _targetUser = null;
    _isSessionCreator = false;
    _routePoints.clear();
    _distance = 0.0;
    _isLoadingTeam = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _sessionSubscription?.cancel();
    super.dispose();
  }
}
