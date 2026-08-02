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

  /// POST /student/fees/pay/initiate  { id, invoiceId }
  ///
  /// Both spellings are sent on purpose. The app has always sent
  /// `invoiceId` (camelCase, matching the validator this was written
  /// against) while the current Postman collection sends `id`. Laravel
  /// ignores unexpected keys, so submitting both works against either
  /// validator and removes a guess from the payment path — drop one once
  /// the controller is confirmed.
  Future<PaymentInitiation> initiatePayment(int invoiceId) async {
    final data = await _client.post(
      ApiEndpoints.feePayInitiate,
      body: {'id': invoiceId, 'invoiceId': invoiceId},
    );
    return PaymentInitiation.fromJson(asMap(data) ?? {});
  }

  /// GET /student/fees/pay/webview-url?transaction_id=
  ///
  /// A second way to reach the gateway: some gateways answer
  /// `/pay/initiate` with a transaction but no checkout link, and the
  /// hosted page has to be requested separately. Returns null when the
  /// server has no URL to give rather than throwing, so the caller can
  /// fall through to its own error message.
  Future<String?> webviewUrl(String transactionId) async {
    final data = await _client.get(
      ApiEndpoints.feePayWebviewUrl,
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

  /// POST /student/fees/pay/verify  { transaction_id }
  ///
  /// Returns the transaction's post-verification state. Called after the
  /// student returns from the gateway.
  Future<FeeTransaction?> verifyPayment(
    String transactionId, {
    String? paymentId,
    String? signature,
  }) async {
    final body = <String, dynamic>{'transaction_id': transactionId};
    if (paymentId != null) body['razorpay_payment_id'] = paymentId;
    if (signature != null) body['razorpay_signature'] = signature;

    final data = await _client.post(
      ApiEndpoints.feePayVerify,
      body: body,
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
  Future<BinaryResponse> receipt(int transactionId) {
    return _client.getBytes(
      ApiEndpoints.feeReceipt(transactionId),
      accept: 'application/pdf',
    );
  }
}
