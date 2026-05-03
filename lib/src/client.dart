import 'dart:convert';
import 'package:http/http.dart' as http;
import 'exceptions.dart';
import 'models.dart';

/// Main Money-Pulse SDK client for Flutter/Dart.
///
/// ```dart
/// final mp = MoneyPulse(apiKey: 'mp_live_votre_cle_api');
///
/// // Create a payment
/// final payment = await mp.payments.create(
///   amount: 5000,
///   currency: 'XOF',
///   customer: Customer(email: 'user@example.com'),
///   returnUrl: 'https://myapp.com/callback',
/// );
///
/// // Verify a payment
/// final verified = await mp.payments.verify(payment.id);
/// ```
class MoneyPulse {
  final String apiKey;
  final String baseUrl;
  final http.Client _httpClient;

  late final PaymentResource payments;
  late final PayoutResource payouts;

  MoneyPulse({
    required this.apiKey,
    this.baseUrl = 'https://api.money-pulse.org/api/v1',
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client() {
    payments = PaymentResource(this);
    payouts = PayoutResource(this);
  }

  /// Sends an authenticated request to the Money-Pulse API.
  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: queryParams);
    final headers = {
      'X-Api-Key': apiKey,
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-SDK': 'flutter/1.0.0',
    };

    late http.Response response;

    switch (method.toUpperCase()) {
      case 'GET':
        response = await _httpClient.get(uri, headers: headers);
        break;
      case 'POST':
        response = await _httpClient.post(uri, headers: headers, body: jsonEncode(body));
        break;
      case 'PUT':
        response = await _httpClient.put(uri, headers: headers, body: jsonEncode(body));
        break;
      case 'DELETE':
        response = await _httpClient.delete(uri, headers: headers);
        break;
      default:
        throw MoneyPulseException('Unsupported HTTP method: $method');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 401) {
      throw MoneyPulseAuthException(data['error'] ?? 'Unauthorized');
    }
    if (response.statusCode == 404) {
      throw MoneyPulseNotFoundException(data['error'] ?? 'Not found');
    }
    if (response.statusCode >= 400) {
      throw MoneyPulseException(
        data['error'] ?? 'Request failed',
        statusCode: response.statusCode,
        details: data,
      );
    }

    return data;
  }

  /// Closes the HTTP client.
  void close() => _httpClient.close();
}

/// Manages payment operations.
class PaymentResource {
  final MoneyPulse _client;
  PaymentResource(this._client);

  /// Initializes a new payment.
  Future<PaymentTransaction> create({
    required double amount,
    required String currency,
    required Customer customer,
    required String returnUrl,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    final data = await _client.request('POST', '/payments/initiate', body: {
      'amount': amount,
      'currency': currency,
      'customer': customer.toJson(),
      'return_url': returnUrl,
      if (description != null) 'description': description,
      if (metadata != null) 'metadata': metadata,
    });
    return PaymentTransaction.fromJson(data['data']);
  }

  /// Verifies a payment by its ID.
  Future<PaymentTransaction> verify(String paymentId) async {
    final data = await _client.request('GET', '/payments/$paymentId/verify');
    return PaymentTransaction.fromJson(data['data']);
  }

  /// Retrieves a payment by its ID.
  Future<PaymentTransaction> retrieve(String paymentId) async {
    final data = await _client.request('GET', '/payments/$paymentId');
    return PaymentTransaction.fromJson(data['data']);
  }
}

/// Manages payout operations.
class PayoutResource {
  final MoneyPulse _client;
  PayoutResource(this._client);

  /// Initializes a new payout.
  Future<PayoutTransaction> create({
    required double amount,
    required String currency,
    required Recipient recipient,
    required String method,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    final data = await _client.request('POST', '/payouts/initiate', body: {
      'amount': amount,
      'currency': currency,
      'recipient': recipient.toJson(),
      'method': method,
      if (description != null) 'description': description,
      if (metadata != null) 'metadata': metadata,
    });
    return PayoutTransaction.fromJson(data['data']);
  }

  /// Verifies a payout by its ID.
  Future<PayoutTransaction> verify(String payoutId) async {
    final data = await _client.request('GET', '/payouts/$payoutId/verify');
    return PayoutTransaction.fromJson(data['data']);
  }
}
