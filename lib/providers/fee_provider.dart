import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../data/models/fee.dart';
import '../data/models/pagination.dart';
import '../data/repositories/fee_repository.dart';
import 'base_provider.dart';

/// Backs the Fees screen: outstanding dues, payment history, and the
/// gateway hand-off.
class FeeProvider extends BaseProvider {
  final FeeRepository _repo;

  FeeProvider(this._repo);

  List<FeeTransaction> _dues = [];
  Pagination _duesPage = const Pagination();
  LoadState _duesState = LoadState.idle;
  String? _duesError;

  List<FeeTransaction> _history = [];
  Pagination _historyPage = const Pagination();
  LoadState _historyState = LoadState.idle;
  String? _historyError;
  bool _loadingMoreHistory = false;
  bool _loadingMoreDues = false;

  bool _initiating = false;
  String? _payError;

  /// Transaction currently being downloaded, so only that row shows a
  /// spinner rather than the whole list.
  int? _downloadingReceiptId;
  String? _receiptError;
  PaymentInitiation? _lastInitiation;

  List<FeeTransaction> get dues => _dues;
  LoadState get duesState => _duesState;
  String? get duesError => _duesError;
  bool get loadingMoreDues => _loadingMoreDues;
  bool get hasMoreDues => _duesPage.hasMore;

  List<FeeTransaction> get history => _history;
  LoadState get historyState => _historyState;
  String? get historyError => _historyError;
  bool get loadingMoreHistory => _loadingMoreHistory;
  bool get hasMoreHistory => _historyPage.hasMore;

  bool get initiating => _initiating;
  String? get payError => _payError;
  String? get receiptError => _receiptError;
  bool isDownloadingReceipt(int id) => _downloadingReceiptId == id;
  PaymentInitiation? get lastInitiation => _lastInitiation;

  /// Total still owed across every unpaid due.
  double get totalOutstanding =>
      _dues.fold(0.0, (sum, d) => sum + d.outstanding);

  int get overdueCount => _dues.where((d) => d.isOverdue).length;

  /// Currency of the outstanding dues, or null when rows disagree — the
  /// seeded data mixes GBP and EUR, so a single symbol can't be assumed.
  String? get duesCurrency {
    final codes = _dues
        .map((d) => d.currency)
        .where((c) => c.isNotEmpty)
        .toSet();
    return codes.length == 1 ? codes.first : null;
  }

  Future<void> loadDues({bool force = false}) async {
    if (_duesState == LoadState.loading) return;
    if (_duesState == LoadState.ready && !force) return;

    final result = await guard(
      () => _repo.dues(page: 1),
      onState: (state, err) {
        _duesState = state;
        _duesError = err;
      },
    );
    if (result != null) {
      _dues = result.items;
      _duesPage = result.pagination;
    }
    safeNotify();
  }

  Future<void> loadHistory({bool force = false}) async {
    if (_historyState == LoadState.loading) return;
    if (_historyState == LoadState.ready && !force) return;

    final result = await guard(
      () => _repo.history(page: 1),
      onState: (state, err) {
        _historyState = state;
        _historyError = err;
      },
    );
    if (result != null) {
      _history = result.items;
      _historyPage = result.pagination;
    }
    safeNotify();
  }

  /// Dues are paginated at 15 per page, so a student with a long fee
  /// history needs this as much as the history tab does.
  Future<void> loadMoreDues() async {
    if (_loadingMoreDues || !_duesPage.hasMore) return;
    _loadingMoreDues = true;
    safeNotify();
    try {
      final result = await _repo.dues(page: _duesPage.nextPage);
      _dues = [..._dues, ...result.items];
      _duesPage = result.pagination;
    } on ApiException catch (e) {
      _duesError = e.message;
    } finally {
      _loadingMoreDues = false;
      safeNotify();
    }
  }

  Future<void> loadMoreHistory() async {
    if (_loadingMoreHistory || !_historyPage.hasMore) return;
    _loadingMoreHistory = true;
    safeNotify();
    try {
      final result = await _repo.history(page: _historyPage.nextPage);
      _history = [..._history, ...result.items];
      _historyPage = result.pagination;
    } on ApiException catch (e) {
      _historyError = e.message;
    } finally {
      _loadingMoreHistory = false;
      safeNotify();
    }
  }

  Future<void> refreshAll() async {
    await Future.wait([loadDues(force: true), loadHistory(force: true)]);
  }

  /// Starts a payment for an invoice and returns the gateway hand-off, or
  /// null if the server rejected it.
  Future<PaymentInitiation?> initiate(int invoiceId) async {
    _initiating = true;
    _payError = null;
    safeNotify();
    try {
      final result = await _repo.initiatePayment(invoiceId);
      _lastInitiation = result;
      return result;
    } on ApiException catch (e) {
      _payError = e.message;
      return null;
    } finally {
      _initiating = false;
      safeNotify();
    }
  }

  /// Asks the backend for a hosted checkout URL for a transaction.
  ///
  /// Used when `/pay/initiate` comes back without a redirect link — some
  /// gateways expose the page only through this endpoint. Returns null
  /// and records [payError] when nothing usable comes back.
  Future<String?> checkoutUrl(String transactionId) async {
    try {
      final url = await _repo.webviewUrl(transactionId);
      if (url == null || url.isEmpty) return null;
      return url;
    } on ApiException catch (e) {
      _payError = e.message;
      safeNotify();
      return null;
    }
  }

  /// Confirms a payment after the student returns from the gateway.
  /// Refreshes both lists on success so the due disappears.
  Future<bool> verify(String transactionId) async {
    _payError = null;
    safeNotify();
    try {
      await _repo.verifyPayment(transactionId);
      await refreshAll();
      return true;
    } on ApiException catch (e) {
      _payError = e.message;
      safeNotify();
      return false;
    }
  }

  /// Fetches a receipt PDF as bytes.
  ///
  /// Returns null on failure and records the reason in [receiptError].
  /// The bytes are held only by the caller — receipts are small (~16 KB)
  /// and re-fetching is cheap, so nothing is cached here.
  Future<BinaryResponse?> downloadReceipt(int transactionId) async {
    _downloadingReceiptId = transactionId;
    _receiptError = null;
    safeNotify();
    try {
      return await _repo.receipt(transactionId);
    } on ApiException catch (e) {
      _receiptError = e.isNotFound
          ? 'No receipt has been generated for this payment yet.'
          : e.message;
      return null;
    } finally {
      _downloadingReceiptId = null;
      safeNotify();
    }
  }

  void reset() {
    _dues = [];
    _duesPage = const Pagination();
    _duesState = LoadState.idle;
    _duesError = null;
    _history = [];
    _historyPage = const Pagination();
    _historyState = LoadState.idle;
    _historyError = null;
    _loadingMoreHistory = false;
    _loadingMoreDues = false;
    _initiating = false;
    _payError = null;
    _lastInitiation = null;
    _downloadingReceiptId = null;
    _receiptError = null;
    safeNotify();
  }
}
