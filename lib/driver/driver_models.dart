int? _int(Object? v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

/// Decimal stringlarni ham qabul qiladi: "1.00", "5.5", "10".
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

class DriverRegistrationStatus {
  const DriverRegistrationStatus({
    required this.userId,
    this.driverId,
    this.status,
    required this.nextStep,
    required this.rejectCount,
    this.rejectionReason,
  });

  /// `users.id`
  final int userId;

  /// `drivers.id` — null bo'lsa, hali driver yozuvi yaratilmagan.
  final int? driverId;

  /// `drivers.status`. null = driver yozuvi yo'q.
  /// Backend semantikasi (DriverModerationService const'lari bilan mos):
  ///   1 = pending (moderatsiya kutilmoqda)
  ///   2 = rejected (rad etildi — xatolarni tuzatish kerak)
  ///   3 = failed (3 martadan ortiq rad etildi)
  ///   4 = active (tasdiqlandi — yuk olishi mumkin)
  final int? status;

  /// Backend status kodlari — routing shu konstantalar bilan qilinsin,
  /// raw raqam emas (ilgari 2/3/4 noto'g'ri "active/rejected/failed" deb taxmin qilingan edi).
  static const int statusPending = 1;
  static const int statusRejected = 2;
  static const int statusFailed = 3;
  static const int statusActive = 4;

  /// 1, 2 yoki 3 — qaysi stepdan davom etish kerak. 0 = registratsiya tugagan.
  final int nextStep;

  final int rejectCount;
  final String? rejectionReason;

  static DriverRegistrationStatus fromMap(Map<String, dynamic> m) {
    return DriverRegistrationStatus(
      userId: _int(m['user_id']) ?? 0,
      driverId: _int(m['driver_id']),
      status: _int(m['status']),
      nextStep: _int(m['next_step']) ?? 1,
      rejectCount: _int(m['reject_count']) ?? 0,
      rejectionReason: m['rejection_reason']?.toString(),
    );
  }
}

class DriverRegistrationRejects {
  const DriverRegistrationRejects({
    this.driverId,
    this.step1Errors,
    this.step2Errors,
    this.step3Errors,
    this.comment,
  });

  final int? driverId;
  /// Backend har bir step uchun MASSIV qaytaradi:
  /// `[{field, reason_code, reason_text}, ...]`. Har element — bitta maydon
  /// bo'yicha admin belgilagan xatolik.
  final List<dynamic>? step1Errors;
  final List<dynamic>? step2Errors;
  final List<dynamic>? step3Errors;
  final String? comment;

  bool get hasAnyErrors =>
      (step1Errors?.isNotEmpty ?? false) ||
      (step2Errors?.isNotEmpty ?? false) ||
      (step3Errors?.isNotEmpty ?? false);

  int get firstFailedStep {
    if (step1Errors?.isNotEmpty ?? false) return 1;
    if (step2Errors?.isNotEmpty ?? false) return 2;
    if (step3Errors?.isNotEmpty ?? false) return 3;
    return 1;
  }

  static DriverRegistrationRejects fromMap(Map<String, dynamic> m) {
    return DriverRegistrationRejects(
      driverId: _int(m['driver_id']),
      step1Errors: m['step1_errors'] is List ? m['step1_errors'] as List : null,
      step2Errors: m['step2_errors'] is List ? m['step2_errors'] as List : null,
      step3Errors: m['step3_errors'] is List ? m['step3_errors'] as List : null,
      comment: m['comment']?.toString(),
    );
  }
}

/// Rad etilgan haydovchining oldin yuborgan registratsiya qiymatlari (Driver +
/// Vehicle). "Xatolarni tuzatish" oqimida step maydonlarini oldindan to'ldirish
/// uchun. Rasm maydonlari `*_img_url` — nisbiy `/storage/...` yo'l.
class DriverRegistrationData {
  const DriverRegistrationData({this.step1, this.step2, this.step3});

  final Map<String, dynamic>? step1;
  final Map<String, dynamic>? step2;
  final Map<String, dynamic>? step3;

  static Map<String, dynamic>? _sect(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : null;

  static DriverRegistrationData fromMap(Map<String, dynamic> m) {
    return DriverRegistrationData(
      step1: _sect(m['step1']),
      step2: _sect(m['step2']),
      step3: _sect(m['step3']),
    );
  }

  String? s1(String k) => _str(step1?[k]);
  String? s2(String k) => _str(step2?[k]);
  String? s3(String k) => _str(step3?[k]);
  int? i2(String k) => _int(step2?[k]);
  int? i3(String k) => _int(step3?[k]);
  bool b2(String k) => step2?[k] == true;

  static String? _str(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    return s.isEmpty ? null : s;
  }
}

class DriverStepResult {
  const DriverStepResult({
    required this.nextStep,
    this.sessionId,
    this.tempToken,
  });

  final int nextStep;
  final String? sessionId;
  final String? tempToken;

  static DriverStepResult fromMap(Map<String, dynamic> m) {
    return DriverStepResult(
      nextStep: _int(m['next_step']) ?? 0,
      sessionId: m['session_id']?.toString(),
      tempToken: m['temp_token']?.toString(),
    );
  }
}

class AvtoparkItem {
  const AvtoparkItem({
    required this.id,
    required this.name,
    this.uniqueCode,
  });

  final int id;
  final String name;
  final String? uniqueCode;

  static AvtoparkItem? fromMap(Map<String, dynamic> m) {
    final id = _int(m['id']);
    if (id == null) return null;
    return AvtoparkItem(
      id: id,
      name: (m['company_name'] ?? m['name'])?.toString() ?? '',
      uniqueCode: m['unique_code']?.toString(),
    );
  }
}

class DriverTariffItem {
  const DriverTariffItem({
    required this.id,
    required this.name,
    this.pricePerKm,
  });

  final int id;
  final String name;
  final String? pricePerKm;

  static DriverTariffItem? fromMap(Map<String, dynamic> m) {
    final id = _int(m['id']);
    if (id == null) return null;
    return DriverTariffItem(
      id: id,
      name: m['name']?.toString() ?? '',
      pricePerKm: m['price_per_km']?.toString(),
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

class DriverOrder {
  const DriverOrder({
    required this.id,
    this.orderNumber,
    this.status,
    this.totalPrice,
    this.basePrice,
    this.distanceKm,
    this.distanceM,
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
    this.projectCommissionPct,
    this.companyCommissionPct,
    this.projectCommissionAmount,
    this.companyCommissionAmount,
    this.driverIncomeAmount,
    this.scheduledPickupAt,
    this.incomeVisible = true,
  });

  final int id;
  final String? orderNumber;
  final int? status;
  final String? totalPrice;
  final String? basePrice;
  final String? distanceKm;
  final double? distanceM;
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
  /// `cancel_reasons.id` (yangi flow). Eski yozuvlarda NULL.
  final int? cancelReasonId;
  /// Eager-loaded sabab nomi (uz/ru + is_other).
  final DriverOrderCancelReasonInfo? cancelReasonInfo;
  final String? projectCommissionPct;
  final String? companyCommissionPct;
  final String? projectCommissionAmount;
  final String? companyCommissionAmount;
  final String? driverIncomeAmount;
  /// Rejali buyurtma — kelajakdagi olib ketish vaqti. NULL bo'lsa zudlik bilan.
  final String? scheduledPickupAt;

  /// Driverga tushum (daromad + komissiya taqsimoti) ko'rsatiladimi? Avtoparkning
  /// O'Z (fleet) driveri uchun `false` — u faqat yuk ma'lumotlarini ko'radi.
  final bool incomeVisible;

  static double? _double(Object? v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static DriverOrder? fromMap(Map<String, dynamic> m) {
    final id = _int(m['id'] ?? m['order_id']);
    if (id == null) return null;
    return DriverOrder(
      id: id,
      orderNumber: m['order_number']?.toString(),
      status: _int(m['status']),
      totalPrice: m['total_price']?.toString(),
      basePrice: m['base_price']?.toString(),
      distanceKm: m['distance_km']?.toString(),
      distanceM: _double(m['distance_m']),
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
      cancelReasonInfo: DriverOrderCancelReasonInfo.fromMap(m['cancel_reason_info'] as Map<String, dynamic>?),
      projectCommissionPct: m['project_commission_pct']?.toString(),
      companyCommissionPct: m['company_commission_pct']?.toString(),
      projectCommissionAmount: m['project_commission_amount']?.toString(),
      companyCommissionAmount: m['company_commission_amount']?.toString(),
      driverIncomeAmount: m['driver_income_amount']?.toString(),
      scheduledPickupAt: m['scheduled_pickup_at']?.toString(),
      // Backend yubormasa (eski javob) — default true (ko'rsatiladi).
      incomeVisible: m['income_visible'] is bool ? m['income_visible'] as bool : true,
    );
  }
}

/// Order detail javobidagi `cancel_reason_info` nested object (eager-loaded
/// catalog row). Client joriy localega ko'ra `name_uz`/`name_ru` dan birini
/// ko'rsatadi; `isOther=true` bo'lsa custom matn izoh sifatida qo'shiladi.
class DriverOrderCancelReasonInfo {
  const DriverOrderCancelReasonInfo({
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

  static DriverOrderCancelReasonInfo? fromMap(Map<String, dynamic>? m) {
    if (m == null) return null;
    final id = _int(m['id']);
    if (id == null) return null;
    return DriverOrderCancelReasonInfo(
      id: id,
      code: m['code']?.toString() ?? '',
      nameUz: m['name_uz']?.toString() ?? '',
      nameRu: m['name_ru']?.toString() ?? '',
      isOther: m['is_other'] == true,
    );
  }
}

class DriverWalletSnapshot {
  const DriverWalletSnapshot({this.balance, this.currency = 'UZS'});

  final String? balance;
  final String? currency;

  static DriverWalletSnapshot? fromMap(dynamic data) {
    if (data is! Map<String, dynamic>) return null;
    return DriverWalletSnapshot(
      balance: data['balance']?.toString() ?? data['available_balance']?.toString(),
      currency: data['currency']?.toString() ?? 'UZS',
    );
  }
}

/// Driver'ning hozirgi online holati va saqlangan cargo turlari snapshot'i.
/// `GET /api/driver/me/status` orqali olinadi.
class DriverStatusSnapshot {
  const DriverStatusSnapshot({
    required this.isOnline,
    required this.cargoTypeIds,
    this.wentOnlineAt,
  });

  final bool isOnline;
  final List<int> cargoTypeIds;
  final String? wentOnlineAt;

  static DriverStatusSnapshot fromMap(Map<String, dynamic> m) {
    final rawIds = m['cargo_type_ids'];
    final ids = <int>[];
    if (rawIds is List) {
      for (final e in rawIds) {
        final v = _int(e);
        if (v != null) ids.add(v);
      }
    }
    return DriverStatusSnapshot(
      isOnline: m['is_online'] == true,
      cargoTypeIds: ids,
      wentOnlineAt: m['went_online_at']?.toString(),
    );
  }
}

/// Driver fleet (avtopark) ma'lumotini olib keladi.
/// `GET /api/driver/wallet/fleet-info`.
class DriverFleetInfo {
  const DriverFleetInfo({
    required this.isFleet,
    required this.personalBalance,
    required this.personalCurrency,
    this.avtoparkId,
    this.avtoparkName,
    this.avtoparkCommissionPct,
    this.avtoparkBalance,
    this.avtoparkCurrency,
    this.myTotalToAvtopark,
    this.recentMyEarnings = const [],
  });

  final bool isFleet;
  final String personalBalance;
  final String personalCurrency;
  final int? avtoparkId;
  final String? avtoparkName;
  final String? avtoparkCommissionPct;
  final String? avtoparkBalance;
  final String? avtoparkCurrency;
  final String? myTotalToAvtopark;
  final List<DriverWalletTx> recentMyEarnings;

  static DriverFleetInfo? fromMap(Map<String, dynamic>? m) {
    if (m == null) return null;
    final personal = m['personal_wallet'] as Map<String, dynamic>?;
    final avtopark = m['avtopark'] as Map<String, dynamic>?;
    final avWallet = m['avtopark_wallet'] as Map<String, dynamic>?;
    final earnings = (m['recent_my_earnings'] as List?) ?? const [];
    return DriverFleetInfo(
      isFleet: m['is_fleet'] == true,
      personalBalance: personal?['balance']?.toString() ?? '0',
      personalCurrency: personal?['currency']?.toString() ?? 'UZS',
      avtoparkId: _int(avtopark?['id']),
      avtoparkName: avtopark?['name']?.toString(),
      avtoparkCommissionPct: avtopark?['commission_pct']?.toString(),
      avtoparkBalance: avWallet?['balance']?.toString(),
      avtoparkCurrency: avWallet?['currency']?.toString(),
      myTotalToAvtopark: m['my_total_to_avtopark']?.toString(),
      recentMyEarnings: earnings
          .whereType<Map<String, dynamic>>()
          .map(DriverWalletTx.fromMap)
          .toList(),
    );
  }
}

class DriverWalletTx {
  const DriverWalletTx({
    this.title,
    this.amount,
    this.createdAt,
    this.transactionType,
    this.orderId,
  });

  /// Raw description (backend tilida saqlangan) — fallback faqat.
  final String? title;
  final String? amount;
  final String? createdAt;
  /// 1=Topup, 2=OrderPayment, 3=OrderSettlement, 4=Compensation, 5=Refund.
  final int? transactionType;
  final int? orderId;

  static int? _intOf(Object? v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static DriverWalletTx fromMap(Map<String, dynamic> m) {
    return DriverWalletTx(
      title: m['type']?.toString() ?? m['description']?.toString() ?? m['note']?.toString(),
      amount: m['amount']?.toString(),
      createdAt: m['created_at']?.toString(),
      transactionType: _intOf(m['transaction_type']),
      orderId: _intOf(m['order_id']),
    );
  }
}

List<Map<String, dynamic>> mapListFrom(dynamic v) {
  if (v is List) {
    return v
        .map((e) => e is Map<String, dynamic> ? e : <String, dynamic>{})
        .where((e) => e.isNotEmpty)
        .toList();
  }
  if (v is Map<String, dynamic>) {
    if (v['items'] is List) return mapListFrom(v['items']);
    if (v['data'] is List) return mapListFrom(v['data']);
  }
  return [];
}
