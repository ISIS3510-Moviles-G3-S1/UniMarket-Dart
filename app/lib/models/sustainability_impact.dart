/// Environmental impact coefficients and accumulation logic for reused
/// clothing items — ported from the Swift ImpactCategory / SustainabilityImpact
/// models.
///
/// Figures are rough per-garment averages drawn from UNEP / Ellen MacArthur /
/// WWF textile footprint references (same source as the Swift app).

enum ImpactCategory {
  jacket,
  jeans,
  dress,
  top,
  shoes,
  accessory,
  other;

  /// (water in litres, CO2 in kg, waste in kg) per reused garment.
  ({int water, double co2, double waste}) get coefficients {
    switch (this) {
      case ImpactCategory.jacket:
        return (water: 9000, co2: 25.0, waste: 1.0);
      case ImpactCategory.jeans:
        return (water: 7500, co2: 33.0, waste: 0.8);
      case ImpactCategory.dress:
        return (water: 2500, co2: 10.0, waste: 0.4);
      case ImpactCategory.top:
        return (water: 2700, co2: 7.0, waste: 0.25);
      case ImpactCategory.shoes:
        return (water: 8000, co2: 14.0, waste: 0.8);
      case ImpactCategory.accessory:
        return (water: 1500, co2: 4.0, waste: 0.2);
      case ImpactCategory.other:
        return (water: 3000, co2: 8.0, waste: 0.4);
    }
  }

  String get displayName {
    switch (this) {
      case ImpactCategory.jacket:
        return 'Jackets & outerwear';
      case ImpactCategory.jeans:
        return 'Jeans & pants';
      case ImpactCategory.dress:
        return 'Dresses & skirts';
      case ImpactCategory.top:
        return 'Tops & shirts';
      case ImpactCategory.shoes:
        return 'Shoes';
      case ImpactCategory.accessory:
        return 'Accessories';
      case ImpactCategory.other:
        return 'Other garments';
    }
  }

  /// Infers the category from listing tags + title keywords.
  static ImpactCategory infer({required List<String> tags, required String title}) {
    final haystack = [...tags, title].map((s) => s.toLowerCase()).join(' ');

    const buckets = <ImpactCategory, List<String>>{
      ImpactCategory.jacket: ['jacket', 'coat', 'blazer', 'hoodie', 'sweater', 'cardigan', 'parka'],
      ImpactCategory.jeans: ['jeans', 'pants', 'trousers', 'shorts', 'denim'],
      ImpactCategory.dress: ['dress', 'skirt', 'gown'],
      ImpactCategory.shoes: ['shoes', 'sneaker', 'boot', 'sandal', 'heels'],
      ImpactCategory.accessory: ['bag', 'purse', 'hat', 'scarf', 'belt', 'accessory'],
      ImpactCategory.top: ['shirt', 'tee', 't-shirt', 'tshirt', 'blouse', 'top', 'polo', 'tank'],
    };

    for (final entry in buckets.entries) {
      if (entry.value.any((kw) => haystack.contains(kw))) {
        return entry.key;
      }
    }
    return ImpactCategory.other;
  }
}

class SustainabilityImpact {
  const SustainabilityImpact({
    required this.itemsReused,
    required this.waterLiters,
    required this.co2Kg,
    required this.wasteKg,
    required this.categoryCounts,
  });

  final int itemsReused;
  final int waterLiters;
  final double co2Kg;
  final double wasteKg;
  final Map<ImpactCategory, int> categoryCounts;

  static const SustainabilityImpact empty = SustainabilityImpact(
    itemsReused: 0,
    waterLiters: 0,
    co2Kg: 0,
    wasteKg: 0,
    categoryCounts: {},
  );

  /// Builds the aggregate impact for a list of sold/reused listings.
  factory SustainabilityImpact.fromListings(List<({List<String> tags, String title})> items) {
    if (items.isEmpty) return SustainabilityImpact.empty;

    var water = 0;
    var co2 = 0.0;
    var waste = 0.0;
    final counts = <ImpactCategory, int>{};

    for (final item in items) {
      final cat = ImpactCategory.infer(tags: item.tags, title: item.title);
      final c = cat.coefficients;
      water += c.water;
      co2 += c.co2;
      waste += c.waste;
      counts[cat] = (counts[cat] ?? 0) + 1;
    }

    return SustainabilityImpact(
      itemsReused: items.length,
      waterLiters: water,
      co2Kg: co2,
      wasteKg: waste,
      categoryCounts: counts,
    );
  }

  // ── Human-relatable comparisons ──────────────────────────────────────────

  /// Average shower ≈ 65 L (8 min at 8 L/min).
  int get showerEquivalents => waterLiters ~/ 65;

  /// Passenger car ≈ 0.17 kg CO2/km (EPA average).
  int get drivingKilometersAvoided => (co2Kg / 0.17).round();

  /// Mature tree absorbs ≈ 21 kg CO2/year.
  double get treeYearsEquivalent => ((co2Kg / 21.0) * 10).roundToDouble() / 10;

  List<MapEntry<ImpactCategory, int>> get topCategories {
    final sorted = categoryCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(2).toList();
  }
}
