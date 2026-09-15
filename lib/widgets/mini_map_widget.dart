import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../screens/business_detail_screen.dart';

class MiniMapWidget extends StatelessWidget {
  const MiniMapWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // Coordenadas centraditas en Lourdes Colón
    final LatLng centerLocation = const LatLng(13.7215, -89.3620);

    // Datos estructurados de los negocios en el mapa
    final List<Map<String, dynamic>> businesses = [
      {
        'id': '1',
        'name': 'Taller Electrónico López',
        'category': 'Reparaciones',
        'description':
            'Servicio técnico especializado en celulares, pantallas, TVs y electrodomésticos.',
        'rating': '4.8',
        'address': 'Polígono W, Lourdes Colón',
        'phone': '+503 7123-4567',
        'point': const LatLng(13.7215, -89.3620),
      },
      {
        'id': '2',
        'name': 'Panadería Don Juan',
        'category': 'Comida',
        'description': 'Pan dulce fresco todos los días, pasteles fríos y café recién molido.',
        'rating': '4.9',
        'address': 'Colonia Martell, Lourdes Colón',
        'phone': '+503 7890-1234',
        'point': const LatLng(13.7230, -89.3600),
      },
      {
        'id': '3',
        'name': 'Pupusería La Esquina',
        'category': 'Comida',
        'description': 'Pupusas tradicionales de maíz y arroz con el mejor curtido de la zona.',
        'rating': '4.7',
        'address': 'Urbanización Villa Lourdes, Lourdes Colón',
        'phone': '+503 7555-8888',
        'point': const LatLng(13.7190, -89.3640),
      },
    ];

    return Container(
      height: 350,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: centerLocation,
                initialZoom: 15.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.mi_comunidad',
                ),
                MarkerLayer(
                  markers: businesses.map((business) {
                    return Marker(
                      point: business['point'],
                      width: 40,
                      height: 40,
                      child: GestureDetector(
                        onTap: () {
                          // 🚀 Abrir detalle del negocio al tocar el pin
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => BusinessDetailScreen(
                                business: business,
                              ),
                            ),
                          );
                        },
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 38,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                ),
                child: const Row(
                  children: [
                    Icon(Icons.map, size: 16, color: Colors.blue),
                    SizedBox(width: 6),
                    Text(
                      'Toca un pin para ver detalles',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}