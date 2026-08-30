import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'purchase_service.dart';
import 'subscription_plans.dart';

class PremiumPage extends StatefulWidget {
  const PremiumPage({super.key});

  @override
  State<PremiumPage> createState() => _PremiumPageState();
}

class _PremiumPageState extends State<PremiumPage> {
  late final PurchaseService purchaseService;

  @override
  void initState() {
    super.initState();

    purchaseService = PurchaseService();
    purchaseService.addListener(_atualizarTela);
    purchaseService.init();
  }

  void _atualizarTela() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    purchaseService.removeListener(_atualizarTela);
    purchaseService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = purchaseService.isPremium;
    

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('SnapShrink Premium'),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.deepPurple,
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(
                Icons.diamond,
                size: 72,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isPremium ? 'Premium ativo' : 'Experiência Premium',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              isPremium
                  ? 'Sua assinatura Premium está ativa.'
                  : 'Remova anúncios e use o SnapShrink com mais conforto.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 28),
            const _PremiumBenefit(
              icon: Icons.block,
              title: 'Remover anúncios',
              description:
                  'Sem banners no rodapé e sem anúncios de tela cheia.',
            ),
            const SizedBox(height: 14),
            const _PremiumBenefit(
              icon: Icons.flash_on,
              title: 'Compressão sem interrupções',
              description: 'Reduza imagens e vídeos com mais fluidez.',
            ),
            const SizedBox(height: 14),
            const _PremiumBenefit(
              icon: Icons.workspace_premium,
              title: 'Melhorias Premium',
              description:
                  'O Premium mantém a experiência sem anúncios e poderá receber melhorias.',
            ),
            const SizedBox(height: 28),
            if (purchaseService.loading)
              const Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              )
            else if (isPremium)
              _PremiumActiveCard(
                onClose: () => Navigator.pop(context, true),
              )
            else ...[
              if (purchaseService.errorMessage != null) ...[
                Card(
                  color: Colors.orange.shade50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      purchaseService.errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black87),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              ...purchaseService.products.map((product) {
                return _PlanCard(
                  product: product,
                  purchasing: purchaseService.purchasing,
                  onBuy: () => purchaseService.buy(product),
                );
              }),
              if (purchaseService.products.isEmpty &&
                  purchaseService.errorMessage == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Text(
                    'Nenhum plano disponível no momento.',
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: purchaseService.purchasing
                      ? null
                      : purchaseService.restorePurchases,
                  icon: const Icon(Icons.restore),
                  label: const Text('Restaurar compra'),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'A assinatura é processada pela Google Play. Você pode cancelar ou gerenciar sua assinatura na sua conta da Play Store.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final ProductDetails product;
  final bool purchasing;
  final VoidCallback onBuy;

  const _PlanCard({
    required this.product,
    required this.purchasing,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    final config = SubscriptionPlans.byId(product.id);

    return Card(
      elevation: config.highlighted ? 4 : 1,
      color: config.highlighted ? Colors.deepPurple.shade50 : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: config.highlighted ? Colors.deepPurple : Colors.grey.shade300,
          width: config.highlighted ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            if (config.highlighted) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.deepPurple,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Melhor opção',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              config.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              config.description,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 14),
            Text(
              product.price,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Colors.deepPurple,
              ),
            ),
            if (config.periodLabel.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                config.periodLabel,
                style: const TextStyle(color: Colors.black54),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: purchasing ? null : onBuy,
                icon: purchasing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.shopping_cart),
                label: Text(purchasing ? 'Processando...' : 'Assinar agora'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumActiveCard extends StatelessWidget {
  final VoidCallback onClose;

  const _PremiumActiveCard({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.green.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Premium liberado',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Os anúncios serão removidos ao voltar para a tela principal.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: onClose,
                child: const Text('Voltar para o app'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumBenefit extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _PremiumBenefit({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.deepPurple, size: 32),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(description),
      ),
    );
  }
}