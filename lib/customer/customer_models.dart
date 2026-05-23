class CustomerProfile {
  const CustomerProfile({
    required this.userId,
    this.customerId,
    this.lastName,
    this.firstName,
    this.middleName,
    this.birthDate,
    this.phoneNumber,
    this.idDocumentType,
    this.idDocFrontImg,
    this.idDocBackImg,
    this.idDocSelfieImg,
  });

  final int userId;
  final int? customerId;
  final String? lastName;
  final String? firstName;
  final String? middleName;
  final String? birthDate;
  final String? phoneNumber;
  final int? idDocumentType;
  final String? idDocFrontImg;
  final String? idDocBackImg;
  final String? idDocSelfieImg;

  static CustomerProfile? fromMap(Map<String, dynamic>? m) {
    if (m == null) return null;
    final id = _int(m['user_id']);
    if (id == null) return null;
    return CustomerProfile(
      userId: id,
      customerId: _int(m['customer_id']),
      lastName: m['last_name']?.toString(),
      firstName: m['first_name']?.toString(),
      middleName: m['middle_name']?.toString(),
      birthDate: m['birth_date']?.toString(),
      phoneNumber: m['phone_number']?.toString(),
      idDocumentType: _int(m['id_document_type']),
      idDocFrontImg: m['id_doc_front_img']?.toString(),
      idDocBackImg: m['id_doc_back_img']?.toString(),
      idDocSelfieImg: m['id_doc_selfie_img']?.toString(),
    );
  }
}

class TariffItem {
  const TariffItem({
    required this.id,
    required this.name,
    this.description,
    this.pricePerKm,
    this.minOrderPrice,
  });

  final int id;
  final String name;
  final String? description;
  final String? pricePerKm;
  final String? minOrderPrice;

  static TariffItem? fromMap(Map<String, dynamic>? m) {
    if (m == null) return null;
    final id = _int(m['id']);
    if (id == null) return null;
    return TariffItem(
      id: id,
      name: m['name']?.toString() ?? '',
      description: m['description']?.toString(),
      pricePerKm: m['price_per_km']?.toString(),
      minOrderPrice: m['min_order_price']?.toString(),
    );
  }
}

class CargoTypeMini {
  const CargoTypeMini({
    required this.id,
    required this.name,
    this.pickupFreeWaitMinutes = 0,
    this.pickupPaidWaitPrice,
    this.pickupPaidWaitIntervalMin = 10,
    this.deliveryFreeWaitMinutes = 0,
    this.deliveryPaidWaitPrice,
    this.deliveryPaidWaitIntervalMin = 10,
  });

  final int id;
  final String name;
  final int pickupFreeWaitMinutes;
  final String? pickupPaidWaitPrice;
  final int pickupPaidWaitIntervalMin;
  final int deliveryFreeWaitMinutes;
  final String? deliveryPaidWaitPrice;
  final int deliveryPaidWaitIntervalMin;

  static CargoTypeMini? fromMap(Map<String, dynamic>? m) {
    if (m == null) return null;
    final id = _int(m['id']);
    if (id == null) return null;
    return CargoTypeMini(
      id: id,
      name: m['name']?.toString() ?? '',
      pickupFreeWaitMinutes: _int(m['pickup_free_wait_minutes']) ?? 0,
      pickupPaidWaitPrice: m['pickup_paid_wait_price']?.toString(),
      pickupPaidWaitIntervalMin: _int(m['pickup_paid_wait_interval_min']) ?? 10,
      deliveryFreeWaitMinutes: _int(m['delivery_free_wait_minutes']) ?? 0,
      deliveryPaidWaitPrice: m['delivery_paid_wait_price']?.toString(),
      deliveryPaidWaitIntervalMin: _int(m['delivery_paid_wait_interval_min']) ?? 10,
    );
  }
}

class CustomerOrder {
  const CustomerOrder({
    required this.id,
    this.orderNumber,
    this.status,
    this.totalPrice,
    this.basePrice,
    this.distanceKm,
    this.currency,
    this.pickupAddress,
    this.pickupLat,
    this.pickupLng,
    this.deliveryAddress,
    this.deliveryLat,
    this.deliveryLng,
    this.acceptLat,
    this.acceptLng,
    this.cargoWeightKg,
    this.comment,
    this.createdAt,
    this.cargoType,
    this.acceptedAt,
    this.arrivedPickupAt,
    this.loadingStartedAt,
    this.inTransitAt,
    this.arrivedDeliveryAt,
    this.unloadingStartedAt,
    this.deliveredAt,
    this.deliveryDeadlineAt,
    this.slaHoursSnapshot,
    this.latePenaltyAmount,
    this.completedAt,
    this.cancelledAt,
    this.cancelReason,
    this.cancelReasonId,
    this.cancelReasonInfo,
    this.scheduledPickupAt,
    this.projectCommissionPct,
    this.projectCommissionAmount,
    this.companyCommissionPct,
    this.companyCommissionAmount,
    this.driverIncomeAmount,
  });

