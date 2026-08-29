import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class BusinessService {
  static final ValueNotifier<List<Map<String, dynamic>>> businessesNotifier =
      ValueNotifier<List<Map<String, dynamic>>>([
    {
      'id': '1',
      'name': 'Taller Electrónico López',
      'category': 'Reparaciones',
      'description':
          'Reparación de celulares, TVs, microondas y electrodomésticos en general.',
      'rating': '4.8',
      'address': 'Polígono W, Lourdes Colón',
      'phone': '+503 7123-4567',
      'distance': 'A 2 km de ti',
      'isFavorite': false,
      'point': const LatLng(13.7215, -89.3620),
    },
    {
      'id': '2',
      'name': 'Panadería Don Juan',
      'category': 'Comida',
      'description': 'Pan fresco, pasteles por encargo y café molido al instante.',
      'rating': '4.9',
      'address': 'Colonia Martell, Lourdes Colón',
      'phone': '+503 7890-1234',
      'distance': 'A 500 m de ti',
      'isFavorite': false,
      'point': const LatLng(13.7230, -89.3600),
    },
  ]);

  // Alternar estado de favorito (Heart Toggle)
  static void toggleFavorite(String id) {
    final currentList = List<Map<String, dynamic>>.from(businessesNotifier.value);
    final index = currentList.indexWhere((b) => b['id'] == id);
    if (index != -1) {
      currentList[index]['isFavorite'] = !(currentList[index]['isFavorite'] ?? false);
      businessesNotifier.value = currentList; // Actualiza en tiempo real
    }
  }

  static void addBusiness(Map<String, dynamic> newBusiness) {
    final currentList = List<Map<String, dynamic>>.from(businessesNotifier.value);
    currentList.insert(0, newBusiness);
    businessesNotifier.value = currentList;
  }

  static void deleteBusiness(String id) {
    final currentList = List<Map<String, dynamic>>.from(businessesNotifier.value);
    currentList.removeWhere((business) => business['id'] == id);
    businessesNotifier.value = currentList;
  }
}