class MembershipLevel {
  final int id;
  final String name;
  final String description;
  final String initialPayment;
  final String billingAmount;
  final String billingPeriod;
  final int billingLimit;
  final bool isActive;
  final bool allowsSignup;

  const MembershipLevel({
    required this.id,
    required this.name,
    required this.description,
    required this.initialPayment,
    required this.billingAmount,
    required this.billingPeriod,
    required this.billingLimit,
    required this.isActive,
    this.allowsSignup = true,
  });

  factory MembershipLevel.fromJson(Map<String, dynamic> json) {
    final period = (json['billing_period'] ?? json['cycle_period'] ?? '')
        .toString()
        .trim();
    final signups = json['allow_signups'];
    return MembershipLevel(
      id: _toInt(json['id'] ?? json['ID']),
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      initialPayment: json['initial_payment']?.toString() ?? '0',
      billingAmount: json['billing_amount']?.toString() ?? '0',
      billingPeriod: period,
      billingLimit: _toInt(json['billing_limit']),
      isActive: (json['status']?.toString() ?? '') == 'active' ||
          json['id'] != null,
      allowsSignup: signups == null ||
          signups == true ||
          signups.toString() == '1',
    );
  }

  bool get isFree =>
      (double.tryParse(initialPayment) ?? 0) == 0 &&
      (double.tryParse(billingAmount) ?? 0) == 0;

  /// Site copy when PMPro sends an empty description.
  String get summary {
    final text = description.trim();
    if (text.isNotEmpty) return text;
    if (isFree) return 'Browse the catalog with a free account.';
    return 'Full access to members-only videos and classic horror movies.';
  }

  /// Benefits shown on the Premium card.
  List<String> get includes => isFree ? const [] : premiumIncludes;

  static const premiumIncludes = <String>[
    'Full access to all members-only videos',
    'All classic horror movies',
    'Truth • Lies • Betrayal — AI-spoken character series',
    'Horror After Dark Network original stories',
    'A new 60-minute triple-story horror video every month',
    'Live chat with Sarah — host of Horror After Dark Network — once a month',
    'Automatic entry into all giveaways',
    'Exclusive discounts on all merchandise',
  ];

  String get priceLabel {
    final initial = double.tryParse(initialPayment) ?? 0;
    final recurring = double.tryParse(billingAmount) ?? 0;
    if (initial == 0 && recurring == 0) return 'Free';
    if (recurring == 0) return '\$${initial.toStringAsFixed(2)} one-time';
    final period = billingPeriod.trim();
    if (period.isEmpty) return '\$${recurring.toStringAsFixed(2)}';
    return '\$${recurring.toStringAsFixed(2)} / $period';
  }

  /// The two plans published on the site: Free, then Premium Membership.
  static const sitePlans = <MembershipLevel>[
    MembershipLevel(
      id: 1,
      name: 'Free',
      description: '',
      initialPayment: '0',
      billingAmount: '0',
      billingPeriod: '',
      billingLimit: 0,
      isActive: true,
    ),
    MembershipLevel(
      id: 2,
      name: 'Premium Membership',
      description: '',
      initialPayment: '6.99',
      billingAmount: '6.99',
      billingPeriod: 'Month',
      billingLimit: 0,
      isActive: true,
    ),
  ];

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }
}
