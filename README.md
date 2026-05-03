# Money-Pulse Flutter SDK

SDK officiel Flutter / Dart pour [Money-Pulse](https://money-pulse.org). Compatible iOS, Android, Web.

## Installation

```yaml
dependencies:
  moneypulse: ^1.0.0
  flutter_inappwebview: ^6.0.0   # pour ouvrir le checkout hosted
  uni_links: ^0.5.1              # pour capturer le callback deep link
```

```bash
flutter pub get
```

## Quick Start

```dart
import 'package:moneypulse/moneypulse.dart';

final client = MoneyPulseClient(
  apiKey: 'mp_live_votre_cle_api',
  environment: MoneyPulseEnvironment.live,
);

final payment = await client.payments.create(
  amount: 10000,
  currency: 'XOF',
  country: 'CI',
  customer: Customer(email: 'client@email.com', phone: '+22507000000'),
  callbackUrl: 'https://votre-backend.com/webhook',
  returnUrl:   'moneypulse://callback',
);

print('Checkout URL: ${payment.checkoutUrl}');
```

## Payouts

```dart
final payout = await client.payouts.create(
  amount: 50000,
  currency: 'XOF',
  country: 'CI',
  recipient: PayoutRecipient(
    type: 'mobile_money',
    phone: '+22507000000',
    name: 'Jean Kouassi',
  ),
);
```

## Mode Simulation

Testez sans débiter de fonds réels.

```dart
final test = await client.payments.create(
  amount: 5000,
  currency: 'XOF',
  country: 'CI',
  customer: Customer(phone: '+22507000000'),
  simulate: true, // ← active la simulation
);
```

| Dernier chiffre | Résultat |
|---|---|
| `00`–`49` | ✅ completed |
| `50`–`89` | ⏳ pending → success |
| `90`–`99` | ❌ failed |

## Exemple complet — Checkout dans une WebView avec deep link callback

### 1. Configurer le deep link

**Android** (`android/app/src/main/AndroidManifest.xml`)

```xml
<activity android:name=".MainActivity" android:launchMode="singleTask">
    <intent-filter android:autoVerify="true">
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="moneypulse" android:host="callback" />
    </intent-filter>
</activity>
```

**iOS** (`ios/Runner/Info.plist`)

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array><string>moneypulse</string></array>
  </dict>
</array>
```

### 2. Écran de paiement

```dart
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:moneypulse/moneypulse.dart';
import 'package:uni_links/uni_links.dart';

class CheckoutScreen extends StatefulWidget {
  final double amount;
  final String currency;
  final String orderId;
  const CheckoutScreen({
    super.key,
    required this.amount,
    required this.currency,
    required this.orderId,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String? checkoutUrl;
  StreamSubscription? _linkSub;

  @override
  void initState() {
    super.initState();
    _initCheckout();
    _listenDeepLinks();
  }

  Future<void> _initCheckout() async {
    final client = MoneyPulseClient(apiKey: const String.fromEnvironment('MP_API_KEY'));
    final payment = await client.payments.create(
      amount: widget.amount,
      currency: widget.currency,
      country: 'CI',
      customer: Customer(email: 'client@email.com'),
      returnUrl: 'moneypulse://callback?order=${widget.orderId}',
      callbackUrl: 'https://votre-backend.com/webhook',
      metadata: {'order_id': widget.orderId},
    );
    setState(() => checkoutUrl = payment.checkoutUrl);
  }

  void _listenDeepLinks() {
    _linkSub = uriLinkStream.listen((Uri? uri) {
      if (uri?.scheme == 'moneypulse' && uri?.host == 'callback') {
        final status = uri!.queryParameters['status'] ?? 'unknown';
        Navigator.of(context).pop({'status': status, 'order': uri.queryParameters['order']});
      }
    });
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (checkoutUrl == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Paiement')),
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(checkoutUrl!)),
        shouldOverrideUrlLoading: (controller, action) async {
          final uri = action.request.url;
          if (uri?.scheme == 'moneypulse') {
            final status = uri!.queryParameters['status'] ?? 'unknown';
            Navigator.of(context).pop({'status': status});
            return NavigationActionPolicy.CANCEL;
          }
          return NavigationActionPolicy.ALLOW;
        },
      ),
    );
  }
}
```

### 3. Lancer le paiement et récupérer le résultat

```dart
final result = await Navigator.push<Map>(
  context,
  MaterialPageRoute(builder: (_) => CheckoutScreen(
    amount: 25000, currency: 'XOF', orderId: 'CMD-12345',
  )),
);

if (result?['status'] == 'success') {
  showDialog(context: context, builder: (_) => const SuccessDialog());
} else if (result?['status'] == 'failed') {
  showDialog(context: context, builder: (_) => const FailedDialog());
}
```

## Webhooks (côté backend)

Le callback `returnUrl` est utile pour l'UX, mais la **source de vérité** reste le webhook
serveur-à-serveur. Configurez `callbackUrl` vers votre backend (Node, Laravel, Django…) et
**vérifiez la signature** avant de marquer la commande comme payée :

```dart
// Côté Flutter, vous n'avez pas besoin de vérifier la signature.
// Voir les SDK PHP / Python / JS pour le code backend.
```

Ne jamais marquer une commande comme payée uniquement sur la base du `returnUrl` —
le client peut intercepter ou modifier l'URL.

## Erreurs courantes

```dart
try {
  final payment = await client.payments.create(...);
} on MoneyPulseException catch (e) {
  print(e.message);    // description lisible
  print(e.code);       // ex: 'invalid_amount'
  print(e.httpStatus); // 400, 401, 422...
}
```

| Code | Cause | Action |
|---|---|---|
| `invalid_api_key` | Clé absente / révoquée | Régénérer dans le dashboard |
| `network_error` | Pas d'internet ou timeout | Retry avec backoff |
| `webview_blocked` | URL bloquée par le système | Whitelister `*.money-pulse.org` |
| `deep_link_missing` | Schema custom non déclaré | Vérifier Info.plist / AndroidManifest |

## Liens

- Docs complètes : <https://money-pulse.org/documentation>
- pub.dev : <https://pub.dev/packages/moneypulse>
- Support : <support@money-pulse.org>

## License

MIT © NOCYL-PULSE
