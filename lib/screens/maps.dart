import '../config/imports.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

class FreeTrackerMap extends StatefulWidget {
  const FreeTrackerMap({super.key});

  @override
  State<FreeTrackerMap> createState() => _FreeTrackerMapState();
}

class _FreeTrackerMapState extends State<FreeTrackerMap> {
  MapLibreMapController? _mapController;
  bool _isStyleLoaded = false;
  static const double zoom = 17.8;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<TrackingProvider>(context, listen: false);
      provider.initialData(onDataRequired: ShowRegisterDialogue().showDialog);
    });
  }

  void _onMapCreated(MapLibreMapController controller) {
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
      const FillExtrusionLayerProperties(
        fillExtrusionColor: "#ffffff",
        fillExtrusionHeight: ["get", "render_height"],
        fillExtrusionBase: ["get", "render_min_height"],
        fillExtrusionOpacity: 1,
      ),
    );
  }

  void _updateMapElements() {
    if (_mapController == null || !_isStyleLoaded) return;
    final provider = Provider.of<TrackingProvider>(context, listen: false);

    _mapController!.clearLines();
    _mapController!.clearSymbols();

    if (provider.routePoints.isNotEmpty) {
      List<LatLng> mapLibrePoints = provider.routePoints
          .map((p) => LatLng(p.latitude, p.longitude))
          .toList();

      _mapController!.addLine(
        LineOptions(
          geometry: mapLibrePoints,
          lineColor: "#0000FF",
          lineWidth: 4.0,
          lineOpacity: 0.8,
        ),
      );
    }

    provider.teamLocations.forEach((userId, userData) {
      bool isTracked = userId == provider.targetUser;

      _mapController!.addSymbol(
        SymbolOptions(
          geometry: LatLng(userData['lat'], userData['lng']),
          iconImage: isTracked ? "custom-marker" : "friend-marker",
          textField: userData['name'] ?? 'Unknown',
          textColor: isTracked ? "#000000" : "#FFFFFF",
          textOffset: const Offset(0, 2.5),
          textAnchor: "top",
          textSize: 14.0,
          iconColor: isTracked ? "#000000" : "#00000ff",
          iconSize: 2,
        ),
      );
    });
  }

  void _joinSession(String sessionId, bool isCreatingSession) async {
    final provider = Provider.of<TrackingProvider>(context, listen: false);
    bool success = await provider.joinOrCreateSession(
      sessionId,
      isCreatingSession: isCreatingSession,
    );
    if (!mounted) return;
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Invalid Code!"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TrackingProvider>(
      builder: (context, provider, child) {
        if (_mapController != null && _isStyleLoaded) {
          _updateMapElements();

          if (provider.myLocation != null) {
            _mapController!.animateCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(
                  target: LatLng(
                    provider.myLocation!.latitude,
                    provider.myLocation!.longitude,
                  ),
                  zoom: zoom,
                  tilt: 95.0,
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
                    currentAccountPicture: CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.transparent,
                      backgroundImage: const AssetImage(
                        'assets/images/momo.png',
                      ),
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
                                    CameraUpdate.newLatLngZoom(
                                      LatLng(userData['lat'], userData['lng']),
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
              MapLibreMap(
                initialCameraPosition: CameraPosition(
                  target: provider.myLocation != null
                      ? LatLng(
                          provider.myLocation!.latitude,
                          provider.myLocation!.longitude,
                        )
                      : const LatLng(9.03, 38.74),
                  zoom: zoom,
                ),
                styleString: "https://tiles.openfreemap.org/styles/liberty",
                onMapCreated: _onMapCreated,
                onStyleLoadedCallback: _onStyleLoaded,
                myLocationEnabled: true,
                myLocationTrackingMode: MyLocationTrackingMode.trackingGps,
              ),
              Positioned(
                bottom: 20,
                left: 10,
                right: 10,
                child: _buildDistanceCard(provider),
              ),
              Positioned(
                right: 20,
                bottom: 110,
                child: FloatingActionButton(
                  backgroundColor: Colors.blueAccent,
                  child: const Icon(Icons.my_location, color: Colors.white),
                  onPressed: () {
                    if (provider.myLocation != null && _mapController != null) {
                      _mapController!.animateCamera(
                        CameraUpdate.newCameraPosition(
                          CameraPosition(
                            target: LatLng(
                              provider.myLocation!.latitude,
                              provider.myLocation!.longitude,
                            ),
                            zoom: zoom,
                            tilt: 60.0,
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

  Widget _buildDistanceCard(TrackingProvider provider) {
    bool isTrackingOthers =
        provider.targetUser != null &&
        provider.teamLocations.containsKey(provider.targetUser);
    if (provider.myLocation == null || provider.isLoadingTeam)
      return _buildShimmerCard();

    final targetUserData = isTrackingOthers
        ? provider.teamLocations[provider.targetUser]
        : null;
    final displayLocation = isTrackingOthers && targetUserData != null
        ? LatLng(targetUserData['lat'], targetUserData['lng'])
        : LatLng(provider.myLocation!.latitude, provider.myLocation!.longitude);

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
