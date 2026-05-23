import 'i18n.dart';

/// Wallet tranzaksiyasi uchun foydalanuvchiga ko'rinadigan sarlavhani
/// joriy tilda qaytaradi. Backend `description` matnini emas — `transaction_type`
/// integer kodini va `description`'ning ma'lum kalit so'zlarini ishlatadi.
///
/// `transaction_type`:
///   1 — Topup
///   2 — Order payment (escrow)
///   3 — Order settlement (driver/avtopark/app)
///   4 — Compensation
///   5 — Refund (cancel)
///
/// Settlement (type=3) bir nechta yo'nalishda ishlatiladi (driver daromadi,
/// avtopark komissiyasi, platforma komissiyasi). Ularni `description`'dagi
/// kalit so'zlardan ajratamiz.
String walletTxLabel({
  required int? transactionType,
  required String? rawDescription,
  double? amount,
}) {
  final desc = (rawDescription ?? '').toLowerCase();

  switch (transactionType) {
    case 1:
      return I18n.t('wallet.tx.topup');
    case 2:
      if (desc.contains('korporativ') || desc.contains('корпоратив')) {
        return I18n.t('wallet.tx.order_payment_corp');
      }
      return I18n.t('wallet.tx.order_payment');
    case 3:
      // Settlement — variantlar:
      //  • "Buyurtma yakuni — driver daromadi"
      //  • "Buyurtma yakuni — fleet driver daromadi (driver_id=X)"
      //  • "Buyurtma yakuni — avtopark komissiyasi"
      //  • "Buyurtma yakuni — platforma komissiyasi"
      if (desc.contains('platforma') ||
          desc.contains('платформ')) {
        return I18n.t('wallet.tx.settlement_app_commission');
      }
      if (desc.contains('avtopark komissiyasi') ||
          desc.contains('комисс') && desc.contains('автопарк')) {
        return I18n.t('wallet.tx.settlement_avtopark_commission');
      }
      if (desc.contains('fleet driver daromadi') ||
          desc.contains('водител') && desc.contains('автопарк')) {
        return I18n.t('wallet.tx.settlement_avtopark_income');
      }
      if (desc.contains('driver daromadi') ||
          desc.contains('водител')) {
        return I18n.t('wallet.tx.settlement_driver');
      }
      return I18n.t('wallet.tx.settlement_driver');
    case 4:
      // Compensation — har xil sabablar bo'lishi mumkin. Hozircha umumiy.
      if (desc.contains('jarima') || desc.contains('штраф')) {
        if ((amount ?? 0) >= 0) {
          return I18n.t('wallet.tx.late_penalty_refund');
        }
        return I18n.t('wallet.tx.late_penalty_charge');
      }
      return I18n.t('wallet.tx.compensation');
    case 5:
      return I18n.t('wallet.tx.refund');
    default:
      // Fallback — DB matn (kamida o'qish mumkin)
      if ((rawDescription ?? '').isNotEmpty) return rawDescription!;
      return I18n.t('wallet.tx.unknown');
  }
}
