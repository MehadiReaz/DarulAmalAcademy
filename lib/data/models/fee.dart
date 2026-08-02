import '../../core/utils/json_utils.dart';

/// A fee transaction, as returned by `GET /student/fees/dues` and
/// `GET /student/fees/history` (both raw Laravel paginators).
///
/// Note that `amount` arrives as a **string** ("638.00") and `currency`
/// varies per row in the current data ("GBP", "EUR"), so neither can be
/// assumed. The server also pre-formats dates into `date_time` and
/// `due_date_format`, which are preferred for display over re-parsing.
class FeeTransaction {
  final int id;
  final String? transactionNo;
  final String title;
  final int? invoiceId;
  final double amount;
  final double? paidAmount;
  final String currency;
  final String? description;

  /// 'paid' | 'unpaid' | 'partial' — server-side lifecycle.
  final String status;
  final String? method;
  final String? documentUrl;

  /// Pre-formatted by the server: "Dec 17, 2026".
  final String? dateLabel;

  /// Pre-formatted by the server: "Jul 27, 2026".
  final String? dueDateLabel;

  final String? rawDate;
  final String? rawDueDate;
  final String? typeName;

  const FeeTransaction({
    required this.id,
    this.transactionNo,
    this.title = '',
    this.invoiceId,
    this.amount = 0,
    this.paidAmount,
    this.currency = '',
    this.description,
    this.status = 'unpaid',
    this.method,
    this.documentUrl,
    this.dateLabel,
    this.dueDateLabel,
    this.rawDate,
    this.rawDueDate,
    this.typeName,
  });

  factory FeeTransaction.fromJson(Map<String, dynamic> json) {
    final type = asMap(json['type']);
    return FeeTransaction(
      id: asInt(json['id']),
      transactionNo: asStringOrNull(json['transaction_no']),
      title: asString(json['title'], fallback: 'Fee'),
      invoiceId: asIntOrNull(json['invoice_id']),
      amount: asDouble(json['amount']),
      paidAmount: json['paid_amount'] == null
          ? null
          : asDouble(json['paid_amount']),
      currency: asString(json['currency']),
      description: asStringOrNull(json['description']),
      status: asString(json['status'], fallback: 'unpaid'),
      method: asStringOrNull(json['method']),
      documentUrl: asStringOrNull(json['document']),
      dateLabel: asStringOrNull(json['date_time']),
      dueDateLabel: asStringOrNull(json['due_date_format']),
      rawDate: asStringOrNull(json['date']),
      rawDueDate: asStringOrNull(json['due_date']),
      typeName: type == null ? null : asStringOrNull(type['name']),
    );
  }

  bool get isPaid => status.toLowerCase() == 'paid';
  bool get isUnpaid => !isPaid;

  double get outstanding {
    final paid = paidAmount ?? 0;
    final left = amount - paid;
    return left < 0 ? 0 : left;
  }

  DateTime? get dueAt => asDate(rawDueDate);

  /// Negative when past due. Null when the server sent no due date.
  int? get daysUntilDue {
    final due = dueAt;
    if (due == null) return null;
    final now = DateTime.now();
    return DateTime(due.year, due.month, due.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
  }

  bool get isOverdue {
    if (isPaid) return false;
    final d = daysUntilDue;
    return d != null && d < 0;
  }

  String get statusLabel {
    switch (status.toLowerCase()) {
      case 'paid':
        return 'Paid';
      case 'partial':
        return 'Partially paid';
      default:
        return isOverdue ? 'Overdue' : 'Unpaid';
    }
  }

  /// "GBP 638.00". The currency is whatever the row carries — the API
  /// mixes them, so a hardcoded symbol would be wrong.
  String get amountLabel {
    final value = amount.toStringAsFixed(2);
    return currency.isEmpty ? value : '$currency $value';
  }
}

/// Response from `POST /student/fees/pay/initiate  { invoiceId }`.
///
/// The exact success payload could not be captured — the endpoint 422'd
/// on every invoice ID available during the test run. Every field is
/// therefore optional and read from several plausible key spellings, and
/// [raw] keeps the original body so nothing is lost if the shape differs.
class PaymentInitiation {
  final String? transactionId;
  final String? transactionNo;
  final String? paymentUrl;
  final String? gateway;
  final double? amount;
  final String? currency;
  final String? razorpayKey;
  final int? razorAmount;
  final Map<String, dynamic> raw;

  const PaymentInitiation({
    this.transactionId,
    this.transactionNo,
    this.paymentUrl,
    this.gateway,
    this.amount,
    this.currency,
    this.razorpayKey,
    this.razorAmount,
    this.raw = const {},
  });

  factory PaymentInitiation.fromJson(Map<String, dynamic> json) {
    // Gateways in this codebase (PayPal / Stripe / Razorpay / Flutterwave
    // / Midtrans) each name the redirect differently.
    final url = asStringOrNull(json['payment_url']) ??
        asStringOrNull(json['redirect_url']) ??
        asStringOrNull(json['url']) ??
        asStringOrNull(json['link']) ??
        asStringOrNull(json['checkout_url']);

    int? rAmount;
    if (json['razor_amount'] != null) {
      rAmount = asInt(json['razor_amount']);
    } else if (json['razorpay_amount'] != null) {
      rAmount = asInt(json['razorpay_amount']);
    }

    return PaymentInitiation(
      transactionId: asStringOrNull(json['transaction_id']) ??
          asStringOrNull(json['transactionId']) ??
          asStringOrNull(json['id']),
      transactionNo: asStringOrNull(json['transaction_no']),
      paymentUrl: url,
      gateway: asStringOrNull(json['gateway']) ??
          asStringOrNull(json['payment_method']),
      amount: json['amount'] == null ? null : asDouble(json['amount']),
      currency: asStringOrNull(json['currency']),
      razorpayKey: asStringOrNull(json['razorpay_key']) ??
          asStringOrNull(json['razor_key']) ??
          asStringOrNull(json['key']),
      razorAmount: rAmount,
      raw: json,
    );
  }

  bool get hasRedirect => paymentUrl != null && paymentUrl!.isNotEmpty;

  bool get isRazorpayNative =>
      razorpayKey != null && razorpayKey!.isNotEmpty;
}
