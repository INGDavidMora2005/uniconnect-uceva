import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/route_model.dart';
import '../models/product_model.dart';
import 'key_service.dart';
import 'user_history_service.dart';

class AiRecommendationService {
  static final AiRecommendationService _instance =
      AiRecommendationService._internal();
  factory AiRecommendationService() => _instance;
  AiRecommendationService._internal();

  static String get _apiKey => KeyService.geminiApiKey;

  List<RouteModel>? _cachedRoutes;
  List<ProductModel>? _cachedProducts;

  Future<List<RouteModel>> getRouteRecommendations({
    required String uid,
    required List<RouteModel> availableRoutes,
  }) async {
    if (_cachedRoutes != null) return _cachedRoutes!;

    if (_apiKey.isEmpty) {
      if (kDebugMode) {
        assert(false, 'Gemini API Key no configurada en AiRecommendationService');
      }
      return _getFallbackRoutes(availableRoutes);
    }

    try {
      final views = await UserHistoryService()
          .getRecentRouteViews(uid, limit: 10);
      if (views.isEmpty) {
        final fallback = _getFallbackRoutes(availableRoutes);
        _cachedRoutes = fallback;
        return fallback;
      }

      final historyText = _formatRouteHistory(views);
      final limited = availableRoutes.take(15).toList();
      final routesJson = jsonEncode(limited
          .map((r) => {
                'id': r.id,
                'origin': r.origin,
                'destination': r.destination,
                'time': r.time,
                'price': r.price,
                'seats': r.availableSeats,
              })
          .toList());

      final prompt = '''
Eres el motor de recomendación de rutas compartidas de UniConnect, una app de carpooling universitario de la UCEVA (Colombia).
HISTORIAL DEL USUARIO (últimas vistas de rutas):
$historyText
RUTAS DISPONIBLES ACTUALMENTE:
$routesJson
INSTRUCCIONES:

Analiza los patrones de origen, destino y hora del historial.
Selecciona hasta 3 IDs de rutas disponibles que sean más relevantes para este usuario.
Si el historial está vacío, selecciona las 3 rutas con más cupos disponibles.
Responde ÚNICAMENTE con un array JSON de strings con los IDs seleccionados. Sin texto adicional, sin markdown, sin explicaciones.
Ejemplo de respuesta válida: ["id1","id2","id3"]
Si no hay rutas relevantes, responde: []
''';

      final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent?key=$_apiKey');

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': prompt}
                  ]
                }
              ]
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        if (kDebugMode) debugPrint('Gemini routes status: ${response.statusCode}');
        return _getFallbackRoutes(availableRoutes);
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] as String? ?? '';

      final ids = _extractJsonArray(text);
      if (ids == null || ids.isEmpty) {
        return _getFallbackRoutes(availableRoutes);
      }

      final routeMap = {for (final r in availableRoutes) r.id: r};
      final result = <RouteModel>[];
      for (final id in ids) {
        final m = routeMap[id];
        if (m != null) {
          result.add(m);
          if (result.length >= 3) break;
        }
      }

      final finalResult = result.isNotEmpty ? result : _getFallbackRoutes(availableRoutes);
      _cachedRoutes = finalResult;
      return finalResult;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AiRecommendationService getRouteRecommendations error: $e');
      }
      final fallback = _getFallbackRoutes(availableRoutes);
      _cachedRoutes = fallback;
      return fallback;
    }
  }

  Future<List<ProductModel>> getProductRecommendations({
    required String uid,
    required List<ProductModel> availableProducts,
  }) async {
    if (_cachedProducts != null) return _cachedProducts!;

    if (_apiKey.isEmpty) {
      if (kDebugMode) {
        assert(false, 'Gemini API Key no configurada en AiRecommendationService');
      }
      return _getFallbackProducts(availableProducts);
    }

    try {
      final views = await UserHistoryService()
          .getRecentProductViews(uid, limit: 10);
      if (views.isEmpty) {
        final fallback = _getFallbackProducts(availableProducts);
        _cachedProducts = fallback;
        return fallback;
      }

      final historyText = _formatProductHistory(views);
      final limited = availableProducts.take(15).toList();
      final productsJson = jsonEncode(limited
          .map((p) => {
                'id': p.id,
                'name': p.name,
                'category': p.category,
                'price': p.price,
              })
          .toList());

      final prompt = '''
Eres el motor de recomendación del Bazar UCEVA, un marketplace universitario.
HISTORIAL DEL USUARIO (últimas categorías vistas):
$historyText
PRODUCTOS DISPONIBLES ACTUALMENTE:
$productsJson
INSTRUCCIONES:

Analiza las categorías del historial del usuario.
Selecciona hasta 3 IDs de productos disponibles que mejor coincidan con sus intereses.
Si el historial está vacío, selecciona los 3 productos con menor precio.
Responde ÚNICAMENTE con un array JSON de strings con los IDs. Sin texto adicional, sin markdown, sin explicaciones.
Ejemplo de respuesta válida: ["id1","id2","id3"]
Si no hay productos relevantes, responde: []
''';

      final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent?key=$_apiKey');

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': prompt}
                  ]
                }
              ]
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        if (kDebugMode) debugPrint('Gemini products status: ${response.statusCode}');
        return _getFallbackProducts(availableProducts);
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] as String? ?? '';

      final ids = _extractJsonArray(text);
      if (ids == null || ids.isEmpty) {
        return _getFallbackProducts(availableProducts);
      }

      final productMap = {for (final p in availableProducts) p.id: p};
      final result = <ProductModel>[];
      for (final id in ids) {
        final m = productMap[id];
        if (m != null) {
          result.add(m);
          if (result.length >= 3) break;
        }
      }

      final finalResult = result.isNotEmpty ? result : _getFallbackProducts(availableProducts);
      _cachedProducts = finalResult;
      return finalResult;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AiRecommendationService getProductRecommendations error: $e');
      }
      final fallback = _getFallbackProducts(availableProducts);
      _cachedProducts = fallback;
      return fallback;
    }
  }

  List<String>? _extractJsonArray(String text) {
    final regex = RegExp(r'\[[\s\S]*?\]');
    final match = regex.firstMatch(text);
    if (match == null) return null;
    final jsonStr = match.group(0)!;
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is List) {
        return decoded
            .map((e) => e.toString())
            .where((s) => s.isNotEmpty)
            .toList();
      }
    } catch (_) {}
    return null;
  }

  List<RouteModel> _getFallbackRoutes(List<RouteModel> all) {
    return all.take(3).toList();
  }

  List<ProductModel> _getFallbackProducts(List<ProductModel> all) {
    final sorted = List<ProductModel>.from(all);
    sorted.sort((a, b) => a.price.compareTo(b.price));
    return sorted.take(3).toList();
  }

  String _formatRouteHistory(List<Map<String, dynamic>> views) {
    if (views.isEmpty) return 'Sin historial de rutas vistas.';
    final freq = <String, int>{};
    for (final v in views) {
      final o = (v['origin'] ?? '').toString();
      final d = (v['destination'] ?? '').toString();
      final h = v['hour'] ?? 0;
      final key = '$o|$d|$h';
      freq[key] = (freq[key] ?? 0) + 1;
    }
    return freq.entries.map((e) {
      final p = e.key.split('|');
      final c = e.value;
      final vez = c == 1 ? 'vez' : 'veces';
      return 'De: ${p[0]} → A: ${p[1]} | Hora: ${p[2]}:00 (aparece $c $vez)';
    }).join('\n');
  }

  String _formatProductHistory(List<Map<String, dynamic>> views) {
    if (views.isEmpty) return 'Sin historial de productos vistas.';
    final freq = <String, int>{};
    for (final v in views) {
      final cat = (v['category'] ?? '').toString();
      if (cat.isEmpty) continue;
      freq[cat] = (freq[cat] ?? 0) + 1;
    }
    return freq.entries.map((e) {
      final c = e.value;
      final vez = c == 1 ? 'vez' : 'veces';
      return 'Categoría: ${e.key} (aparece $c $vez)';
    }).join('\n');
  }
}
