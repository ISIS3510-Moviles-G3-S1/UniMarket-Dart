enum AIOutfitSyncStatus { synced, pending, failed }

AIOutfitSyncStatus aiOutfitSyncStatusFromString(String? value) {
  switch ((value ?? '').trim().toLowerCase()) {
    case 'pending':
      return AIOutfitSyncStatus.pending;
    case 'failed':
      return AIOutfitSyncStatus.failed;
    case 'synced':
    default:
      return AIOutfitSyncStatus.synced;
  }
}

String aiOutfitSyncStatusToString(AIOutfitSyncStatus status) {
  switch (status) {
    case AIOutfitSyncStatus.pending:
      return 'pending';
    case AIOutfitSyncStatus.failed:
      return 'failed';
    case AIOutfitSyncStatus.synced:
      return 'synced';
  }
}

class AIOutfitAnalysis {
  final String id;
  final DateTime createdAt;
  final List<String> imagePaths;
  final List<String> thumbnailPaths;
  final List<String> categories;
  final List<String> dominantColors;
  final String style;
  final String aesthetic;
  final String outfitAdvice;
  final List<String> missingItems;
  final List<String> marketplaceTags;
  final bool fromCache;
  final AIOutfitSyncStatus syncStatus;
  final String cacheKey;
  final String? errorMessage;

  const AIOutfitAnalysis({
    required this.id,
    required this.createdAt,
    required this.imagePaths,
    this.thumbnailPaths = const [],
    required this.categories,
    required this.dominantColors,
    required this.style,
    required this.aesthetic,
    required this.outfitAdvice,
    required this.missingItems,
    required this.marketplaceTags,
    required this.fromCache,
    required this.syncStatus,
    required this.cacheKey,
    this.errorMessage,
  });

  AIOutfitAnalysis copyWith({
    String? id,
    DateTime? createdAt,
    List<String>? imagePaths,
    List<String>? thumbnailPaths,
    List<String>? categories,
    List<String>? dominantColors,
    String? style,
    String? aesthetic,
    String? outfitAdvice,
    List<String>? missingItems,
    List<String>? marketplaceTags,
    bool? fromCache,
    AIOutfitSyncStatus? syncStatus,
    String? cacheKey,
    String? errorMessage,
  }) {
    return AIOutfitAnalysis(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      imagePaths: imagePaths ?? this.imagePaths,
      thumbnailPaths: thumbnailPaths ?? this.thumbnailPaths,
      categories: categories ?? this.categories,
      dominantColors: dominantColors ?? this.dominantColors,
      style: style ?? this.style,
      aesthetic: aesthetic ?? this.aesthetic,
      outfitAdvice: outfitAdvice ?? this.outfitAdvice,
      missingItems: missingItems ?? this.missingItems,
      marketplaceTags: marketplaceTags ?? this.marketplaceTags,
      fromCache: fromCache ?? this.fromCache,
      syncStatus: syncStatus ?? this.syncStatus,
      cacheKey: cacheKey ?? this.cacheKey,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'createdAt': createdAt.toIso8601String(),
      'imagePaths': imagePaths,
      'thumbnailPaths': thumbnailPaths,
      'categories': categories,
      'dominantColors': dominantColors,
      'style': style,
      'aesthetic': aesthetic,
      'outfitAdvice': outfitAdvice,
      'missingItems': missingItems,
      'marketplaceTags': marketplaceTags,
      'fromCache': fromCache,
      'syncStatus': aiOutfitSyncStatusToString(syncStatus),
      'cacheKey': cacheKey,
      'errorMessage': errorMessage,
    };
  }

  static AIOutfitAnalysis fromJson(Map<dynamic, dynamic> json) {
    DateTime parseDate(dynamic value) {
      if (value is DateTime) return value;
      if (value is String && value.trim().isNotEmpty) {
        return DateTime.tryParse(value) ?? DateTime.now();
      }
      return DateTime.now();
    }

    List<String> toStringList(dynamic value) {
      if (value is List) {
        return value.map((item) => item.toString()).where((item) => item.trim().isNotEmpty).toList();
      }
      if (value is String && value.trim().isNotEmpty) {
        return [value];
      }
      return const <String>[];
    }

    return AIOutfitAnalysis(
      id: (json['id'] ?? '').toString(),
      createdAt: parseDate(json['createdAt']),
      imagePaths: toStringList(json['imagePaths']),
      thumbnailPaths: toStringList(json['thumbnailPaths']),
      categories: toStringList(json['categories']),
      dominantColors: toStringList(json['dominantColors']),
      style: (json['style'] ?? '').toString(),
      aesthetic: (json['aesthetic'] ?? '').toString(),
      outfitAdvice: (json['outfitAdvice'] ?? '').toString(),
      missingItems: toStringList(json['missingItems']),
      marketplaceTags: toStringList(json['marketplaceTags']),
      fromCache: json['fromCache'] == true,
      syncStatus: aiOutfitSyncStatusFromString(json['syncStatus']?.toString()),
      cacheKey: (json['cacheKey'] ?? '').toString(),
      errorMessage: json['errorMessage']?.toString(),
    );
  }
}