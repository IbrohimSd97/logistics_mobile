# Do'kon materiallari (ALIX 1.1.3+15)

Rasmlar haqiqiy ilova kodi bilan, soxta ma'lumotlar asosida chiziladi:

    flutter test test/store --dart-define=store_shots=true --update-goldens
    python3 store_assets/flatten.py   # alfa-kanalni olib tashlaydi (App Store)

## App Store Connect (faqat iPhone)
| Papka | O'lcham | Qayerga |
|---|---|---|
| `screenshots/ios_6.9/<til>/` | 1320×2868 | iPhone 6.9" Display |
| `screenshots/ios_6.5/<til>/` | 1242×2688 | iPhone 6.5" Display |

`uz` → O'zbek lokalizatsiyasi, `ru` → Русский. Tartib: 01 → 06.

## Google Play Console
| Fayl | O'lcham | Qayerga |
|---|---|---|
| `screenshots/play_phone/<til>/` | 1080×1920 | Phone screenshots |
| `play/feature_graphic_<til>.png` | 1024×500 | Feature graphic |
| `play/icon_512.png` | 512×512 | App icon |

## .aab
`flutter build appbundle --release` → `build/app/outputs/bundle/release/app-release.aab`
(paket `uz.alix.app`, upload kaliti `android/key.properties` orqali — u git'ga kirmaydi).
