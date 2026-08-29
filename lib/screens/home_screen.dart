import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  final bool isAdmin; // Se recibe el parámetro de autenticación desde LoginScreen

  const HomeScreen({
    super.key,
    this.isAdmin = false, // Parámetro opcional que por defecto es false
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MapController _mapController = MapController();

  LatLng _currentLocation = const LatLng(13.6929, -89.2182);
  bool _isLoadingLocation = false;
  bool _isSelectingLocationOnMap = false;
  LatLng? _selectedLocationForNewStore;

  String selectedCategory = 'Todos';
  Map<String, dynamic>? selectedBusiness;

  List<Map<String, dynamic>> favoriteBusinesses = [];
  List<Map<String, dynamic>> businesses = [
    {
      'id': '1',
      'name': 'Café El Chaparrastique',
      'category': 'Restaurantes',
      'rating': 0.0,
      'ratingsCount': 0,
      'reviews': <Map<String, dynamic>>[],
      'location': const LatLng(13.6980, -89.2230),
      'address': 'Colonia Escalón, San Salvador',
      'description': 'Café especial y desayunos artesanales.',
      'isPromoted': true,
    },
    {
      'id': '2',
      'name': 'Farmacia La Buena Salud',
      'category': 'Farmacias',
      'rating': 0.0,
      'ratingsCount': 0,
      'reviews': <Map<String, dynamic>>[],
      'location': const LatLng(13.6890, -89.2110),
      'address': 'Centro Histórico, San Salvador',
      'description': 'Medicamentos y atención las 24 horas.',
      'isPromoted': false,
    },
  ];

  final List<String> categories = [
    'Todos',
    'Restaurantes',
    'Hoteles',
    'Farmacias',
    'Servicios',
  ];

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    setState(() => _isLoadingLocation = true);

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _isLoadingLocation = false);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _isLoadingLocation = false);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() => _isLoadingLocation = false);
      return;
    }

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentLocation = LatLng(position.latitude, position.longitude);
      _isLoadingLocation = false;
    });

    _mapController.move(_currentLocation, 15.0);
  }

  double _calculateDistance(LatLng target) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Kilometer, _currentLocation, target);
  }

  void _toggleFavorite(Map<String, dynamic> store) {
    setState(() {
      if (favoriteBusinesses.any((element) => element['id'] == store['id'])) {
        favoriteBusinesses.removeWhere((element) => element['id'] == store['id']);
      } else {
        favoriteBusinesses.add(store);
      }
    });
  }

  void _deleteBusiness(String businessId, String businessName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0D0D0D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.white24, width: 1.5),
        ),
        title: const Text(
          'ELIMINAR LOCAL',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.2),
        ),
        content: Text(
          '¿Deseas eliminar "$businessName"? Esta acción destruirá los registros del negocio.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR', style: TextStyle(color: Colors.white38, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              setState(() {
                businesses.removeWhere((b) => b['id'] == businessId);
                favoriteBusinesses.removeWhere((b) => b['id'] == businessId);
                selectedBusiness = null;
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Local "$businessName" eliminado.', style: const TextStyle(color: Colors.black)),
                  backgroundColor: Colors.white,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('ELIMINAR', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  void _logout() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  void _startMapLocationPicker() {
    setState(() {
      _isSelectingLocationOnMap = true;
      selectedBusiness = null;
    });
  }

  void _confirmSelectedLocation() {
    if (_selectedLocationForNewStore == null) return;
    setState(() => _isSelectingLocationOnMap = false);
    _showFormWithLocation(_selectedLocationForNewStore!);
  }

  void _showPaymentModal(Map<String, dynamic> newBusinessData) {
    final cardHolderController = TextEditingController();
    final cardNumberController = TextEditingController();
    final expiryController = TextEditingController();
    final cvvController = TextEditingController();
    final paymentFormKey = GlobalKey<FormState>();
    bool isProcessing = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D0D0D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        side: BorderSide(color: Colors.white24, width: 1.5),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 24,
                left: 24,
                right: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: paymentFormKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white30,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'PAGO CON TARJETA',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                          Row(
                            children: const [
                              Icon(Icons.credit_card, color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Text(
                                '\$5.00',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: cardHolderController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: _inputDecoration('Nombre en la tarjeta'),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Ingresa el titular' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: cardNumberController,
                        keyboardType: TextInputType.number,
                        maxLength: 16,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: const TextStyle(color: Colors.white, fontSize: 14, letterSpacing: 2),
                        decoration: _inputDecoration('Número de tarjeta (16 dígitos)').copyWith(counterText: ''),
                        validator: (val) => val == null || val.length < 16 ? 'Número de 16 dígitos inválido' : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: expiryController,
                              keyboardType: TextInputType.number,
                              maxLength: 5,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              decoration: _inputDecoration('MM/AA').copyWith(counterText: ''),
                              validator: (val) => val == null || !val.contains('/') || val.length < 5
                                  ? 'Formato MM/AA'
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: cvvController,
                              keyboardType: TextInputType.number,
                              maxLength: 3,
                              obscureText: true,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              decoration: _inputDecoration('CVV').copyWith(counterText: ''),
                              validator: (val) => val == null || val.length < 3 ? '3 dígitos' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: isProcessing
                              ? null
                              : () async {
                                  if (paymentFormKey.currentState!.validate()) {
                                    setModalState(() => isProcessing = true);
                                    await Future.delayed(const Duration(seconds: 2));

                                    setState(() {
                                      businesses.add(newBusinessData);
                                      selectedBusiness = newBusinessData;
                                    });

                                    if (mounted) {
                                      Navigator.pop(context);
                                      _mapController.move(newBusinessData['location'] as LatLng, 16.0);

                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '¡Pago aprobado! "${newBusinessData['name']}" ha sido publicado.',
                                            style: const TextStyle(color: Colors.black),
                                          ),
                                          backgroundColor: Colors.white,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  }
                                },
                          child: isProcessing
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5),
                                )
                              : const Text(
                                  'PROCESAR PAGO \$5.00',
                                  style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showFormWithLocation(LatLng location) {
    final nameController = TextEditingController();
    final addressController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedCategoryForm = 'Restaurantes';
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        side: BorderSide(color: Colors.white24, width: 1.5),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 24,
                left: 24,
                right: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white30,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'REGISTRAR NEGOCIO',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              '\$5.00',
                              style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: nameController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: _inputDecoration('Nombre del negocio'),
                        validator: (val) => val == null || val.isEmpty ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedCategoryForm,
                        dropdownColor: const Color(0xFF141414),
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: _inputDecoration('Categoría'),
                        items: ['Restaurantes', 'Hoteles', 'Farmacias', 'Servicios']
                            .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setModalState(() => selectedCategoryForm = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: addressController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: _inputDecoration('Dirección o Referencia'),
                        validator: (val) => val == null || val.isEmpty ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141414),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.my_location, color: Colors.white, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Lat: ${location.latitude.toStringAsFixed(5)} | Lng: ${location.longitude.toStringAsFixed(5)}',
                                style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'Monospace'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: descriptionController,
                        maxLines: 2,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: _inputDecoration('Descripción rápida'),
                        validator: (val) => val == null || val.isEmpty ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          onPressed: () {
                            if (formKey.currentState!.validate()) {
                              final newBusinessData = {
                                'id': DateTime.now().millisecondsSinceEpoch.toString(),
                                'name': nameController.text,
                                'category': selectedCategoryForm,
                                'rating': 0.0,
                                'ratingsCount': 0,
                                'reviews': <Map<String, dynamic>>[],
                                'location': location,
                                'address': addressController.text,
                                'description': descriptionController.text,
                                'isPromoted': true,
                              };

                              Navigator.pop(context);
                              _showPaymentModal(newBusinessData);
                            }
                          },
                          child: const Text(
                            'CONTINUAR AL PAGO \$5.00',
                            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showBusinessDetailsModal() {
    if (selectedBusiness == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D0D0D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: Colors.white24, width: 1.5),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            List reviews = selectedBusiness!['reviews'] ?? [];

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white30,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          selectedBusiness!['name'].toString().toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  Text(
                    selectedBusiness!['category'],
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    selectedBusiness!['description'] ?? 'Sin descripción disponible.',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.white54, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          selectedBusiness!['address'],
                          style: const TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.white, size: 20),
                          const SizedBox(width: 6),
                          Text(
                            '${selectedBusiness!['rating']} / 5.0',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            ' (${selectedBusiness!['ratingsCount']} opiniones)',
                            style: const TextStyle(color: Colors.white38, fontSize: 12),
                          ),
                        ],
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _showAddReviewModal();
                        },
                        child: const Text('OPINAR', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'RESEÑAS DEL PÚBLICO',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: reviews.isEmpty
                        ? const Center(
                            child: Text(
                              'Aún no hay reseñas. ¡Sé el primero en opinar!',
                              style: TextStyle(color: Colors.white38, fontSize: 13),
                            ),
                          )
                        : ListView.builder(
                            itemCount: reviews.length,
                            itemBuilder: (context, index) {
                              final rev = reviews[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF141414),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        ...List.generate(5, (sIndex) {
                                          return Icon(
                                            sIndex < rev['stars'] ? Icons.star : Icons.star_border,
                                            color: Colors.white,
                                            size: 14,
                                          );
                                        }),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${rev['stars']}.0',
                                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                    if (rev['comment'] != null && rev['comment'].toString().isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        rev['comment'],
                                        style: const TextStyle(color: Colors.white, fontSize: 13),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAddReviewModal() {
    if (selectedBusiness == null) return;
    int selectedStars = 5;
    final commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D0D0D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: Colors.white24, width: 1.5),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 24,
                left: 24,
                right: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CALIFICAR ${selectedBusiness!['name'].toString().toUpperCase()}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starValue = index + 1;
                      return IconButton(
                        icon: Icon(
                          starValue <= selectedStars ? Icons.star : Icons.star_border,
                          color: Colors.white,
                          size: 32,
                        ),
                        onPressed: () {
                          setModalState(() => selectedStars = starValue);
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: commentController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: _inputDecoration('Escribe tu opinión (opcional)'),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        setState(() {
                          List reviews = selectedBusiness!['reviews'] ?? [];
                          reviews.add({
                            'stars': selectedStars,
                            'comment': commentController.text,
                          });

                          int currentCount = selectedBusiness!['ratingsCount'] ?? 0;
                          double currentRating = (selectedBusiness!['rating'] as num).toDouble();

                          double newTotalScore = (currentRating * currentCount) + selectedStars;
                          int newCount = currentCount + 1;
                          double newRating = newTotalScore / newCount;

                          selectedBusiness!['rating'] = double.parse(newRating.toStringAsFixed(1));
                          selectedBusiness!['ratingsCount'] = newCount;
                          selectedBusiness!['reviews'] = reviews;
                        });

                        Navigator.pop(context);
                        _showBusinessDetailsModal();
                      },
                      child: const Text('PUBLICAR RESEÑA', style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showSavedModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D0D0D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: Colors.white24, width: 1.5),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'LOCALES GUARDADOS',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.2),
              ),
              const SizedBox(height: 16),
              favoriteBusinesses.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text(
                          'No tienes locales guardados.',
                          style: TextStyle(color: Colors.white38, fontSize: 13),
                        ),
                      ),
                    )
                  : Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: favoriteBusinesses.length,
                        itemBuilder: (context, index) {
                          final fav = favoriteBusinesses[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white10,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(_getCategoryIcon(fav['category']), color: Colors.white, size: 18),
                            ),
                            title: Text(
                              fav['name'],
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              fav['category'],
                              style: const TextStyle(color: Colors.white38, fontSize: 11),
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              setState(() => selectedBusiness = fav);
                              _mapController.move(fav['location'] as LatLng, 16.0);
                            },
                          );
                        },
                      ),
                    ),
            ],
          ),
        );
      },
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
      filled: true,
      fillColor: const Color(0xFF141414),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: const BorderSide(color: Colors.white12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: const BorderSide(color: Colors.white),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredBusinesses = selectedCategory == 'Todos'
        ? businesses
        : businesses.where((b) => b['category'] == selectedCategory).toList();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation,
              initialZoom: 14.0,
              onTap: (tapPosition, point) {
                if (_isSelectingLocationOnMap) {
                  setState(() => _selectedLocationForNewStore = point);
                } else {
                  setState(() => selectedBusiness = null);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.mi_comunidad',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _currentLocation,
                    width: 44,
                    height: 44,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: const [BoxShadow(color: Colors.white24, blurRadius: 10)],
                      ),
                      child: const Center(
                        child: CircleAvatar(backgroundColor: Colors.white, radius: 5),
                      ),
                    ),
                  ),

                  if (_isSelectingLocationOnMap && _selectedLocationForNewStore != null)
                    Marker(
                      point: _selectedLocationForNewStore!,
                      width: 50,
                      height: 50,
                      child: const Icon(Icons.location_on, color: Colors.white, size: 48),
                    ),

                  ...filteredBusinesses.map((b) {
                    final bool isSelected = selectedBusiness?['id'] == b['id'];
                    final bool isPromoted = b['isPromoted'] == true;

                    return Marker(
                      point: b['location'] as LatLng,
                      width: 46,
                      height: 46,
                      child: GestureDetector(
                        onTap: () {
                          if (!_isSelectingLocationOnMap) {
                            setState(() => selectedBusiness = b);
                            _mapController.move(b['location'] as LatLng, 15.0);
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : Colors.black,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isPromoted ? Colors.white : Colors.white54,
                              width: isPromoted ? 2.5 : 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isSelected ? Colors.white38 : Colors.black54,
                                blurRadius: isSelected ? 12 : 4,
                              ),
                            ],
                          ),
                          child: Icon(
                            _getCategoryIcon(b['category']),
                            color: isSelected ? Colors.black : Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),

          if (!_isSelectingLocationOnMap)
            SafeArea(
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D0D0D).withOpacity(0.92),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white24, width: 1.2),
                      boxShadow: const [BoxShadow(color: Colors.black, blurRadius: 15)],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search, color: Colors.white54),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: TextField(
                            style: TextStyle(color: Colors.white, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Explorar comunidad...',
                              hintStyle: TextStyle(color: Colors.white38, fontSize: 14),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.power_settings_new, color: Colors.white54),
                          onPressed: _logout,
                        ),
                      ],
                    ),
                  ),

                  SizedBox(
                    height: 38,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final cat = categories[index];
                        final isSelected = selectedCategory == cat;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedCategory = cat;
                                selectedBusiness = null;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white : const Color(0xFF0D0D0D).withOpacity(0.9),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected ? Colors.white : Colors.white24,
                                ),
                              ),
                              child: Text(
                                cat.toUpperCase(),
                                style: TextStyle(
                                  color: isSelected ? Colors.black : Colors.white70,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

          if (_isSelectingLocationOnMap)
            Positioned(
              top: 50,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D0D0D),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: const [BoxShadow(color: Colors.black, blurRadius: 20)],
                ),
                child: Column(
                  children: [
                    const Text(
                      'SELECCIONA UBICACIÓN',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Toca un punto exacto sobre el mapa',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.white24),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => setState(() => _isSelectingLocationOnMap = false),
                            child: const Text('CANCELAR', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: _selectedLocationForNewStore == null ? null : _confirmSelectedLocation,
                            child: const Text('CONFIRMAR', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),

          if (!_isSelectingLocationOnMap)
            Positioned(
              right: 16,
              bottom: selectedBusiness == null ? 24 : 230,
              child: Column(
                children: [
                  FloatingActionButton.small(
                    heroTag: 'btnSaved',
                    backgroundColor: const Color(0xFF0D0D0D),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: Colors.white24),
                    ),
                    onPressed: _showSavedModal,
                    child: const Icon(Icons.bookmark_outline, size: 18),
                  ),
                  const SizedBox(height: 10),
                  FloatingActionButton.small(
                    heroTag: 'btnGps',
                    backgroundColor: const Color(0xFF0D0D0D),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: Colors.white24),
                    ),
                    onPressed: _determinePosition,
                    child: _isLoadingLocation
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location, size: 18),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: _startMapLocationPicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: const [BoxShadow(color: Colors.white12, blurRadius: 10)],
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.add, color: Colors.black, size: 20),
                          SizedBox(width: 6),
                          Text(
                            'PUBLICAR \$5',
                            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.8),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (selectedBusiness != null && !_isSelectingLocationOnMap)
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0D0D0D).withOpacity(0.95),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white24, width: 1.2),
                  boxShadow: const [BoxShadow(color: Colors.black, blurRadius: 25)],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      selectedBusiness!['name'],
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    if (selectedBusiness!['isPromoted'] == true) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: Colors.white),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'PRO',
                                          style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  selectedBusiness!['address'],
                                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              // Se evalúa el widget.isAdmin recibido por parámetro
                              if (widget.isAdmin)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.white54),
                                  onPressed: () => _deleteBusiness(
                                    selectedBusiness!['id'],
                                    selectedBusiness!['name'],
                                  ),
                                ),
                              IconButton(
                                icon: Icon(
                                  favoriteBusinesses.any((element) => element['id'] == selectedBusiness!['id'])
                                      ? Icons.bookmark
                                      : Icons.bookmark_border,
                                  color: Colors.white,
                                ),
                                onPressed: () => _toggleFavorite(selectedBusiness!),
                              ),
                            ],
                          )
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: _showBusinessDetailsModal,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white10,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.star, color: Colors.white, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    selectedBusiness!['rating'] > 0
                                        ? '${selectedBusiness!['rating']} (${selectedBusiness!['ratingsCount']})'
                                        : '0.0 (Ver/Opinaciones)',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.near_me, color: Colors.white, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  '${_calculateDistance(selectedBusiness!['location'] as LatLng).toStringAsFixed(1)} km',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: _showBusinessDetailsModal,
                            child: Row(
                              children: const [
                                Text('MÁS DETALLES', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                                Icon(Icons.chevron_right, color: Colors.white, size: 16),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Restaurantes':
        return Icons.restaurant ;
      case 'Hoteles':
        return Icons.hotel;
      case 'Farmacias':
        return Icons.local_pharmacy;
      default:
        return Icons.storefront;
    }
  }
}