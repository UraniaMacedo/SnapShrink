import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'subscription_plans.dart';

class PurchaseService extends ChangeNotifier {
  final InAppPurchase _iap = InAppPurchase.instance;

  static const String _premiumKey = 'usuario_premium';
  static const String _premiumProductIdKey = 'premium_product_id';
  static const String _premiumUntilMsKey = 'premium_until_ms';

  StreamSubscription<List<PurchaseDetails>>? _subscription;

  bool loading = true;
  bool available = false;
  bool purchasing = false;
  bool isPremium = false;

  String? errorMessage;
  List<ProductDetails> products = [];

  bool _disposed = false;

  Future<void> init() async {
    loading = true;
    errorMessage = null;
    _safeNotify();

    await _loadLocalPremiumStatus();

    await _subscription?.cancel();
    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdated,
      onError: (Object error) {
        purchasing = false;
        errorMessage = 'Erro na compra: $error';
        _safeNotify();
      },
    );

    await loadProducts();
  }

  Future<void> loadProducts() async {
    loading = true;
    errorMessage = null;
    _safeNotify();

    try {
      available = await _iap.isAvailable();

      if (!available) {
        loading = false;
        errorMessage = 'A Google Play não está disponível neste dispositivo.';
        _safeNotify();
        return;
      }

      final response = await _iap.queryProductDetails(
        SubscriptionPlans.productIds,
      );

      if (response.error != null) {
        errorMessage = response.error!.message;
      }

      if (response.notFoundIDs.isNotEmpty) {
        errorMessage =
            'Alguns planos não foram encontrados na Google Play: ${response.notFoundIDs.join(', ')}. Confira os IDs no Play Console.';
      }

      products = response.productDetails;

      final order = [
  SubscriptionPlans.monthlyId,
  SubscriptionPlans.annualId,
];
      products.sort((a, b) {
        final indexA = order.indexOf(a.id);
        final indexB = order.indexOf(b.id);

        return (indexA == -1 ? 999 : indexA)
            .compareTo(indexB == -1 ? 999 : indexB);
      });

      if (products.isEmpty && errorMessage == null) {
        errorMessage =
            'Nenhum plano encontrado. Confira se as assinaturas foram criadas e ativadas na Play Console com os IDs corretos.';
      }
    } catch (e) {
      errorMessage = 'Erro ao carregar planos: $e';
    }

    loading = false;
    _safeNotify();
  }

  Future<void> buy(ProductDetails product) async {
    if (purchasing) return;

    if (!SubscriptionPlans.productIds.contains(product.id)) {
      errorMessage = 'Plano inválido.';
      _safeNotify();
      return;
    }

    purchasing = true;
    errorMessage = null;
    _safeNotify();

    final purchaseParam = PurchaseParam(productDetails: product);

    try {
      final started = await _iap.buyNonConsumable(
        purchaseParam: purchaseParam,
      );

      if (!started) {
        purchasing = false;
        errorMessage = 'Não foi possível abrir a compra na Google Play.';
        _safeNotify();
      }
    } catch (e) {
      purchasing = false;
      errorMessage = 'Não foi possível iniciar a compra: $e';
      _safeNotify();
    }
  }

  Future<void> restorePurchases() async {
    if (purchasing) return;

    purchasing = true;
    errorMessage = null;
    _safeNotify();

    try {
      await _iap.restorePurchases();

      Future.delayed(const Duration(seconds: 5), () {
        if (_disposed) return;

        if (purchasing && !isPremium) {
          purchasing = false;
          errorMessage =
              'Se você já tem uma assinatura ativa, confira se está usando a mesma conta da Google Play e tente restaurar novamente.';
          _safeNotify();
        }
      });
    } catch (e) {
      purchasing = false;
      errorMessage = 'Não foi possível restaurar compras: $e';
      _safeNotify();
    }
  }

  Future<void> _onPurchaseUpdated(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    for (final purchase in purchaseDetailsList) {
      if (purchase.status == PurchaseStatus.pending) {
        purchasing = true;
        errorMessage = null;
        _safeNotify();
        continue;
      }

      if (purchase.status == PurchaseStatus.error) {
        purchasing = false;
        errorMessage = purchase.error?.message ?? 'Erro ao processar compra.';

        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }

        _safeNotify();
        continue;
      }

      if (purchase.status == PurchaseStatus.canceled) {
        purchasing = false;
        errorMessage = 'Compra cancelada.';

        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }

        _safeNotify();
        continue;
      }

      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        final validProduct =
            SubscriptionPlans.productIds.contains(purchase.productID);

        if (validProduct) {
          await _setPremiumFromPurchase(purchase.productID);
          errorMessage = null;
        } else {
          errorMessage = 'Produto não reconhecido: ${purchase.productID}';
        }

        purchasing = false;

        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }

        _safeNotify();
        continue;
      }

      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }

    purchasing = false;
    _safeNotify();
  }

  Future<void> _loadLocalPremiumStatus() async {
    final prefs = await SharedPreferences.getInstance();

    final premiumUntilMs = prefs.getInt(_premiumUntilMsKey);

    if (premiumUntilMs == null) {
      isPremium = false;
      await prefs.setBool(_premiumKey, false);
      return;
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final active = premiumUntilMs > nowMs;

    isPremium = active;
    await prefs.setBool(_premiumKey, active);

    if (!active) {
      await prefs.remove(_premiumProductIdKey);
      await prefs.remove(_premiumUntilMsKey);
    }
  }

  Future<void> _setPremiumFromPurchase(String productId) async {
    final prefs = await SharedPreferences.getInstance();

    final premiumUntil = DateTime.now().add(
      SubscriptionPlans.localEntitlementDurationFor(productId),
    );

    await prefs.setBool(_premiumKey, true);
    await prefs.setString(_premiumProductIdKey, productId);
    await prefs.setInt(
      _premiumUntilMsKey,
      premiumUntil.millisecondsSinceEpoch,
    );

    isPremium = true;
  }

  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}