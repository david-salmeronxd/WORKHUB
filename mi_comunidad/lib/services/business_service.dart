import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'api_client.dart';

class BusinessService {
  static final ValueNotifier<List<Map<String, dynamic>>> businessesNotifier = ValueNotifier([]);

  static Map<String, dynamic> _fromApi(Map<String, dynamic> item) => {
        ...item,
        'id': item['id'].toString(),
        'location': LatLng((item['latitude'] as num).toDouble(), (item['longitude'] as num).toDouble()),
        'rating': (item['rating'] as num?)?.toDouble() ?? 0.0,
        'ratingsCount': (item['ratings_count'] as num?)?.toInt() ?? 0,
        'reviews': (item['reviews'] as List?)?.cast<Map<String, dynamic>>() ?? <Map<String, dynamic>>[],
        'isPromoted': false,
        'isFavorite': false,
      };

  static Future<bool> loadBusinesses() async {
    try {
      final response = await ApiClient.request('GET', '/businesses');
      businessesNotifier.value = (response['data'] as List).cast<Map<String, dynamic>>().map(_fromApi).toList();
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> loadFavorites() async {
    try {
      final response = await ApiClient.request('GET', '/businesses/favorites');
      final favoriteIds = (response['data'] as List).map((id) => id.toString()).toSet();
      businessesNotifier.value = businessesNotifier.value
          .map((business) => {...business, 'isFavorite': favoriteIds.contains(business['id'].toString())})
          .toList();
    } catch (_) {}
  }

  // Alternar estado de favorito (Heart Toggle)
  static Future<void> toggleFavorite(String id) async {
    final current = businessesNotifier.value.firstWhere((item) => item['id'].toString() == id, orElse: () => {});
    if (current.isEmpty) return;
    final isFavorite = current['isFavorite'] == true;
    try {
      await ApiClient.request(isFavorite ? 'DELETE' : 'POST', '/businesses/$id/favorite');
      businessesNotifier.value = businessesNotifier.value
          .map((item) => item['id'].toString() == id ? {...item, 'isFavorite': !isFavorite} : item)
          .toList();
    } catch (_) {}
  }

  static Future<bool> addReview(String id, int rating, String comment) async {
    try {
      await ApiClient.request('POST', '/businesses/$id/reviews', body: {'rating': rating, 'comment': comment});
      await loadBusinesses();
      await loadFavorites();
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>?> addBusiness(Map<String, dynamic> business) async {
    try {
      final point = (business['point'] ?? business['location']) as LatLng?;
      final response = await ApiClient.request('POST', '/businesses', body: {
        'name': business['name'], 'category': business['category'], 'description': business['description'],
        'address': business['address'], 'phone': business['phone'], 'latitude': point?.latitude, 'longitude': point?.longitude,
      });
      final saved = _fromApi(response['data'] as Map<String, dynamic>);
      businessesNotifier.value = [saved, ...businessesNotifier.value];
      return saved;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> deleteBusiness(String id) async {
    try {
      await ApiClient.request('DELETE', '/businesses/$id');
      businessesNotifier.value = businessesNotifier.value.where((item) => item['id'] != id).toList();
      return true;
    } catch (_) {
      return false;
    }
  }
}