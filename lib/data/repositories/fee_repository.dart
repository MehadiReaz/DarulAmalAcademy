import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/json_utils.dart';
import '../models/fee.dart';
import '../models/pagination.dart';

class FeeRepository {
  final ApiClient _client;

  FeeRepository(this._client);

  /// GET /api/student/transactions
  Future<dynamic> transactions({
    String? keyword,
    String? startDate,
    String? endDate,
    String? status,
    String? type,
    String? overdue,
    int? page,
  }) async {
    final query = <String, dynamic>{};
    if (keyword != null && keyword.isNotEmpty) query['keyword'] = keyword;
    if (startDate != null && startDate.isNotEmpty) query['start_date'] = startDate;
    if (endDate != null && endDate.isNotEmpty) query['end_date'] = endDate;
    if (status != null && status.isNotEmpty) query['status'] = status;
    if (type != null && type.isNotEmpty) query['type'] = type;
    if (overdue != null && overdue.isNotEmpty) query['over_due'] = overdue;
    if (page != null) query['page'] = page;

    return await _client.get(
      ApiEndpoints.studentTransactions,
      query: query.isEmpty ? null : query,
    );
  }

  /// GET /api/student/transactions/{transaction_no}
  Future<dynamic> transactionDetail(String transactionNo) async {
    return await _client.get(ApiEndpoints.studentTransactionDetail(transactionNo));
  }

  /// GET /api/student/fees/dues
  Future<Paginated<FeeTransaction>> dues({int page = 1, String? keyword, int? perPage}) =>
      _paginated(ApiEndpoints.studentFeeDues, page, keyword: keyword, perPage: perPage);

  /// GET /api/student/fees/history
  Future<Paginated<FeeTransaction>> history({int page = 1, String? keyword, int? perPage}) =>
      _paginated(ApiEndpoints.studentFeeHistory, page, keyword: keyword, perPage: perPage);

  Future<Paginated<FeeTransaction>> _paginated(
    String path,
    int page, {
    String? keyword,
    int? perPage,
  }) async {
    final query = <String, dynamic>{'page': page};
    if (keyword != null && keyword.isNotEmpty) query['keyword'] = keyword;
    if (perPage != null) query['per_page'] = perPage;

    final data = await _client.get(path, query: query);
    final map = asMap(data) ?? {};
    return Paginated(
      items: asList(map['data'], FeeTransaction.fromJson),
      pagination: Pagination.fromEnvelope(map),
    );
  }

  /// POST /api/student/fees/pay/initiate (form-data: id)
  Future<PaymentInitiation> initiatePayment(int invoiceId) async {
    final data = await _client.postForm(
      ApiEndpoints.studentFeePayInitiate,
      {'id': invoiceId.toString(), 'invoiceId': invoiceId.toString()},
    );
    return PaymentInitiation.fromJson(asMap(data) ?? {});
  }

  /// GET /api/student/fees/pay/webview-url?transaction_id=
  Future<String?> webviewUrl(String transactionId) async {
    final data = await _client.get(
      ApiEndpoints.studentFeePayWebviewUrl,
      query: {'transaction_id': transactionId},
    );

    if (data is String) return data.isEmpty ? null : data;

    final map = asMap(data) ?? {};
    return asStringOrNull(map['url']) ??
        asStringOrNull(map['webview_url']) ??
        asStringOrNull(map['payment_url']) ??
        asStringOrNull(map['redirect_url']) ??
        asStringOrNull(map['link']);
  }

  /// POST /api/student/fees/pay/razorpay/verify (form-data)
  Future<FeeTransaction?> verifyPayment(
    String transactionId, {
    String? paymentId,
    String? orderId,
    String? signature,
  }) async {
    final body = <String, dynamic>{
      'transaction_id': transactionId,
      'razorpay_payment_id': paymentId ?? '',
      'razorpay_order_id': orderId ?? '',
      'razorpay_signature': signature ?? '',
    };

    final data = await _client.postForm(
      ApiEndpoints.studentFeeRazorpayVerify,
      body,
    );
    final map = asMap(data);
    if (map == null) return null;
    final txn = asMap(map['transaction']) ?? map;
    return FeeTransaction.fromJson(txn);
  }

  /// GET /api/student/fees/receipt/{transactionId}
  Future<BinaryResponse> receipt(int transactionId) {
    return _client.getBytes(
      ApiEndpoints.studentFeeReceipt(transactionId),
      accept: 'application/pdf',
    );
  }
}
