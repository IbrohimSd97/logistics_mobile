import 'alix_components.dart';

/// Buyurtma statusining rang ohangi — bitta manba.
///
/// Bir xil buyurtma ro'yxatda, tafsilotda va haydovchi ekranida bir xil
/// rangda ko'rinishi kerak, shuning uchun bu moslik faqat shu yerda turadi.
/// Brend orange faqat "jarayonda" holatiga tegishli: shunda u CTA va progress
/// bilan bir xil ma'noda — "harakat ketmoqda" — o'qiladi.
///
/// Status kodlari `OrderStatusCode` (1..12) bilan mos.
AlixTone orderStatusTone(int? status) {
  switch (status) {
    case 2: // haydovchi qidirilmoqda
      return AlixTone.warning;
    case 3: // qabul qilindi
    case 4: // pickup'ga keldi
    case 5: // yuklanmoqda
    case 6: // yo'lda
    case 7: // delivery'ga keldi
    case 8: // tushirilmoqda
      return AlixTone.progress;
    case 9: // yetkazildi
    case 10: // yakunlandi
      return AlixTone.success;
    case 11: // bekor qilindi
    case 12: // muvaffaqiyatsiz
      return AlixTone.danger;
    default: // 1 = yangi va noma'lum holatlar
      return AlixTone.neutral;
  }
}
