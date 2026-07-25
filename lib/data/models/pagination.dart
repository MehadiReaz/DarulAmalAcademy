import '../../core/utils/json_utils.dart';

/// Matches the `pagination` block in `SupportTicketController@index`.
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

  bool get hasMore => currentPage < lastPage;
  int get nextPage => currentPage + 1;
}

/// Generic list + pagination wrapper.
class Paginated<T> {
  final List<T> items;
  final Pagination pagination;

  const Paginated({required this.items, required this.pagination});
}
