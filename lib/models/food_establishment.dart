class FoodEstablishment {
  const FoodEstablishment({
    required this.id,
    required this.name,
    required this.businessType,
    required this.address,
    required this.postcode,
    required this.rating,
    required this.ratingDate,
    required this.localAuthority,
    required this.schemeType,
    required this.newRatingPending,
    this.distanceMiles,
    this.latitude,
    this.longitude,
  });

  final int id;
  final String name;
  final String businessType;
  final String address;
  final String postcode;
  final String rating;
  final DateTime? ratingDate;
  final String localAuthority;
  final String schemeType;
  final bool newRatingPending;
  final double? distanceMiles;
  final double? latitude;
  final double? longitude;

  bool get hasCoordinates => latitude != null && longitude != null;

  bool get hasNumericRating => int.tryParse(rating) != null;

  int? get numericRating => int.tryParse(rating);

  String? get ratingDateLabel {
    final date = ratingDate;
    if (date == null) return null;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String get ratingSummary {
    final value = numericRating;
    if (value != null) {
      return switch (value) {
        5 => 'Very good',
        4 => 'Good',
        3 => 'Generally satisfactory',
        2 => 'Some improvement necessary',
        1 => 'Major improvement necessary',
        0 => 'Urgent improvement necessary',
        _ => 'Official rating',
      };
    }

    return switch (rating.toLowerCase()) {
      'pass' => 'Meets hygiene standards',
      'pass and eat safe' => 'Meets hygiene standards',
      'improvement required' => 'Improvement required',
      'awaiting inspection' => 'Awaiting inspection',
      'awaiting publication' => 'Awaiting publication',
      'exempt' => 'Exempt from rating',
      _ => rating,
    };
  }

  factory FoodEstablishment.fromJson(Map<String, dynamic> json) {
    final geocode = json['geocode'] as Map<String, dynamic>? ?? const {};
    final addressParts = [
      json['AddressLine1'],
      json['AddressLine2'],
      json['AddressLine3'],
      json['AddressLine4'],
    ]
        .whereType<String>()
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();

    return FoodEstablishment(
      id: _asInt(json['FHRSID']),
      name: _asString(json['BusinessName'], fallback: 'Unknown business'),
      businessType: _asString(json['BusinessType'], fallback: 'Food business'),
      address: addressParts.join(', '),
      postcode: _asString(json['PostCode']),
      rating: _asString(json['RatingValue'], fallback: 'Not rated'),
      ratingDate: DateTime.tryParse(_asString(json['RatingDate'])),
      localAuthority: _asString(json['LocalAuthorityName']),
      schemeType: _asString(json['SchemeType'], fallback: 'FHRS'),
      newRatingPending: json['NewRatingPending'] == true,
      distanceMiles: _asDouble(json['Distance']),
      latitude: _asDouble(geocode['latitude'] ?? geocode['Latitude']),
      longitude: _asDouble(geocode['longitude'] ?? geocode['Longitude']),
    );
  }

  static String _asString(Object? value, {String fallback = ''}) {
    final result = value?.toString().trim() ?? '';
    return result.isEmpty ? fallback : result;
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}

class FoodHygienePage {
  const FoodHygienePage({
    required this.establishments,
    required this.pageNumber,
    required this.totalPages,
    required this.totalCount,
  });

  final List<FoodEstablishment> establishments;
  final int pageNumber;
  final int totalPages;
  final int totalCount;

  bool get hasMore => pageNumber < totalPages;

  factory FoodHygienePage.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] as Map<String, dynamic>? ?? const {};
    final rawEstablishments =
        json['establishments'] as List<dynamic>? ?? const [];

    return FoodHygienePage(
      establishments: rawEstablishments
          .whereType<Map<String, dynamic>>()
          .map(FoodEstablishment.fromJson)
          .toList(),
      pageNumber: _metaInt(meta['pageNumber'], fallback: 1),
      totalPages: _metaInt(meta['totalPages'], fallback: 1),
      totalCount: _metaInt(meta['totalCount']),
    );
  }

  static int _metaInt(Object? value, {int fallback = 0}) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}
