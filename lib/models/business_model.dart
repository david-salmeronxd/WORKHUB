import 'package:latlong2/latlong.dart';

class Review {
  final String id;
  final String userName;
  final double rating;
  final String comment;
  final DateTime date;

  Review({
    required this.id,
    required this.userName,
    required this.rating,
    required this.comment,
    required this.date,
  });
}

class Business {
  final String id;
  final String name;
  final String category;
  final LatLng location;
  final String address;
  final String description;
  final String phoneNumber;
  final String whatsappNumber;
  final String openingHours;
  final bool isOpenNow;
  final bool isPromoted;
  final String? activeOffer;
  final List<String> imageUrls;
  final List<Review> reviews;

  Business({
    required this.id,
    required this.name,
    required this.category,
    required this.location,
    required this.address,
    required this.description,
    required this.phoneNumber,
    required this.whatsappNumber,
    required this.openingHours,
    this.isOpenNow = true,
    this.isPromoted = false,
    this.activeOffer,
    this.imageUrls = const [],
    this.reviews = const [],
  });

  double get averageRating {
    if (reviews.isEmpty) return 0.0;
    double total = reviews.fold(0, (sum, item) => sum + item.rating);
    return total / reviews.length;
  }
}