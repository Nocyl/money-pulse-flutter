/// Represents a Money-Pulse API response.
class ApiResponse<T> {
  final bool success;
  final String? message;
  final T? data;

  ApiResponse({required this.success, this.message, this.data});

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>)? fromData,
  ) {
    return ApiResponse(
      success: json['success'] ?? false,
      message: json['message'],
      data: json['data'] != null && fromData != null
          ? fromData(json['data'])
          : json['data'],
    );
  }
}

/// Represents a payment transaction.
class PaymentTransaction {
  final String id;
  final String status;
  final double amount;
  final String currency;
  final String? checkoutUrl;
  final String? reference;
  final Map<String, dynamic>? metadata;

  PaymentTransaction({
    required this.id,
    required this.status,
    required this.amount,
    required this.currency,
    this.checkoutUrl,
    this.reference,
    this.metadata,
  });

  factory PaymentTransaction.fromJson(Map<String, dynamic> json) {
    return PaymentTransaction(
      id: json['id'] ?? '',
      status: json['status'] ?? 'pending',
      amount: (json['amount'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'XOF',
      checkoutUrl: json['checkout_url'],
      reference: json['reference'],
      metadata: json['metadata'],
    );
  }
}

/// Represents a payout transaction.
class PayoutTransaction {
  final String id;
  final String status;
  final double amount;
  final String currency;
  final String? reference;
  final String? failureReason;

  PayoutTransaction({
    required this.id,
    required this.status,
    required this.amount,
    required this.currency,
    this.reference,
    this.failureReason,
  });

  factory PayoutTransaction.fromJson(Map<String, dynamic> json) {
    return PayoutTransaction(
      id: json['id'] ?? '',
      status: json['status'] ?? 'pending',
      amount: (json['amount'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'XOF',
      reference: json['reference'],
      failureReason: json['failure_reason'],
    );
  }
}

/// Customer information for a payment.
class Customer {
  final String email;
  final String? firstName;
  final String? lastName;
  final String? phone;

  Customer({
    required this.email,
    this.firstName,
    this.lastName,
    this.phone,
  });

  Map<String, dynamic> toJson() => {
        'email': email,
        if (firstName != null) 'first_name': firstName,
        if (lastName != null) 'last_name': lastName,
        if (phone != null) 'phone': phone,
      };
}

/// Recipient information for a payout.
class Recipient {
  final String phone;
  final String? name;
  final String? email;
  final String country;

  Recipient({
    required this.phone,
    required this.country,
    this.name,
    this.email,
  });

  Map<String, dynamic> toJson() => {
        'phone': phone,
        'country': country,
        if (name != null) 'name': name,
        if (email != null) 'email': email,
      };
}
