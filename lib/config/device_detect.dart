// import 'imports.dart';

// class DeviceDetect {
//   static bool isRootDevice = false;
//   Future<void> detectRoot() async {
//     final rootJailbreakDetectorPlugin = RootJailbreakDetector();
//     try {
//       isRootDevice = (await rootJailbreakDetectorPlugin.isRooted() ?? false);
//     } catch (_) {
//       isRootDevice = false;
//     }
//     if (isRootDevice) {
//       Navigator.push(
//         navigatorKey.currentContext!,
//         MaterialPageRoute(builder: (context) => RootDetectionScreen()),
//       );
//     }
//   }
// }
