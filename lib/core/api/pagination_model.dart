/// Standard pagination envelope for list endpoints.
/// Adheres to Section 25 (Pagination Standard).
class PaginationMeta {
  final int page;
  final int limit;
  final int totalCount;
  final int totalPages;
  final bool hasNextPage;
  final bool hasPrevPage;

  const PaginationMeta({
    required this.page,
    required this.limit,
    required this.totalCount,
    required this.totalPages,
    required this.hasNextPage,
    required this.hasPrevPage,
  });

  factory PaginationMeta.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const PaginationMeta(
        page: 1,
        limit: 20,
        totalCount: 0,
        totalPages: 1,
        hasNextPage: false,
        hasPrevPage: false,
      );
    }

    final page = (json['page'] as num?)?.toInt() ?? 1;
    final limit = (json['limit'] as num?)?.toInt() ?? 20;
    final totalCount = (json['totalCount'] as num?)?.toInt() ?? (json['total'] as num?)?.toInt() ?? 0;
    final totalPages = (json['totalPages'] as num?)?.toInt() ?? ((totalCount / (limit > 0 ? limit : 20)).ceil());
    final hasNext = json['hasNextPage'] as bool? ?? (page < totalPages);
    final hasPrev = json['hasPrevPage'] as bool? ?? (page > 1);

    return PaginationMeta(
      page: page,
      limit: limit,
      totalCount: totalCount,
      totalPages: totalPages,
      hasNextPage: hasNext,
      hasPrevPage: hasPrev,
    );
  }
}

/// Generic container for paginated responses.
class PaginatedList<T> {
  final List<T> items;
  final PaginationMeta meta;

  const PaginatedList({
    required this.items,
    required this.meta,
  });

  factory PaginatedList.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic item) fromJsonT, {
    String itemsKey = 'items',
  }) {
    final rawList = json[itemsKey] ?? json['data'] ?? [];
    final List<T> items = (rawList is List)
        ? rawList.map((e) => fromJsonT(e)).toList()
        : <T>[];

    final meta = PaginationMeta.fromJson(
      (json['meta'] is Map<String, dynamic>) ? json['meta'] as Map<String, dynamic> : json,
    );

    return PaginatedList<T>(items: items, meta: meta);
  }
}
