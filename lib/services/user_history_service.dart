import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/route_model.dart';
import '../models/product_model.dart';

class UserHistoryService {
  static final UserHistoryService _instance = UserHistoryService._internal();
  factory UserHistoryService() => _instance;
  UserHistoryService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final Map<String, DateTime> _recentlyLogged = {};

  int _extractHour(String timeStr) {
    final regex = RegExp(r'(\d{1,2}):(\d{2})\s*(AM|PM)', caseSensitive: false);
    final match = regex.firstMatch(timeStr.trim());
    if (match == null) return 0;
    int hour = int.tryParse(match.group(1)!) ?? 12;
    final ampm = match.group(3)!.toUpperCase();
    if (ampm == 'PM' && hour != 12) {
      hour += 12;
    } else if (ampm == 'AM' && hour == 12) {
      hour = 0;
    }
    return hour;
  }

  Future<void> logRouteView(String uid, RouteModel route) async {
    if (uid.isEmpty) return;
    final key = 'route_${route.id}';
    final now = DateTime.now();
    if (_recentlyLogged.containsKey(key) &&
        now.difference(_recentlyLogged[key]!).inSeconds < 60) {
      return;
    }
    _recentlyLogged[key] = now;

    try {
      final col = _db
          .collection('user_history')
          .doc(uid)
          .collection('route_views');
      final recent =
          await col.orderBy('timestamp', descending: false).limit(20).get();
      if (recent.docs.length >= 20) {
        final oldest =
            await col.orderBy('timestamp', descending: false).limit(1).get();
        if (oldest.docs.isNotEmpty) {
          await oldest.docs.first.reference.delete();
        }
      }

      final hour = _extractHour(route.time);
      await col.add({
        'routeId': route.id,
        'origin': route.origin,
        'destination': route.destination,
        'hour': hour,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('UserHistoryService logRouteView error: $e');
      }
    }
  }

  Future<void> logProductView(String uid, ProductModel product) async {
    if (uid.isEmpty) return;
    final key = 'product_${product.id}';
    final now = DateTime.now();
    if (_recentlyLogged.containsKey(key) &&
        now.difference(_recentlyLogged[key]!).inSeconds < 60) {
      return;
    }
    _recentlyLogged[key] = now;

    try {
      final col = _db
          .collection('user_history')
          .doc(uid)
          .collection('product_views');
      final recent =
          await col.orderBy('timestamp', descending: false).limit(20).get();
      if (recent.docs.length >= 20) {
        final oldest =
            await col.orderBy('timestamp', descending: false).limit(1).get();
        if (oldest.docs.isNotEmpty) {
          await oldest.docs.first.reference.delete();
        }
      }

      await col.add({
        'productId': product.id,
        'category': product.category,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('UserHistoryService logProductView error: $e');
      }
    }
  }

  Future<List<Map<String, dynamic>>> getRecentRouteViews(String uid,
      {int limit = 10}) async {
    if (uid.isEmpty) return [];
    try {
      final snap = await _db
          .collection('user_history')
          .doc(uid)
          .collection('route_views')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();
      return snap.docs.map((d) => Map<String, dynamic>.from(d.data())).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('getRecentRouteViews error: $e');
      }
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getRecentProductViews(String uid,
      {int limit = 10}) async {
    if (uid.isEmpty) return [];
    try {
      final snap = await _db
          .collection('user_history')
          .doc(uid)
          .collection('product_views')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();
      return snap.docs.map((d) => Map<String, dynamic>.from(d.data())).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('getRecentProductViews error: $e');
      }
      return [];
    }
  }
}
