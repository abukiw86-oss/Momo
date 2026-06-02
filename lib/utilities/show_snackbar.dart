import 'package:gps_tracker/config/imports.dart';

class ShowSnackbar {
  void show({required String message}) {
    ScaffoldMessenger.of(
      navigatorKey.currentContext!,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
