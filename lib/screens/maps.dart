import 'package:screenshot/screenshot.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as maplibre;
import '../config/imports.dart';

class FreeTrackerMap extends StatefulWidget {
  const FreeTrackerMap({super.key});

  @override
  State<FreeTrackerMap> createState() => _FreeTrackerMapState();
}

class _FreeTrackerMapState extends State<FreeTrackerMap> {
  maplibre.MapLibreMapController? _mapController;
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isStyleLoaded = false;
  static const double zoom = 10.8;
  double _currentTilt = 60.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<TrackingProvider>(context, listen: false);
      provider.initialData(onDataRequired: ShowRegisterDialogue().showDialog);
    });
  }

  void _onMapCreated(maplibre.MapLibreMapController controller) {
    _mapController = controller;
  }

  void _onStyleLoaded() {
    setState(() {
      _isStyleLoaded = true;
    });
    _enable3dBuildings();
    _updateMapElements();
  }

  void _enable3dBuildings() {
    if (_mapController == null) return;
    _mapController!.addFillExtrusionLayer(
      "openfreemap",
      "3d-buildings-layer",
      const maplibre.FillExtrusionLayerProperties(
        fillExtrusionColor: "#ffffff",
        fillExtrusionHeight: ["get", "render_height"],
        fillExtrusionBase: ["get", "render_min_height"],
        fillExtrusionOpacity: 1.0,
      ),
    );
  }

  void _updateMapElements() async {
    if (_mapController == null || !_isStyleLoaded) return;
    final provider = Provider.of<TrackingProvider>(context, listen: false);

    _mapController!.clearLines();
    _mapController!.clearSymbols();

    if (provider.routePoints.isNotEmpty) {
      List<maplibre.LatLng> mapLibrePoints = provider.routePoints
          .map((p) => maplibre.LatLng(p.latitude, p.longitude))
          .toList();

      await _mapController!.addLine(
        maplibre.LineOptions(
          geometry: mapLibrePoints,
          lineColor: "#0000FF",
          lineWidth: 5.0,
          lineOpacity: 0.8,
        ),
      );
    }

    for (var entry in provider.teamLocations.entries) {
      String userId = entry.key;
      Map<String, dynamic> userData = entry.value;
      bool isTracked = userId == provider.targetUser;

      Widget markerUi = _markerWidget(
        userData['name'] ?? 'Unknown',
        isTracked ? Colors.green : Colors.red,
        logoUrl: 'assets/images/appa.jpeg',
      );

      Uint8List? imageBytes = await _screenshotController.captureFromWidget(
        markerUi,
        pixelRatio: MediaQuery.of(context).devicePixelRatio,
        delay: const Duration(milliseconds: 50),
      );
      if (imageBytes.isEmpty) continue;

      String symbolImageKey = "marker_$userId";

      try {
        await _mapController!.addImage(symbolImageKey, imageBytes);
      } catch (e) {
        debugPrint("Error adding symbol image: $e");
      }

      await _mapController!.addSymbol(
        maplibre.SymbolOptions(
          geometry: maplibre.LatLng(userData['lat'], userData['lng']),
          iconImage: symbolImageKey,
          iconSize: 1.0,
        ),
      );
    }
  }

  void _joinSession(String sessionId, bool isCreatingSession) async {
    final provider = Provider.of<TrackingProvider>(context, listen: false);
    bool success = await provider.joinOrCreateSession(
      sessionId,
      isCreatingSession: isCreatingSession,
    );
    if (!mounted) return;
    if (!success) {
      ShowSnackbar().show(message: "Session not found. Please check the code.");
    }
  }

  Widget _markerWidget(
    String label,
    Color color, {
    String logoUrl = 'assets/images/momo.png',
  }) {
    return Material(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Icon(Icons.location_on, color: color, size: 70),
              Positioned(
                top: 6,
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white,
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.transparent,
                    backgroundImage: AssetImage(logoUrl),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TrackingProvider>(
      builder: (context, provider, child) {
        if (_mapController != null && _isStyleLoaded) {
          _updateMapElements();

          if (provider.myLocation != null) {
            _mapController!.animateCamera(
              maplibre.CameraUpdate.newCameraPosition(
                maplibre.CameraPosition(
                  target: maplibre.LatLng(
                    provider.myLocation!.latitude,
                    provider.myLocation!.longitude,
                  ),
                  zoom: zoom,
                  tilt: _currentTilt,
                  bearing: -10.0,
                ),
              ),
            );
          }
        }

        return Scaffold(
          extendBodyBehindAppBar: true,
          drawer: Drawer(
            width: MediaQuery.of(context).size.width * 0.85,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
            child: Column(
              children: [
                Center(
                  child: UserAccountsDrawerHeader(
                    onDetailsPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ChangeLogoScreen(),
                        ),
                      );
                    },
                    currentAccountPicture: const CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.transparent,
                      backgroundImage: AssetImage('assets/images/momo.png'),
                    ),
                    accountName: Text(provider.userName),
                    accountEmail: Text(
                      "Session: ${provider.currentSessionId ?? 'None'}",
                    ),
                    decoration: const BoxDecoration(color: Colors.blue),
                  ),
                ),
                const ListTile(
                  title: Text(
                    "Group Members",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: provider.teamLocations.isEmpty
                      ? const Center(child: Text("No one joined yet"))
                      : ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: provider.teamLocations.length,
                          itemBuilder: (context, index) {
                            String userId = provider.teamLocations.keys
                                .elementAt(index);
                            Map<String, dynamic> userData =
                                provider.teamLocations[userId]!;
                            return ListTile(
                              title: Text(userData['name'] ?? 'Unknown'),
                              subtitle: Text(userData['email'] ?? 'No email'),
                              leading: const CircleAvatar(
                                backgroundColor: Colors.transparent,
                                backgroundImage: AssetImage(
                                  'assets/images/momo.png',
                                ),
                              ),
                              onTap: () {
                                provider.selectTargetUser(userId);
                                if (_mapController != null) {
                                  _mapController!.animateCamera(
                                    maplibre.CameraUpdate.newLatLngZoom(
                                      maplibre.LatLng(
                                        userData['lat'],
                                        userData['lng'],
                                      ),
                                      zoom,
                                    ),
                                  );
                                }
                                Navigator.pop(context);
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
                    const String appLink =
                        "https://github.com/abukiw86-oss/Momo/releases/latest";
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
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(
              "Hi, ${provider.userName} ${(provider.currentSessionId != null)
                  ? '(${provider.currentSessionId})'
                  : (provider.isLoadingTeam)
                  ? '(Loading Session...)'
                  : ''}",
            ),
            actions: [
              const ThemeToggleButton(),
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: () {
                  ShowSnackbar().show(
                    message: "Searching will come in the next update!",
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.join_full),
                onPressed: () => _showSessionDialog(provider),
              ),
            ],
          ),
          body: Stack(
            children: [
              maplibre.MapLibreMap(
                initialCameraPosition: maplibre.CameraPosition(
                  target: provider.myLocation != null
                      ? maplibre.LatLng(
                          provider.myLocation!.latitude,
                          provider.myLocation!.longitude,
                        )
                      : const maplibre.LatLng(9.0054, 38.7636),
                  zoom: zoom,
                ),
                styleString:
                    "https://tiles.stadiamaps.com/styles/outdoors.json?api_key=${dotenv.env['MAP_API_KEY']}",
                onMapCreated: _onMapCreated,
                onStyleLoadedCallback: _onStyleLoaded,
                myLocationEnabled: true,
                myLocationTrackingMode:
                    maplibre.MyLocationTrackingMode.tracking,
              ),
              Positioned(
                right: 10,
                top: MediaQuery.of(context).size.height * 0.25,
                bottom: MediaQuery.of(context).size.height * 0.25,
                child: _buildTiltAdjuster(),
              ),
              Positioned(
                bottom: 30,
                left: 10,
                right: 10,
                child: _buildDistanceCard(provider),
              ),
              Positioned(
                left: 20,
                bottom: 130,
                child: FloatingActionButton(
                  backgroundColor: Colors.blueAccent,
                  child: const Icon(Icons.my_location, color: Colors.white),
                  onPressed: () {
                    if (provider.myLocation != null && _mapController != null) {
                      _mapController!.animateCamera(
                        maplibre.CameraUpdate.newCameraPosition(
                          maplibre.CameraPosition(
                            target: maplibre.LatLng(
                              provider.myLocation!.latitude,
                              provider.myLocation!.longitude,
                            ),
                            zoom: zoom,
                            tilt: _currentTilt,
                          ),
                        ),
                      );
                    } else {
                      ShowSnackbar().show(message: "Locating you...");
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSessionDialog(TrackingProvider provider) {
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
              if (provider.currentSessionId != null) ...[
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
                      const Text(
                        "Active Group Code",
                        style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                      ),
                      const SizedBox(height: 5),
                      SelectableText(
                        provider.currentSessionId!,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 3,
                          color: Colors.blue,
                        ),
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
                          Clipboard.setData(
                            ClipboardData(text: provider.currentSessionId!),
                          );
                          Share.share(
                            "Track me on Momo! Group Code: ${provider.currentSessionId} \n Get the app here: https://github.com/abukiw86-oss/Momo/releases/latest",
                          );
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
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 45),
                ),
                icon: const Icon(Icons.group_add),
                label: const Text("Create New Group"),
                onPressed: () {
                  String newId = const Uuid()
                      .v4()
                      .substring(0, 6)
                      .toUpperCase();
                  Navigator.pop(context);
                  _joinSession(newId, true);
                  Share.share(
                    "Join my location group! Code: $newId \n Get the app here: https://github.com/abukiw86-oss/Momo/releases/latest",
                  );
                },
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 15),
                child: Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        "OR JOIN",
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
              ),
              TextField(
                controller: sessionCtrl,
                textAlign: TextAlign.center,
                maxLength: 6,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
                decoration: InputDecoration(
                  hintText: "CODE",
                  counterText: "",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
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
          ),
        ],
      ),
    );
  }

  Widget _buildTiltAdjuster() {
    return Card(
      shadowColor: Colors.black,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 4.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.layers_clear_rounded,
              size: 18,
              color: Colors.blueAccent,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: RotatedBox(
                quarterTurns:
                    3, // Rotates the slider counter-clockwise to point vertically UP
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 8,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 14,
                    ),
                  ),
                  child: Slider(
                    value: _currentTilt,
                    min: 0.0, // Flat overhead 2D view
                    max: 85.0, // Deep 3D perspective horizon limit
                    activeColor: Colors.blueAccent,
                    inactiveColor: Colors.grey[300],
                    onChanged: (newValue) {
                      setState(() {
                        _currentTilt = newValue;
                      });

                      if (_mapController != null) {
                        _mapController!.moveCamera(
                          maplibre.CameraUpdate.bearingTo(
                            _mapController!.cameraPosition!.bearing,
                          ),
                        );
                        _mapController!.moveCamera(
                          maplibre.CameraUpdate.tiltTo(_currentTilt),
                        );
                      }
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "${_currentTilt.toStringAsFixed(0)}°",
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistanceCard(TrackingProvider provider) {
    bool isTrackingOthers =
        provider.targetUser != null &&
        provider.teamLocations.containsKey(provider.targetUser);
    if (provider.myLocation == null || provider.isLoadingTeam) {
      return _buildShimmerCard();
    }
    final targetUserData = isTrackingOthers
        ? provider.teamLocations[provider.targetUser]
        : null;
    final displayLocation = isTrackingOthers && targetUserData != null
        ? maplibre.LatLng(targetUserData['lat'], targetUserData['lng'])
        : maplibre.LatLng(
            provider.myLocation!.latitude,
            provider.myLocation!.longitude,
          );

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: isTrackingOthers
                ? Colors.green
                : Colors.blueAccent,
            child: Icon(
              isTrackingOthers ? Icons.navigation : Icons.person_pin_circle,
              color: Colors.white,
            ),
          ),
          title: Text(
            isTrackingOthers && targetUserData != null
                ? (targetUserData['name'] ?? 'Unknown')
                : "My Location (Solo)",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              if (isTrackingOthers)
                Text(
                  "Distance: ${provider.distance < 1000 ? '${provider.distance.toStringAsFixed(0)} m' : '${(provider.distance / 1000).toStringAsFixed(2)} km'}",
                  style: const TextStyle(color: Colors.black87),
                )
              else
                const Text(
                  "Not tracking anyone else",
                  style: TextStyle(color: Colors.grey),
                ),
              const SizedBox(height: 2),
              Text(
                "Lat: ${displayLocation.latitude.toStringAsFixed(5)}, Lng: ${displayLocation.longitude.toStringAsFixed(5)}",
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          trailing: IconButton(
            icon: const Icon(
              Icons.people_alt_rounded,
              color: Colors.blueAccent,
            ),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerCard() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[700]!,
      highlightColor: Colors.grey[100]!,
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 150,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