  final int id;
  final String? orderNumber;
  final int? status;
  final String? totalPrice;
  final String? basePrice;
  final String? distanceKm;
  final String? currency;
  final String? pickupAddress;
  final double? pickupLat;
  final double? pickupLng;
  final String? deliveryAddress;
  final double? deliveryLat;
  final double? deliveryLng;
  final double? acceptLat;
  final double? acceptLng;
  final int? cargoWeightKg;
  final String? comment;
  final String? createdAt;
  final CargoTypeMini? cargoType;
  final String? acceptedAt;
  final String? arrivedPickupAt;
  final String? loadingStartedAt;
  final String? inTransitAt;
  final String? arrivedDeliveryAt;
  final String? unloadingStartedAt;
  final String? deliveredAt;
  final String? deliveryDeadlineAt;
  final int? slaHoursSnapshot;
  final String? latePenaltyAmount;
  final String? completedAt;
  final String? cancelledAt;
  final String? cancelReason;
  /// `cancel_reasons` jadvalidan tanlangan sabab IDsi (yangi flow).
  /// Eski yozuvlarda NULL bo'ladi — bu holatda `cancelReason` matni
  /// to'g'ridan-to'g'ri ko'rsatiladi.
  final int? cancelReasonId;
  /// Eager-loaded sabab nomi (uz/ru va is_other bayrog'i).
  final CustomerOrderCancelReasonInfo? cancelReasonInfo;
  /// Rejali buyurtma — kelajakdagi olib ketish vaqti. NULL bo'lsa zudlik bilan.
  final String? scheduledPickupAt;
  // ── Komissiya snapshot (Customer ko'rinishi uchun) ──
  // Backend Order modeli orqali keladi. Project — loyiha (platforma) komissiyasi,
  // Company — avtopark komissiyasi. Order yaratilganda project_* darhol o'rnatiladi,
  // driver Accept qilganida company_* qo'shiladi. Settlement esa yakuniy summalarni
  // qayta yozadi.
  final String? projectCommissionPct;
  final String? projectCommissionAmount;
  final String? companyCommissionPct;
  final String? companyCommissionAmount;
  final String? driverIncomeAmount;

  static double? _double(Object? v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static CustomerOrder? fromMap(Map<String, dynamic> m) {
    final id = _int(m['id'] ?? m['order_id']);
    if (id == null) return null;
    return CustomerOrder(
      id: id,
      orderNumber: m['order_number']?.toString(),
      status: _int(m['status']),
      totalPrice: m['total_price']?.toString(),
      basePrice: m['base_price']?.toString(),
      distanceKm: m['distance_km']?.toString(),
      currency: m['currency']?.toString(),
      pickupAddress: m['pickup_address']?.toString(),
      pickupLat: _double(m['pickup_lat']),
      pickupLng: _double(m['pickup_lng']),
      deliveryAddress: m['delivery_address']?.toString(),
      deliveryLat: _double(m['delivery_lat']),
      deliveryLng: _double(m['delivery_lng']),
      acceptLat: _double(m['accept_lat']),
      acceptLng: _double(m['accept_lng']),
      cargoWeightKg: _intFromAny(m['cargo_weight_kg']),
      comment: m['comment']?.toString(),
      createdAt: m['created_at']?.toString(),
      cargoType: CargoTypeMini.fromMap(m['cargo_type'] as Map<String, dynamic>?),
      acceptedAt: m['accepted_at']?.toString(),
      arrivedPickupAt: m['arrived_pickup_at']?.toString(),
      loadingStartedAt: m['loading_started_at']?.toString(),
      inTransitAt: m['in_transit_at']?.toString(),
      arrivedDeliveryAt: m['arrived_delivery_at']?.toString(),
      unloadingStartedAt: m['unloading_started_at']?.toString(),
      deliveredAt: m['delivered_at']?.toString(),
      deliveryDeadlineAt: m['delivery_deadline_at']?.toString(),
      slaHoursSnapshot: _int(m['sla_hours_snapshot']),
      latePenaltyAmount: m['late_penalty_amount']?.toString(),
      completedAt: m['completed_at']?.toString(),
      cancelledAt: m['cancelled_at']?.toString(),
      cancelReason: m['cancel_reason']?.toString(),
      cancelReasonId: _int(m['cancel_reason_id']),
      cancelReasonInfo: CustomerOrderCancelReasonInfo.fromMap(m['cancel_reason_info'] as Map<String, dynamic>?),
      scheduledPickupAt: m['scheduled_pickup_at']?.toString(),
      projectCommissionPct: m['project_commission_pct']?.toString(),
      projectCommissionAmount: m['project_commission_amount']?.toString(),
      companyCommissionPct: m['company_commission_pct']?.toString(),
      companyCommissionAmount: m['company_commission_amount']?.toString(),
      driverIncomeAmount: m['driver_income_amount']?.toString(),
    );
  }
}

/// Order detail javobidagi `cancel_reason_info` nested object — sabab
/// catalog qatori (eager-loaded). Client joriy localega ko'ra `displayName`
/// ni ko'rsatadi; `isOther=true` bo'lsa `cancelReason` matnini izoh sifatida
/// qo'shadi.
class CustomerOrderCancelReasonInfo {
  const CustomerOrderCancelReasonInfo({
    required this.id,
    required this.code,
    required this.nameUz,
    required this.nameRu,
    required this.isOther,
  });

