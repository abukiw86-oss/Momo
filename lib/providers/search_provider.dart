import 'dart:async';
import 'package:http/http.dart' as http;
import '../config/imports.dart';

class SearchProvider extends ChangeNotifier {
  List<dynamic> _searchResults = [];
  Timer? _debounce;

  List<dynamic> get searchResults => _searchResults;

  void onQueryChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    if (query.trim().isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final String url =
          "https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=geojson&limit=5";
      try {
        final response = await http.get(
          Uri.parse(url),
          headers: {"User-Agent": "Momo/1.0 (momo.gps.com)"},
        );
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          _searchResults = data['features'] ?? [];
          notifyListeners();
        }
      } catch (e) {
        debugPrint("Nominatim search error: $e");
      }
    });
  }

  void clearSearch() {
    _debounce?.cancel();
    _searchResults = [];
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
