import 'config/imports.dart';
import 'package:latlong2/latlong.dart';

class FreeTrackerMap extends StatefulWidget {
  const FreeTrackerMap({super.key});

  @override
  State<FreeTrackerMap> createState() => _FreeTrackerMapState();
}

class _FreeTrackerMapState extends State<FreeTrackerMap> {
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<TrackingProvider>(context, listen: false);
      provider.initializeTracking(
        onLocationLoaded: (location) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _mapController.move(location, 15);
            }
          });
        },
        onNameRequired: () {
          _showNameDialog();
        },
      );
    });
  }

  void _showNameDialog() {
    TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Enter Your Name"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "e.g. Abuki"),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                final provider = Provider.of<TrackingProvider>(
                  context,
                  listen: false,
                );
                await provider.setSavedUserName(controller.text);
                if (context.mounted) {
                  Navigator.pop(context);
                }
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _handleSearchSubmit(String val) async {
    if (val.isEmpty) return;
    final provider = Provider.of<TrackingProvider>(context, listen: false);
    final target = await provider.searchPlace(val);
    if (!mounted) return;
    if (target != null) {
      _mapController.move(target, 16);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Place '$val' not found in database"),
          backgroundColor: Colors.orange,
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
        return Scaffold(
          drawer: Drawer(
            width: MediaQuery.of(context).size.width * 0.85,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
            child: Column(
              children: [
                Center(
                  child: UserAccountsDrawerHeader(
                    currentAccountPicture: CircleAvatar(
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
                            String name = provider.teamLocations.keys.elementAt(
                              index,
                            );
                            return ListTile(
                              title: Text(name),
                              leading: CircleAvatar(
                                backgroundColor: Colors.transparent,
                                backgroundImage: AssetImage(
                                  'assets/images/momo.png',
                                ),
                              ),
                              onTap: () {
                                provider.selectTargetUser(name);
                                final targetLoc = provider.teamLocations[name];
                                if (targetLoc != null) {
                                  _mapController.move(targetLoc, 15);
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
                        "https://github.com/abukiw86-oss/GPS-Team-Tracker/releases";
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
            title: provider.isSearching
                ? TextField(
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: "Search places...",
                      hintStyle: TextStyle(color: Colors.white),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (val) => _handleSearchSubmit(val),
                  )
                : Text(
                    "Hi, ${provider.userName} ${provider.currentSessionId != null ? '(${provider.currentSessionId})' : ''}",
                  ),
            actions: [
              IconButton(
                icon: Icon(provider.isSearching ? Icons.close : Icons.search),
                onPressed: () {
                  provider.toggleSearching();
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
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter:
                      provider.myLocation ?? const LatLng(9.03, 38.74),
                  initialZoom: 15,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.momo.gps',
                  ),
                  if (provider.routePoints.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: provider.routePoints,
                          color: Colors.red,
                          strokeWidth: 4,
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      if (provider.myLocation != null)
                        Marker(
                          point: provider.myLocation!,
                          width: 80,
                          height: 80,
                          child: _markerWidget("Me", Colors.blue),
                        ),
                      ...provider.teamLocations.entries.map((entry) {
                        bool isTracked = entry.key == provider.targetUser;
                        return Marker(
                          point: entry.value,
                          width: 80,
                          height: 80,
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isTracked
                                      ? Colors.green
                                      : Colors.black54,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  entry.key,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.location_on,
                                size: isTracked ? 45 : 35,
                                color: isTracked ? Colors.green : Colors.red,
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ],
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
                    if (provider.myLocation != null) {
                      _mapController.move(provider.myLocation!, 17);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Locating you...")),
                      );
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

  Widget _markerWidget(String label, Color color) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          child: Text(label, style: const TextStyle(fontSize: 18)),
        ),
        Icon(Icons.location_on, color: color, size: 50),
      ],
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
                            "Track me on GPS Tracker! Group Code: ${provider.currentSessionId}",
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
                  Share.share("Join my location group! Code: $newId");
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
                  hintStyle: const TextStyle(
                    letterSpacing: 0,
                    fontWeight: FontWeight.normal,
                  ),
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

    if (provider.myLocation == null) {
      return const SizedBox();
    }
    final displayLocation = isTrackingOthers
        ? provider.teamLocations[provider.targetUser]!
        : provider.myLocation!;
    final displayName = isTrackingOthers
        ? provider.targetUser
        : "My Location (Solo)";

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
            displayName!,
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
          trailing: Builder(
            builder: (context) {
              return IconButton(
                icon: const Icon(
                  Icons.people_alt_rounded,
                  color: Colors.blueAccent,
                ),
                onPressed: () {
                  Scaffold.of(context).openDrawer();
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
