import 'package:maplibre_gl/maplibre_gl.dart' as maplibre;
import '../config/imports.dart';

class FreeTrackerMap extends StatefulWidget {
  const FreeTrackerMap({super.key});

  @override
  State<FreeTrackerMap> createState() => _FreeTrackerMapState();
}

class _FreeTrackerMapState extends State<FreeTrackerMap> {
  maplibre.MapLibreMapController? _mapController;
  final DraggableScrollableController _bottomSheetController =
      DraggableScrollableController();
  bool _isStyleLoaded = false;
  static const double zoom = 15.6;
  double _currentTilt = 65.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<TrackingProvider>(context, listen: false);
      provider.initialData(onDataRequired: ShowRegisterDialogue().showDialog);
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      themeProvider.addListener(_onThemeChanged);
    });
  }

  void _onMapCreated(maplibre.MapLibreMapController controller) {
    _mapController = controller;
  }

  void _onStyleLoaded() async {
    setState(() {
      _isStyleLoaded = true;
    });
    _enable3dBuildings();
    _updateMapElements();

    final provider = Provider.of<TrackingProvider>(context, listen: false);

    provider.addListener(() {
      if (mounted && _mapController != null && _isStyleLoaded) {
        _updateMapElements();
      }
    });
  }

  void _trackTeam(TrackingProvider provider) {
    if (provider.currentSessionId == null || provider.targetUser == null)
      return;
    final trackingMember = maplibre.LatLng(
      provider.teamLocations[provider.targetUser]!['lat'],
      provider.teamLocations[provider.targetUser]!['lng'],
    );
    _mapController!.animateCamera(
      maplibre.CameraUpdate.newCameraPosition(
        maplibre.CameraPosition(
          target: trackingMember,
          zoom: zoom,
          tilt: _currentTilt,
          bearing: -10.0,
        ),
      ),
    );
  }

  void _onThemeChanged() {
    if (_mapController != null && _isStyleLoaded) {
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      final newStyle = themeProvider.isDarkMode
          ? "https://tiles.openfreemap.org/styles/dark"
          : "https://tiles.openfreemap.org/styles/liberty";

      try {
        _mapController!.setStyle(newStyle);
      } catch (e) {
        setState(() {});
      }
    }
  }

  String _getStyleString(bool isDarkMode) {
    return isDarkMode
        ? "https://tiles.openfreemap.org/styles/dark"
        : "https://tiles.openfreemap.org/styles/liberty";
  }

  void _enable3dBuildings() {
    if (_mapController == null) return;

    _mapController!.addFillExtrusionLayer(
      "openfreemap",
      "3d-buildings-layer",
      maplibre.FillExtrusionLayerProperties(
        fillExtrusionColor: [
          "match",
          ["get", "type"],
          "house",
          "#D4A574",
          "apartments",
          "#B8C9A5",
          "commercial",
          "#85C1E9",
          "industrial",
          "#BDC3C7",
          "school",
          "#F9E79F",
          "hospital",
          "#F5B7B1",
          "cathedral",
          "#D7BDE2",
          "parking",
          "#AAB7B8",
          [
            "interpolate",
            ["linear"],
            ["get", "render_height"],
            0,
            "#C8D5B9",
            15,
            "#F4D03F",
            30,
            "#E67E22",
            50,
            "#E74C3C",
            80,
            "#8E44AD",
            150,
            "#2C3E50",
          ],
        ],

        fillExtrusionHeight: [
          "let",
          "height",
          ["get", "render_height"],
          [
            "case",
            [
              ">=",
              ["var", "height"],
              100,
            ],
            [
              "*",
              ["var", "height"],
              2.5,
            ],
            [
              ">=",
              ["var", "height"],
              50,
            ],
            [
              "*",
              ["var", "height"],
              1.8,
            ],
            [
              ">=",
              ["var", "height"],
              20,
            ],
            [
              "*",
              ["var", "height"],
              1.3,
            ],
            [
              "*",
              ["var", "height"],
              1.0,
            ],
          ],
        ],

        fillExtrusionBase: ["get", "render_min_height"],
        fillExtrusionOpacity: 0.92,
        fillExtrusionTranslate: const Offset(2.0, 2.0),
        fillExtrusionTranslateAnchor: "map",
        fillExtrusionVerticalGradient: true,
      ),
    );
    _addBuildingGlow();
  }

  void _addBuildingGlow() {
    if (_mapController == null) return;
    _mapController!.addFillExtrusionLayer(
      "openfreemap",
      "3d-buildings-glow",
      maplibre.FillExtrusionLayerProperties(
        fillExtrusionColor: [
          "interpolate",
          ["linear"],
          ["get", "render_height"],
          0,
          "rgba(255, 255, 255, 0)",
          50,
          "rgba(255, 200, 100, 0.2)",
          100,
          "rgba(255, 150, 50, 0.3)",
          150,
          "rgba(255, 100, 0, 0.4)",
        ],
        fillExtrusionHeight: ["get", "render_height"],
        fillExtrusionBase: ["get", "render_min_height"],
        fillExtrusionOpacity: 0.3,
      ),
    );
  }

  void _updateMapElements() async {
    if (_mapController == null || !_isStyleLoaded) return;
    final provider = Provider.of<TrackingProvider>(context, listen: false);

    await _mapController!.clearSymbols();
    await _mapController!.clearCircles();
    await _mapController!.clearLines();
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
          lineJoin: "round",
        ),
      );
    }

    for (var entry in provider.teamLocations.entries) {
      String userId = entry.key;
      Map<String, dynamic> userData = entry.value;
      bool isTracked = userId == provider.targetUser;

      final double userLat = (userData['lat'] as num?)?.toDouble() ?? 0.0;
      final double userLng = (userData['lng'] as num?)?.toDouble() ?? 0.0;
      if (userLat == 0.0 || userLng == 0.0) continue;

      String statusColorHex = isTracked ? "#00FF00" : "#FF0000";
      await _mapController!.addCircle(
        maplibre.CircleOptions(
          geometry: maplibre.LatLng(userLat, userLng),
          circleRadius: 8.0,
          circleColor: statusColorHex,
          circleStrokeWidth: 2.0,
          circleStrokeColor: "#FFFFFF",
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

  @override
  void dispose() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    themeProvider.removeListener(_onThemeChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<TrackingProvider, ThemeProvider>(
      builder: (context, provider, themeProvider, child) {
        return Scaffold(
          extendBodyBehindAppBar: true,
          drawer: Drawer(
            width: MediaQuery.of(context).size.width * 0.82,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
            child: Column(
              children: [
                UserAccountsDrawerHeader(
                  currentAccountPicture: const CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.transparent,
                    backgroundImage: AssetImage('assets/images/momo.png'),
                  ),
                  accountName: Text(
                    provider.userName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  accountEmail: Text(provider.email),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF1A237E),
                        Color(0xFF0D47A1),
                        Color(0xFF1565C0),
                      ],
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.group_add_outlined),
                  title: const Text("Join Team Session"),
                  onTap: () {
                    _showSessionDialog(provider);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text("App Theme"),
                  trailing: const ThemeToggleButton(),
                ),
                ListTile(
                  leading: const Icon(Icons.account_circle_outlined),
                  title: const Text("Edit Profile Avatar"),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ChangeLogoScreen(),
                      ),
                    );
                  },
                ),
                const Spacer(),
                const Divider(),
                ListTile(
                  leading: const Icon(
                    Icons.share_outlined,
                    color: Colors.blueAccent,
                  ),
                  title: const Text("Invite Friends"),
                  onTap: () {
                    const String appLink =
                        "https://github.com/abukiw86-oss/Momo/releases/latest";
                    Share.share(
                      "Hey! Download this GPS Tracker app so we can see each other on the map: $appLink",
                      subject: "Download GPS Tracker",
                    );
                  },
                ),
                const SizedBox(height: 20),
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
          ),
          body: Stack(
            children: [
              maplibre.MapLibreMap(
                key: ValueKey(themeProvider.isDarkMode),
                initialCameraPosition: maplibre.CameraPosition(
                  target: (provider.myLocation == null)
                      ? maplibre.LatLng(
                          provider.myLocation!.latitude,
                          provider.myLocation!.longitude,
                        )
                      : maplibre.LatLng(20, 20),
                  zoom: zoom,
                  tilt: _currentTilt,
                ),
                styleString: _getStyleString(themeProvider.isDarkMode),
                onMapCreated: _onMapCreated,
                onStyleLoadedCallback: _onStyleLoaded,
                myLocationEnabled: true,
                myLocationTrackingMode:
                    maplibre.MyLocationTrackingMode.tracking,
                compassEnabled: false,
                attributionButtonPosition:
                    maplibre.AttributionButtonPosition.bottomRight,
                logoEnabled: false,
                myLocationRenderMode: maplibre.MyLocationRenderMode.gps,
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
                quarterTurns: 3,
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
                    min: 0.0,
                    max: 90.0,
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
      return ShimmerEffect(width: double.infinity, height: 16.0);
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
          leading: IconButton(
            color: isTrackingOthers ? Colors.green : Colors.blueAccent,
            icon: Icon(
              isTrackingOthers ? Icons.navigation : Icons.person_pin_circle,
            ),
            onPressed: isTrackingOthers ? () => _trackTeam(provider) : null,
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
            icon: const Icon(Icons.tune_outlined, color: Colors.blueAccent),
            tooltip: "Open Action Panel",
            onPressed: () => _buildBottomActionCenter(provider),
          ),
        ),
      ),
    );
  }

  void _buildBottomActionCenter(TrackingProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          controller: _bottomSheetController,
          initialChildSize: 0.8,
          minChildSize: 0.8,
          maxChildSize: 0.95,
          snap: true,
          builder: (context, scrollController) {
            return DefaultTabController(
              length: 2,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 15,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),

                    const TabBar(
                      labelColor: Colors.blueAccent,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: Colors.blueAccent,
                      tabs: [
                        Tab(
                          icon: Icon(Icons.people_outline),
                          text: "Team Session",
                        ),
                        Tab(
                          icon: Icon(Icons.search_outlined),
                          text: "Search Places",
                        ),
                      ],
                    ),

                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildTeamTab(provider, scrollController),
                          _buildSearchTab(scrollController),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTeamTab(
    TrackingProvider provider,
    ScrollController scrollController,
  ) {
    if (provider.teamLocations.isEmpty) {
      return const Center(
        child: Text("No active team tracking session discovered"),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      itemCount: provider.teamLocations.length,
      itemBuilder: (context, index) {
        String userId = provider.teamLocations.keys.elementAt(index);
        Map<String, dynamic> userData = provider.teamLocations[userId]!;

        String timeString = DateFormatter().formatLastSeen(
          userData['last_seen'],
        );

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            vertical: 4,
            horizontal: 8,
          ),
          leading: const CircleAvatar(
            backgroundColor: Colors.blue,
            child: Icon(Icons.person, color: Colors.white),
          ),
          title: Text(
            userData['name'] ?? 'Unknown Member',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            "${userData['email'] ?? 'No Email'}\nSeen at: $timeString",
            style: const TextStyle(fontSize: 12),
          ),
          trailing: Icon(
            Icons.my_location,
            color: userId == provider.targetUser ? Colors.green : Colors.grey,
          ),
          onTap: () {
            provider.selectTargetUser(userId);
            if (_mapController != null) {
              _mapController!.animateCamera(
                maplibre.CameraUpdate.newLatLng(
                  maplibre.LatLng(userData['lat'], userData['lng']),
                ),
              );
            }
            Navigator.pop(context);
          },
        );
      },
    );
  }

  Widget _buildSearchTab(ScrollController scrollController) {
    TextEditingController searchCtrl = TextEditingController();
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: searchCtrl,
          decoration: InputDecoration(
            hintText: "Search destinations, cities, streets...",
            prefixIcon: const Icon(Icons.search, color: Colors.blueAccent),
            filled: true,
            fillColor: Colors.grey[100],
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: (query) {
            ShowSnackbar().show(
              message: "Searching for '$query' coming in next update!",
            );
            Navigator.pop(context);
          },
        ),
        const SizedBox(height: 20),

        ListTile(
          leading: const Icon(Icons.location_on_outlined, color: Colors.grey),
          title: const Text("Adama Science and Technology University"),
          subtitle: const Text("Adama, Ethiopia"),
          onTap: () {
            ShowSnackbar().show(
              message: "Selected location waypoint routing pass.",
            );
          },
        ),
      ],
    );
  }
}
