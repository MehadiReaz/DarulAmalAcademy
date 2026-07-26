import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/json_utils.dart';
import '../models/fee.dart';
import '../models/pagination.dart';

class FeeRepository {
  final ApiClient _client;

  FeeRepository(this._client);

  /// GET /student/fees/dues  ->  raw Laravel paginator in `data`.
  Future<Paginated<FeeTransaction>> dues({int page = 1}) =>
      _paginated(ApiEndpoints.feeDues, page);

  /// GET /student/fees/history
  Future<Paginated<FeeTransaction>> history({int page = 1}) =>
      _paginated(ApiEndpoints.feeHistory, page);

  Future<Paginated<FeeTransaction>> _paginated(String path, int page) async {
    final data = await _client.get(path, query: {'page': page});
    final map = asMap(data) ?? {};
    return Paginated(
      items: asList(map['data'], FeeTransaction.fromJson),
      pagination: Pagination.fromEnvelope(map),
    );
  }

  /// POST /student/fees/pay/initiate  { invoiceId }
  ///
  /// The parameter name is camelCase on the wire — that's the server's
  /// validator (`invoiceId`), not a typo.
  Future<PaymentInitiation> initiatePayment(int invoiceId) async {
    final data = await _client.post(
      ApiEndpoints.feePayInitiate,
      body: {'invoiceId': invoiceId},
    );
    return PaymentInitiation.fromJson(asMap(data) ?? {});
  }

  /// POST /student/fees/pay/verify  { transaction_id }
  ///
  /// Returns the transaction's post-verification state. Called after the
  /// student returns from the gateway.
  Future<FeeTransaction?> verifyPayment(String transactionId) async {
    final data = await _client.post(
      ApiEndpoints.feePayVerify,
      body: {'transaction_id': transactionId},
    );
    final map = asMap(data);
    if (map == null) return null;
    // The transaction may come back nested or at the root.
    final txn = asMap(map['transaction']) ?? map;
    return FeeTransaction.fromJson(txn);
  }

  /// GET /student/fees/receipt/{transactionId}
  ///
  /// Returns whatever the server sends. In the test run this 404'd for
  /// the sample ID, so the shape is unconfirmed — the raw map is returned
  /// and the UI pulls a URL out of it if there is one.
  Future<Map<String, dynamic>> receipt(int transactionId) async {
    final data = await _client.get(ApiEndpoints.feeReceipt(transactionId));
    return asMap(data) ?? {};
  }
}
