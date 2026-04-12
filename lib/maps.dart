import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:geolocator/geolocator.dart';

class LiveTrackerMap extends StatefulWidget {
  const LiveTrackerMap({super.key});

  @override
  State<LiveTrackerMap> createState() => _LiveTrackerMapState();
}

class _LiveTrackerMapState extends State<LiveTrackerMap> {
  GoogleMapController? _mapController;
  
  // Locations
  LatLng? _myLocation;
  LatLng? _otherLocation;
  
  // UI Data
  double _distance = 0.0;
  final String _dbUrl = "https://gps-tracker-de7dc-default-rtdb.europe-west1.firebasedatabase.app";

  @override
  void initState() {
    super.initState();
    _startTrackingLogic();
  }

  void _startTrackingLogic() {
    // 1. Listen to MY Real-time Location (From Phone Hardware)
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 2),
    ).listen((Position position) {
      setState(() {
        _myLocation = LatLng(position.latitude, position.longitude);
      });
      _updateCalculations();
    });

    // 2. Listen to OTHER Person's Location (From Firebase)
    // We are listening to 'driver_1' which you successfully set up
    FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: _dbUrl)
        .ref("drivers/driver_1")
        .onValue
        .listen((event) {
      final data = event.snapshot.value as Map?;
      if (data != null) {
        setState(() {
          _otherLocation = LatLng(data['lat'], data['lng']);
        });
        _updateCalculations();
      }
    });
  }

  void _updateCalculations() {
    if (_myLocation != null && _otherLocation != null) {
      // Calculate Distance
      double distanceInMeters = Geolocator.distanceBetween(
        _myLocation!.latitude, _myLocation!.longitude,
        _otherLocation!.latitude, _otherLocation!.longitude,
      );
      
      setState(() {
        _distance = distanceInMeters;
      });

      // Auto-zoom map to show both markers
      _fitMapToMarkers();
    }
  }

  void _fitMapToMarkers() {
    if (_myLocation == null || _otherLocation == null) return;

    LatLngBounds bounds;
    if (_myLocation!.latitude > _otherLocation!.latitude) {
      bounds = LatLngBounds(southwest: _otherLocation!, northeast: _myLocation!);
    } else {
      bounds = LatLngBounds(southwest: _myLocation!, northeast: _otherLocation!);
    }
    _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("One-to-One Tracker"),
        backgroundColor: Colors.blueAccent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(30),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              "Distance: ${(_distance / 1000).toStringAsFixed(2)} km",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
      body: _myLocation == null
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
              initialCameraPosition: CameraPosition(target: _myLocation!, zoom: 14),
              onMapCreated: (controller) => _mapController = controller,
              markers: _createMarkers(),
              polylines: _createPolylines(),
            ),
    );
  }

  Set<Marker> _createMarkers() {
    return {
      if (_myLocation != null)
        Marker(
          markerId: const MarkerId("me"),
          position: _myLocation!,
          infoWindow: const InfoWindow(title: "My Position"),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
      if (_otherLocation != null)
        Marker(
          markerId: const MarkerId("them"),
          position: _otherLocation!,
          infoWindow: const InfoWindow(title: "Driver 1"),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
    };
  }

  Set<Polyline> _createPolylines() {
    if (_myLocation == null || _otherLocation == null) return {};
    return {
      Polyline(
        polylineId: const PolylineId("route"),
        points: [_myLocation!, _otherLocation!],
        color: Colors.blue,
        width: 4,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)], // Dotted line
      ),
    };
  }
}