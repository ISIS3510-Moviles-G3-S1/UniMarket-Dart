import 'dart:collection';
class EcoCacheEntry {
  EcoCacheEntry({
    required this.ecoMessage,
    required this.requestHash,
    required this.createdAt,
  });

  final String ecoMessage;
  final String requestHash;
  final DateTime createdAt;

  bool isExpired(int ttlMinutes) {
    final age = DateTime.now().difference(createdAt).inMinutes;
    return age > ttlMinutes;
  }
}

class EcoCache {
  EcoCache({
    this.maxSize = 20,
    this.ttlMinutes = 60,
  });

  final int maxSize;
  final int ttlMinutes;


  final LinkedHashMap<String, EcoCacheEntry> _cache = LinkedHashMap<String, EcoCacheEntry>();

  int _hits = 0;
  int _misses = 0;

  double get hitRate {
    final total = _hits + _misses;
    if (total == 0) return 0.0;
    return _hits / total;
  }

  /// Retorna hits totales.
  int get hits => _hits;

  /// Retorna misses totales.
  int get misses => _misses;

  /// Retorna tamaño actual del cache.
  int get size => _cache.length;

  /// Retorna capacidad máxima.
  int get capacity => maxSize;

  String? get(String requestHash) {
    final entry = _cache[requestHash];
    if (entry == null) {
      _misses++;
      return null;
    }

    if (entry.isExpired(ttlMinutes)) {
      _cache.remove(requestHash);
      _misses++;
      return null;
    }

    // ── Actualizar orden MRU ──────────────────────────────────────────
    // En LinkedHashMap, remover + re-insertar pone al final (más reciente).
    _cache.remove(requestHash);
    _cache[requestHash] = entry;

    _hits++;
    return entry.ecoMessage;
  }


  void put(String requestHash, String ecoMessage) {
    // Si ya existe, actualizar directamente (no afecta orden).
    if (_cache.containsKey(requestHash)) {
      _cache[requestHash] = EcoCacheEntry(
        ecoMessage: ecoMessage,
        requestHash: requestHash,
        createdAt: DateTime.now(),
      );
      // Mover al final para marcar como MRU:
      _cache.remove(requestHash);
      _cache[requestHash] = EcoCacheEntry(
        ecoMessage: ecoMessage,
        requestHash: requestHash,
        createdAt: DateTime.now(),
      );
      return;
    }

    // ── Eviction: Cuando lleno, sacar el LRU (primer entry) ──────────
    if (_cache.length >= maxSize) {
      // En LinkedHashMap, .keys.first es el más antiguo (LRU).
      final lruKey = _cache.keys.first;
      _cache.remove(lruKey);
    }

    _cache[requestHash] = EcoCacheEntry(
      ecoMessage: ecoMessage,
      requestHash: requestHash,
      createdAt: DateTime.now(),
    );
  }

  /// Invalida toda la caché (limpia cuando perfil cambia o se sube una prenda).
  void invalidate() {
    _cache.clear();
    _hits = 0;
    _misses = 0;
  }

  /// Retorna estadísticas de debug en formato legible.
  String getStats() {
    final total = _hits + _misses;
    final rate = total == 0 ? 0.0 : (_hits / total * 100).toStringAsFixed(2);
    return 'ECO CACHE: size=$size/$capacity, hits=$_hits, misses=$_misses, hitRate=$rate%';
  }
}
