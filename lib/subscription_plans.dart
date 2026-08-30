class SubscriptionPlanConfig {
  final String id;
  final String title;
  final String description;
  final String fallbackPrice;
  final String periodLabel;
  final bool highlighted;
  final int localEntitlementDays;

  const SubscriptionPlanConfig({
    required this.id,
    required this.title,
    required this.description,
    required this.fallbackPrice,
    required this.periodLabel,
    required this.localEntitlementDays,
    this.highlighted = false,
  });
}

class SubscriptionPlans {
  // IDs exatamente iguais aos cadastrados no Google Play Console.
  static const String monthlyId = 'snapshrink_premium_mensal';
  static const String annualId = 'snapshrink_premium_anual';

  static const List<SubscriptionPlanConfig> plans = [
    SubscriptionPlanConfig(
      id: monthlyId,
      title: 'Premium Mensal',
      description: 'Use o SnapShrink sem anúncios e sem interrupções.',
      fallbackPrice: '',
      periodLabel: 'por mês',
      localEntitlementDays: 32,
      highlighted: false,
    ),
    SubscriptionPlanConfig(
      id: annualId,
      title: 'Premium Anual',
      description: 'Aproveite o SnapShrink Premium durante todo o ano.',
      fallbackPrice: '',
      periodLabel: 'por ano',
      localEntitlementDays: 370,
      highlighted: true,
    ),
  ];

  static Set<String> get productIds => {
        monthlyId,
        annualId,
      };

  static SubscriptionPlanConfig byId(String id) {
    return plans.firstWhere(
      (plan) => plan.id == id,
      orElse: () => SubscriptionPlanConfig(
        id: id,
        title: 'SnapShrink Premium',
        description: 'Use o app sem anúncios.',
        fallbackPrice: '',
        periodLabel: '',
        localEntitlementDays: 32,
      ),
    );
  }

  static Duration localEntitlementDurationFor(String id) {
    return Duration(days: byId(id).localEntitlementDays);
  }
}
