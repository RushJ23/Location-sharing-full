import 'dart:convert';
import 'package:http/http.dart' as http;

class PlaceSuggestion {
  const PlaceSuggestion({required this.placeId, required this.description});
  final String placeId;
  final String description;
}

class PlaceDetails {
  const PlaceDetails({required this.lat, required this.lng, required this.name});
  final double lat;
  final double lng;
  final String name;
}

class PlacesService {
  PlacesService(this._apiKey);

  final String _apiKey;
  static const _baseUrl = 'https://maps.googleapis.com/maps/api';

  Future<List<PlaceSuggestion>> autocomplete(String input) async {
    if (input.trim().isEmpty) return [];
    final uri = Uri.parse('$_baseUrl/place/autocomplete/json').replace(queryParameters: {
      'input': input,
      'key': _apiKey,
    });
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final predictions = data['predictions'] as List<dynamic>? ?? [];
      return predictions.map((p) {
        return PlaceSuggestion(
          placeId: p['place_id'] as String,
          description: p['description'] as String,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<PlaceDetails?> getDetails(String placeId) async {
    final uri = Uri.parse('$_baseUrl/place/details/json').replace(queryParameters: {
      'place_id': placeId,
      'fields': 'name,geometry',
      'key': _apiKey,
    });
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final result = data['result'] as Map<String, dynamic>?;
      if (result == null) return null;
      final location = (result['geometry'] as Map<String, dynamic>)['location'] as Map<String, dynamic>;
      return PlaceDetails(
        lat: (location['lat'] as num).toDouble(),
        lng: (location['lng'] as num).toDouble(),
        name: result['name'] as String? ?? '',
      );
    } catch (_) {
      return null;
    }
  }
}
