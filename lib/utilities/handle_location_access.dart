import 'package:gps_tracker/config/imports.dart';

class HandleLocationAccess {
  Future<void> handleLocationAccess() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await _showPermissionDialog(
        title: "GPS Disabled",
        content: "Please enable location services in your system settings.",
        onConfirm: () => Geolocator.openLocationSettings(),
      );
      return;
    }
    permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showPermissionDialog(
          title: "Permission Required",
          content: "This app needs location access to track your journey.",
          onConfirm: () => handleLocationAccess(),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      await _showPermissionDialog(
        title: "Permission Permanently Denied",
        content:
            "You have disabled location permissions. Please enable them in app settings to continue.",
        onConfirm: () => Geolocator.openAppSettings(),
      );
      return;
    }
  }

  Future<void> _showPermissionDialog({
    required String title,
    required String content,
    required VoidCallback onConfirm,
  }) {
    return showDialog(
      context: currentContext!,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: const Text("Open Settings"),
          ),
        ],
      ),
    );
  }
}
