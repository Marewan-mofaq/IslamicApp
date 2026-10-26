class HadithCollection {
  final String id;
  final String nameKu;
  final String nameAr;
  final String nameEn;

  HadithCollection({
    required this.id,
    required this.nameKu,
    required this.nameAr,
    required this.nameEn,
  });

  factory HadithCollection.fromJson(Map<String, dynamic> json) {
    return HadithCollection(
      id: (json['id'] ?? '').toString(),
      nameKu: (json['name_ku'] ?? '').toString(),
      nameAr: (json['name_ar'] ?? '').toString(),
      nameEn: (json['name_en'] ?? '').toString(),
    );
  }
}

class Hadith {
  final int id;
  final String collection;
  final int number;
  final String arabic;
  final String translationKu;
  final String translationEn;
  final String narratorKu;
  final String narratorAr;
  final String narratorEn;

  Hadith({
    required this.id,
    required this.collection,
    required this.number,
    required this.arabic,
    required this.translationKu,
    required this.translationEn,
    required this.narratorKu,
    required this.narratorAr,
    required this.narratorEn,
  });

  factory Hadith.fromJson(Map<String, dynamic> json) {
    return Hadith(
      id: (json['id'] as num?)?.toInt() ?? 0,
      collection: (json['collection'] ?? '').toString(),
      number: (json['number'] as num?)?.toInt() ?? 0,
      arabic: (json['arabic'] ?? '').toString(),
      translationKu: (json['translationKu'] ?? '').toString(),
      translationEn: (json['translationEn'] ?? '').toString(),
      narratorKu: (json['narrator_ku'] ?? '').toString(),
      narratorAr: (json['narrator_ar'] ?? '').toString(),
      narratorEn: (json['narrator_en'] ?? '').toString(),
    );
  }
}
