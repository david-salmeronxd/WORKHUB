import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MiniMapWidget extends StatelessWidget {
  const MiniMapWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // Coordenadas centraditas en Lourdes Colón
    final LatLng centerLocation = const LatLng(13.7215, -89.3620); 

    final List<Map<String, dynamic>> businesses = [
      {'name': 'Taller Electrónico López', 'point': const LatLng(13.7215, -89.3620)},
      {'name': 'Panadería Don Juan', 'point': const LatLng(13.7230, -89.3600)},
      {'name': 'Pupusería La Esquina', 'point': const LatLng(13.7190, -89.3640)},
    ];

    return Container(
      height: 350, // 👈 Aumentamos la altura para que se aprecie mucho mejor
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
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('📍 ${business['name']}'),
                              duration: const Duration(seconds: 2),
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
                      'Explora en tu zona',
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