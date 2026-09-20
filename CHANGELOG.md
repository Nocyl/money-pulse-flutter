# Changelog

## 2.1.0 — 2026-09-19

- Ajout de `mp.billing.{plans,customers,subscriptions,usage}` (facturation récurrente : abonnements + usage pour les utilisateurs finaux de votre application).
- **Correctif critique** : `payouts.create()` appelait `POST /payouts`, une route qui attend un corps différent (`destinationDetails`) de celui envoyé (`recipient`) — le destinataire du virement était silencieusement remplacé par des valeurs vides, sans erreur. Utilise désormais `POST /payments/payouts/initiate`, qui lit correctement `recipient`.
- Correctif : `methodCode` du payout était envoyé en `method_code` (non reconnu côté backend pour cette route) — corrigé en `methodCode`.

## 2.0.3 — 2026-07-01

- Harmonisation de version avec les autres SDKs Money-Pulse.


## 2.0.0 — 2026-06-30

- Synchronisation depuis le monorepo Money-Pulse.
- Corrections et mises à jour du client HTTP et des modèles.


## 1.0.0 — 2026-04-23

- Première release publique du SDK Flutter Money-Pulse.
- Client HTTP pour initier des paiements et payouts.
- Modèles typés (Payment, Payout, Customer, ApiException).
- Support multi-passerelles via l'orchestrateur Money-Pulse.
- Compatible Flutter >= 3.10 et Dart >= 3.0.
