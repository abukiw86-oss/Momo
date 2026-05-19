import 'config/imports.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    print('Error loading .env file: $e');
  }
  await Firebase.initializeApp();
  runApp(
    ChangeNotifierProvider(
      create: (context) => TrackingProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Momo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Team Momo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _handleLocationAccess();
  }

  Future<void> _handleLocationAccess() async {
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
          onConfirm: () => _handleLocationAccess(),
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

    setState(() => _isLoading = false);
  }

  Future<void> _showPermissionDialog({
    required String title,
    required String content,
    required VoidCallback onConfirm,
  }) {
    return showDialog(
      context: context,
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return const FreeTrackerMap();
  }
}
