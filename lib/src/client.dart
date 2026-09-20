import 'dart:convert';
import 'package:http/http.dart' as http;
import 'exceptions.dart';
import 'models.dart';

/// Main Money-Pulse SDK client for Flutter/Dart.
///
/// ```dart
/// final mp = MoneyPulse(apiKey: 'mp_live_votre_cle_api');
///
/// final payment = await mp.payments.create(
///   amount: 5000,
///   currency: 'XOF',
///   country: 'CI',
///   customer: Customer(email: 'user@example.com'),
///   returnUrl: 'https://myapp.com/callback',
/// );
///
/// final status = await mp.payments.getStatus(payment.id);
/// ```
class MoneyPulse {
  final String apiKey;
  final String baseUrl;
  final http.Client _httpClient;

  late final PaymentResource payments;
  late final PayoutResource payouts;
  late final BillingResource billing;

  MoneyPulse({
    required this.apiKey,
    this.baseUrl = 'https://api.money-pulse.org/api/v1',
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client() {
    payments = PaymentResource(this);
    payouts = PayoutResource(this);
    billing = BillingResource(this);
  }

  /// Sends an authenticated request to the Money-Pulse API.
  ///
  /// [idempotencyKey], si fourni, est transmis dans le header
  /// `Idempotency-Key` : une nouvelle tentative avec la même clé ne créera
  /// pas d'opération en double côté serveur.
  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
    String? idempotencyKey,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: queryParams);
    final headers = {
      'X-Api-Key': apiKey,
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-SDK': 'flutter/2.1.0',
      if (idempotencyKey != null) 'Idempotency-Key': idempotencyKey,
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

  /// Initializes a new payment. Une clé d'idempotence est générée
  /// automatiquement si [idempotencyKey] n'est pas fourni.
  Future<PaymentTransaction> create({
    required double amount,
    required String currency,
    required String country,
    required Customer customer,
    String? callbackUrl,
    String? returnUrl,
    String? description,
    Map<String, dynamic>? metadata,
    String? idempotencyKey,
  }) async {
    final data = await _client.request(
      'POST',
      '/payments/initiate',
      body: {
        'amount': amount,
        'currency': currency,
        'country': country,
        'customer': customer.toJson(),
        if (callbackUrl != null) 'callback_url': callbackUrl,
        if (returnUrl != null) 'return_url': returnUrl,
        if (description != null) 'description': description,
        if (metadata != null) 'metadata': metadata,
      },
      idempotencyKey: idempotencyKey,
    );
    return PaymentTransaction.fromJson(data['data']);
  }

  /// Récupère le statut d'un paiement.
  Future<PaymentTransaction> getStatus(String transactionId) async {
    final data = await _client.request('GET', '/payments/$transactionId/status');
    return PaymentTransaction.fromJson(data['data']);
  }
}

/// Manages payout operations.
class PayoutResource {
  final MoneyPulse _client;
  PayoutResource(this._client);

  /// Initializes a new payout. Une clé d'idempotence est générée
  /// automatiquement si [idempotencyKey] n'est pas fourni.
  ///
  /// FIX ALIGNEMENT (vérification approfondie) : POST /payouts
  /// (PayoutController.createPayout côté backend) lit destinationDetails,
  /// jamais recipient -- envoyer recipient comme le fait cette méthode
  /// était silencieusement ignoré (destinataire remplacé par des valeurs
  /// vides/"N/A", aucune erreur renvoyée). La route qui lit bien
  /// `recipient` est /payments/payouts/initiate.
  Future<PayoutTransaction> create({
    required double amount,
    required String currency,
    required String country,
    required Recipient recipient,
    String? methodCode,
    String? description,
    Map<String, dynamic>? metadata,
    String? idempotencyKey,
  }) async {
    final data = await _client.request(
      'POST',
      '/payments/payouts/initiate',
      body: {
        'amount': amount,
        'currency': currency,
        'country': country,
        'recipient': recipient.toJson(),
        if (methodCode != null) 'methodCode': methodCode,
        if (description != null) 'description': description,
        if (metadata != null) 'metadata': metadata,
      },
      idempotencyKey: idempotencyKey,
    );
    return PayoutTransaction.fromJson(data['data']);
  }
}

/// Facturation récurrente : abonnements + usage pour les utilisateurs
/// finaux de votre propre application (ex. les vendeurs qui utilisent
/// votre plateforme) -- pas pour Money-Pulse lui-même.
class BillingResource {
  final MoneyPulse _client;
  BillingResource(this._client) {
    plans = _BillingPlansResource(_client);
    customers = _BillingCustomersResource(_client);
    subscriptions = _BillingSubscriptionsResource(_client);
    usage = _BillingUsageResource(_client);
  }

  late final _BillingPlansResource plans;
  late final _BillingCustomersResource customers;
  late final _BillingSubscriptionsResource subscriptions;
  late final _BillingUsageResource usage;
}

class _BillingPlansResource {
  final MoneyPulse _client;
  _BillingPlansResource(this._client);

  Future<Map<String, dynamic>> create({
    required String code,
    required String name,
    String? description,
    required double priceAmount,
    required String priceCurrency,
    required String billingInterval, // 'monthly' | 'yearly'
    int? trialDays,
    double? usageFeePercent,
  }) async {
    final data = await _client.request('POST', '/billing/plans', body: {
      'code': code,
      'name': name,
      if (description != null) 'description': description,
      'priceAmount': priceAmount,
      'priceCurrency': priceCurrency,
      'billingInterval': billingInterval,
      if (trialDays != null) 'trialDays': trialDays,
      if (usageFeePercent != null) 'usageFeePercent': usageFeePercent,
    });
    return data['data'] as Map<String, dynamic>;
  }

  Future<List<dynamic>> list({bool includeInactive = false}) async {
    final data = await _client.request('GET', '/billing/plans', queryParams: {
      if (includeInactive) 'includeInactive': 'true',
    });
    return data['data'] as List<dynamic>;
  }

  Future<void> deactivate(String id) async {
    await _client.request('DELETE', '/billing/plans/$id');
  }
}

class _BillingCustomersResource {
  final MoneyPulse _client;
  _BillingCustomersResource(this._client);

  Future<Map<String, dynamic>> upsert({
    required String externalCustomerId,
    String? email,
    String? phone,
    String? name,
    required String country,
  }) async {
    final data = await _client.request('POST', '/billing/customers', body: {
      'externalCustomerId': externalCustomerId,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (name != null) 'name': name,
      'country': country,
    });
    return data['data'] as Map<String, dynamic>;
  }
}

class _BillingSubscriptionsResource {
  final MoneyPulse _client;
  _BillingSubscriptionsResource(this._client);

  /// Retourne { subscription, invoice, checkoutUrl } -- checkoutUrl est le
  /// lien de paiement hébergé à présenter à l'utilisateur final (aucun
  /// débit automatique n'existe côté Money-Pulse).
  Future<Map<String, dynamic>> create({
    required String billingCustomerId,
    required String planCode,
  }) async {
    final data = await _client.request('POST', '/billing/subscriptions', body: {
      'billingCustomerId': billingCustomerId,
      'planCode': planCode,
    });
    return data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> cancel(
    String id, {
    bool atPeriodEnd = true,
    String? reason,
  }) async {
    final data = await _client.request('POST', '/billing/subscriptions/$id/cancel', body: {
      'atPeriodEnd': atPeriodEnd,
      if (reason != null) 'reason': reason,
    });
    return data['data'] as Map<String, dynamic>;
  }
}

class _BillingUsageResource {
  final MoneyPulse _client;
  _BillingUsageResource(this._client);

  /// Enregistre un relevé d'usage (ex. commission sur une vente), agrégé à
  /// la prochaine facture de l'abonnement concerné.
  Future<Map<String, dynamic>> record({
    required String billingCustomerId,
    String? subscriptionId,
    required double quantity,
    required double unitAmount,
    required String currency,
    String? description,
  }) async {
    final data = await _client.request('POST', '/billing/usage', body: {
      'billingCustomerId': billingCustomerId,
      if (subscriptionId != null) 'subscriptionId': subscriptionId,
      'quantity': quantity,
      'unitAmount': unitAmount,
      'currency': currency,
      if (description != null) 'description': description,
    });
    return data['data'] as Map<String, dynamic>;
  }
}
