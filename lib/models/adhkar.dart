class AdhkarCategory {
  final String id;
  final String icon;
  final String color;
  final String ku;
  final String ar;
  final String en;

  AdhkarCategory({
    required this.id,
    required this.icon,
    required this.color,
    required this.ku,
    required this.ar,
    required this.en,
  });

  factory AdhkarCategory.fromJson(Map<String, dynamic> json) {
    return AdhkarCategory(
      id: (json['id'] ?? '').toString(),
      icon: (json['icon'] ?? '').toString(),
      color: (json['color'] ?? '').toString(),
      ku: (json['ku'] ?? '').toString(),
      ar: (json['ar'] ?? '').toString(),
      en: (json['en'] ?? '').toString(),
    );
  }
}

class AdhkarItem {
  final String id;
  final String arabic;
  final String translationKu;
  final String translationEn;
  final int repeat;
  final String source;

  AdhkarItem({
    required this.id,
    required this.arabic,
    required this.translationKu,
    required this.translationEn,
    required this.repeat,
    required this.source,
  });

  factory AdhkarItem.fromJson(Map<String, dynamic> json) {
    return AdhkarItem(
      id: (json['id'] ?? '').toString(),
      arabic: (json['arabic'] ?? '').toString(),
      translationKu: (json['translationKu'] ?? '').toString(),
      translationEn: (json['translationEn'] ?? '').toString(),
      repeat: (json['repeat'] as num?)?.toInt() ?? 1,
      source: (json['source'] ?? '').toString(),
    );
  }
}
