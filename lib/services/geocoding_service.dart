import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class PlaceSuggestion {
  final String displayName;
  final double lat;
  final double lng;

  const PlaceSuggestion({
    required this.displayName,
    required this.lat,
    required this.lng,
  });
}

class GeocodingService {
  static final GeocodingService _instance = GeocodingService._internal();
  factory GeocodingService() => _instance;
  GeocodingService._internal();

  static const _headers = {
    'User-Agent': 'UniConnectUCEVA/1.0',
    'Accept-Language': 'es',
  };

  // Bounding box de Colombia
  static bool isWithinColombia(double lat, double lng) {
    return lat >= -4.2 && lat <= 13.0 && lng >= -79.0 && lng <= -66.8;
  }

  // Sugerencias de autocompletado (mínimo 3 caracteres para llamar)
  Future<List<PlaceSuggestion>> getSuggestions(String query) async {
    try {
      final uri = Uri(
        scheme: 'https',
        host: 'nominatim.openstreetmap.org',
        path: '/search',
        queryParameters: {
          'q': query,
          'format': 'json',
          'limit': '5',
          'countrycodes': 'co',
        },
      );
      final response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) {
          return PlaceSuggestion(
            displayName: item['display_name'] ?? '',
            lat: double.tryParse(item['lat'] ?? '') ?? 0.0,
            lng: double.tryParse(item['lon'] ?? '') ?? 0.0,
          );
        }).toList();
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  // Geocoding directo (fallback cuando no seleccionó sugerencia)
  Future<LatLng?> geocodeAddress(String address) async {
    try {
      final uri = Uri(
        scheme: 'https',
        host: 'nominatim.openstreetmap.org',
        path: '/search',
        queryParameters: {
          'q': address,
          'format': 'json',
          'limit': '1',
          'countrycodes': 'co',
        },
      );
      final response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
          final item = data.first;
          final lat = double.tryParse(item['lat'] ?? '');
          final lng = double.tryParse(item['lon'] ?? '');
          if (lat != null && lng != null) {
            return LatLng(lat, lng);
          }
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}