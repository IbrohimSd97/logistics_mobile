import 'package:flutter/widgets.dart';

/// Klaviaturani yopadi va oxirgi fokuslangan inputni "unutadi".
///
/// `FocusScope.of(context).unfocus()` yetarli emas: u sahifa fokus doirasini
/// yopadi, lekin doira ichida oxirgi input eslab qolinadi va dialog/sheet/
/// kamera sahifasi yopilganda fokus o'sha inputga QAYTARILADI — klaviatura
/// o'z-o'zidan ochilib qoladi. Bu yerda esa fokuslangan input to'g'ridan-
/// to'g'ri bo'shatiladi (UnfocusDisposition.scope), tarixdan ham chiqadi.
void dismissKeyboard() => FocusManager.instance.primaryFocus?.unfocus();

/// Kalendar, rasm tanlash, kamera, fayl tanlash kabi oynani klaviaturasiz
/// ochadi va yopilgandan keyin ham hech bir input fokus olmasligini
/// ta'minlaydi (route yopilishi fokusni keyingi kadrda tiklashi mumkin).
Future<T> withoutKeyboard<T>(Future<T> Function() action) async {
  dismissKeyboard();
  try {
    return await action();
  } finally {
    dismissKeyboard();
    WidgetsBinding.instance.addPostFrameCallback((_) => dismissKeyboard());
  }
}