  final int id;
  final String code;
  final String nameUz;
  final String nameRu;
  final bool isOther;

  static CustomerOrderCancelReasonInfo? fromMap(Map<String, dynamic>? m) {
    if (m == null) return null;
    final id = _int(m['id']);
    if (id == null) return null;
    return CustomerOrderCancelReasonInfo(
      id: id,
      code: m['code']?.toString() ?? '',
      nameUz: m['name_uz']?.toString() ?? '',
      nameRu: m['name_ru']?.toString() ?? '',
      isOther: m['is_other'] == true,
    );
  }
}

class WalletSnapshot {
  const WalletSnapshot({this.balance, this.currency = 'UZS', this.ownerType});

  final String? balance;
  final String? currency;
  /// 1=driver, 2=customer, 3=app, 4=avtopark, 5=customer_company.
  /// Korporativ (5) bo'lsa UI top-up tugmalarini yashiradi (faqat admin to'ldiradi).
  final int? ownerType;

  bool get isCorporate => ownerType == 5;

  static WalletSnapshot? fromData(dynamic data) {
    if (data is! Map<String, dynamic>) return null;
    final ot = data['owner_type'];
    return WalletSnapshot(
      balance: data['balance']?.toString() ?? data['available_balance']?.toString(),
      currency: data['currency']?.toString() ?? 'UZS',
      ownerType: ot is int ? ot : (ot != null ? int.tryParse(ot.toString()) : null),
    );
  }
}

class WalletTransaction {
  const WalletTransaction({
    this.title,
    this.amount,
    this.createdAt,
    this.transactionType,
    this.orderId,
    this.raw,
  });

  /// Raw description (backend tilida saqlangan) — fallback faqat.
  final String? title;
  final String? amount;
  final String? createdAt;
  /// 1=Topup, 2=OrderPayment, 3=OrderSettlement, 4=Compensation, 5=Refund.
  /// Mobile tomonda I18n.t bilan tarjima qilinadi.
  final int? transactionType;
  final int? orderId;
  final Map<String, dynamic>? raw;

  static int? _intOf(Object? v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static WalletTransaction fromMap(Map<String, dynamic> m) {
    return WalletTransaction(
      title: m['type']?.toString() ?? m['description']?.toString() ?? m['note']?.toString(),
      amount: m['amount']?.toString(),
      createdAt: m['created_at']?.toString(),
      transactionType: _intOf(m['transaction_type']),
      orderId: _intOf(m['order_id']),
      raw: m,
    );
  }
}

class CreateOrderResult {
  const CreateOrderResult({
    required this.orderId,
    this.orderNumber,
    this.status,
    this.distanceKm,
    this.basePrice,
    this.totalPrice,
    this.currency,
  });

  final int orderId;
  final String? orderNumber;
  final int? status;
  final String? distanceKm;
  final String? basePrice;
  final String? totalPrice;
  final String? currency;
}

/// Customer billing info — shaxsiy + (mavjud bo'lsa) kompaniya hamyon.
/// `GET /api/customer/wallet/billing-info`.
class CustomerBillingInfo {
  const CustomerBillingInfo({
    required this.isCompanyStaff,
    required this.personalBalance,
    required this.personalCurrency,
    required this.billingSource,
    this.companyId,
    this.companyName,
    this.companyTaxNumber,
    this.companyBalance,
    this.companyCurrency,
    this.recentCompanyTx = const [],
  });

