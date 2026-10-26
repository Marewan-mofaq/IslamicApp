class City {
  final String id;
  final String ku;
  final String ar;
  final String en;
  final String country;
  final String countryKu;
  final String? countryAr;
  final String? countryEn;
  final double lat;
  final double lng;

  City({
    required this.id,
    required this.ku,
    required this.ar,
    required this.en,
    required this.country,
    required this.countryKu,
    this.countryAr,
    this.countryEn,
    required this.lat,
    required this.lng,
  });

  factory City.fromJson(Map<String, dynamic> json) {
    return City(
      id: (json['id'] ?? '').toString(),
      ku: (json['ku'] ?? '').toString(),
      ar: (json['ar'] ?? '').toString(),
      en: (json['en'] ?? '').toString(),
      country: (json['country'] ?? '').toString(),
      countryKu: (json['country_ku'] ?? '').toString(),
      countryAr: json['country_ar']?.toString(),
      countryEn: json['country_en']?.toString(),
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ku': ku,
      'ar': ar,
      'en': en,
      'country': country,
      'country_ku': countryKu,
      if (countryAr != null) 'country_ar': countryAr,
      if (countryEn != null) 'country_en': countryEn,
      'lat': lat,
      'lng': lng,
    };
  }
}
