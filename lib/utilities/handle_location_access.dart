import 'package:gps_tracker/config/imports.dart';

class HandleLocationAccess {
  Future<void> showPermissionDialog({
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
