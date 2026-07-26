import '../../core/utils/json_utils.dart';

/// Page metadata.
///
/// The API returns pagination in two different shapes:
///
///  * A raw Laravel paginator, where `current_page` / `last_page` /
///    `per_page` / `total` sit alongside a `data` array — used by
///    notices, tickets, fee dues, fee history, recordings and the class
///    routine.
///  * A nested `pagination: {}` object — used by group-chat messages.
///
/// Both have identical keys, so one parser covers them; [fromEnvelope]
/// picks whichever is present.
class Pagination {
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  const Pagination({
    this.currentPage = 1,
    this.lastPage = 1,
    this.perPage = 10,
    this.total = 0,
  });

  factory Pagination.fromJson(Map<String, dynamic> json) => Pagination(
        currentPage: asInt(json['current_page'], fallback: 1),
        lastPage: asInt(json['last_page'], fallback: 1),
        perPage: asInt(json['per_page'], fallback: 10),
        total: asInt(json['total']),
      );

  /// Reads page metadata from a response body whether it is a raw
  /// paginator or carries a nested `pagination` object.
  factory Pagination.fromEnvelope(Map<String, dynamic> json) {
    final nested = asMap(json['pagination']);
    return Pagination.fromJson(nested ?? json);
  }

  bool get hasMore => currentPage < lastPage;
  int get nextPage => currentPage + 1;
}

/// Generic list + pagination wrapper.
class Paginated<T> {
  final List<T> items;
  final Pagination pagination;

  const Paginated({required this.items, required this.pagination});

  static Paginated<T> empty<T>() =>
      Paginated<T>(items: const [], pagination: const Pagination());
}