  final bool isCompanyStaff;
  final String personalBalance;
  final String personalCurrency;
  /// 'personal' yoki 'company' — qaysi hamyondan yechiladi.
  final String billingSource;
  final int? companyId;
  final String? companyName;
  final String? companyTaxNumber;
  final String? companyBalance;
  final String? companyCurrency;
  final List<WalletTransaction> recentCompanyTx;

  bool get isCorporateBilling => billingSource == 'company';

  static CustomerBillingInfo? fromMap(Map<String, dynamic>? m) {
    if (m == null) return null;
    final personal = m['personal_wallet'] as Map<String, dynamic>?;
    final company = m['company'] as Map<String, dynamic>?;
    final companyWallet = m['company_wallet'] as Map<String, dynamic>?;
    final txList = (m['recent_company_tx'] as List?) ?? const [];
    return CustomerBillingInfo(
      isCompanyStaff: m['is_company_staff'] == true,
      personalBalance: personal?['balance']?.toString() ?? '0',
      personalCurrency: personal?['currency']?.toString() ?? 'UZS',
      billingSource: m['billing_source']?.toString() ?? 'personal',
      companyId: _int(company?['id']),
      companyName: company?['name']?.toString(),
      companyTaxNumber: company?['tax_number']?.toString(),
      companyBalance: companyWallet?['balance']?.toString(),
      companyCurrency: companyWallet?['currency']?.toString(),
      recentCompanyTx: txList
          .whereType<Map<String, dynamic>>()
          .map(WalletTransaction.fromMap)
          .toList(),
    );
  }
}

class WalletPaymentResult {
  const WalletPaymentResult({
    required this.orderId,
    this.orderStatus,
    this.paymentStatus,
    this.amountPaid,
    this.walletBalanceAfter,
    this.currency,
  });

  final int orderId;
  final int? orderStatus;
  final int? paymentStatus;
  final String? amountPaid;
  final String? walletBalanceAfter;
  final String? currency;

  static WalletPaymentResult? fromMap(Map<String, dynamic>? m) {
    if (m == null) return null;
    final id = _int(m['order_id']);
    if (id == null) return null;
    return WalletPaymentResult(
      orderId: id,
      orderStatus: _int(m['order_status']),
      paymentStatus: _int(m['payment_status']),
      amountPaid: m['amount_paid']?.toString(),
      walletBalanceAfter: m['wallet_balance_after']?.toString(),
      currency: m['currency']?.toString(),
    );
  }
}

int? _int(Object? v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

/// Driver'ning oxirgi GPS lokatsiyasi (customer real-vaqt tracking uchun).
/// `recordedAt` — oxirgi yangilangan vaqt; `ageSeconds` — server hisobi
/// (NOW() - recorded_at), UI'da "X soniya oldin" ko'rsatish uchun qulay.
class DriverLiveLocation {
  const DriverLiveLocation({
    required this.driverId,
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    required this.ageSeconds,
  });

  final int driverId;
  final double latitude;
  final double longitude;
  final String recordedAt;
  final int ageSeconds;

  static DriverLiveLocation? fromMap(Map<String, dynamic>? m) {
    if (m == null) return null;
    final id = _int(m['driver_id']);
    final lat = double.tryParse('${m['latitude']}');
    final lng = double.tryParse('${m['longitude']}');
    if (id == null || lat == null || lng == null) return null;
    return DriverLiveLocation(
      driverId: id,
      latitude: lat,
      longitude: lng,
      recordedAt: (m['recorded_at'] ?? '').toString(),
      ageSeconds: _int(m['age_seconds']) ?? 0,
    );
  }
}

int? _intFromAny(Object? v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  final s = v.toString();
  final asInt = int.tryParse(s);
  if (asInt != null) return asInt;
  final asDouble = double.tryParse(s);
  if (asDouble != null) return asDouble.round();
  return null;
}

List<Map<String, dynamic>> mapListFrom(dynamic v) {
  if (v is List) {
    return v.map((e) => e is Map<String, dynamic> ? e : <String, dynamic>{}).where((e) => e.isNotEmpty).toList();
  }
  if (v is Map<String, dynamic>) {
    if (v['items'] is List) return mapListFrom(v['items']);
    if (v['data'] is List) return mapListFrom(v['data']);
    if (v['orders'] is List) return mapListFrom(v['orders']);
  }
  return [];
}
