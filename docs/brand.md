# ALIX brend tizimi (mobil ilova)

Bu hujjat ilovadagi brendning manba nuqtasi: ranglar, shrift, logotip va
komponentlar qayerda belgilangani va ularni qanday o'zgartirish kerakligi.

## 1. Ranglar

Brend ikki rangdan iborat — orange va charcoal. Qolgani neytral yuzalar.

| Token | Qiymat | Qayerda |
|---|---|---|
| `AppPalette.orange` | `#FF6A13` | Asosiy CTA, faol holat, marshrut chizig'i, progress |
| `AppPalette.orangeDeep` | `#E05605` | Bosilgan holat, gradient oxiri |
| `AppPalette.orangeSoft` | `#FFF0E6` | Yorug' fonda orange chip/banner |
| `AppPalette.ink` | `#3A3A3A` | Asosiy matn, ikkilamchi CTA |
| `AppPalette.inkStrong` | `#1E1E1E` | To'q kartalar (tracking), snackbar, tooltip |
| `AppPalette.inkMuted` | `#616161` | Ikkinchi darajali matn |
| `AppPalette.sand` | `#F4F2EE` | Krem yuza: ro'yxat kartalari, input foni |
| `AppPalette.sandBorder` | `#E8E6E2` | Krem yuzaning chegarasi |

Holat ranglari (brenddan tashqari, faqat ma'no uchun): `success #12A150`,
`amber #F5A524` (kutilmoqda), `dangerLight #E5484D`.

### Kontrast va matn variantlari

Brend orange yorug' fonda **2.87:1** beradi — WCAG AA (4.5:1) dan past.
Shuning uchun rang ikkiga bo'lingan:

* **to'ldirish** (tugma foni, progress, nuqta, ikonka) — brend `orange`;
* **matn** (chip yozuvi, havola, kichik yorliq) — `orangeText #B23F00`
  (oq fonda 5.83:1, krem fonda 5.23:1).

Xuddi shunday `successText #0B6B35` va matn uchun `danger #B3261E`.
Rejimga qarab tanlash: `AppPalette.accentTextOn(brightness)`,
`successTextOn`, `dangerTextOn` — to'q rejimda brend ranglari o'zi
yetarli kontrast beradi.

**Ongli chetlanish:** asosiy CTA (oq matn + orange fon) 2.87:1 da qoladi —
bu brend materiallaridagi ko'rinish. Kompensatsiya: tugma balandligi
52–56 dp, matn 16 px qalin, teginish maydoni katta. Agar qat'iy AA talab
qilinsa, CTA foni `#C44600` ga quyultiriladi (4.97:1).

Teginish maydonlari kamida 44 dp.

To'q rejim yuzalari: `darkBg #141414`, `darkCard #1E1E1E`,
`darkCardElevated #262626`, `darkBorder #333333`, matn `#F4F2EE`.

**Qoida:** ekran fayllarida rang qo'lda yozilmaydi. Yo `Theme.of(context).colorScheme`,
yo `AppPalette` ishlatiladi — shunda brend o'zgarsa bitta fayl yangilanadi.

## 2. Tipografika

Shrift — **Manrope** (`assets/fonts/`, OFL litsenziyasi o'sha papkada).
Lotin, kirill va o'zbekcha `ʻ` belgisini qo'llab-quvvatlaydi, shuning uchun
uz / ru / en uchun bitta oila yetarli.

Og'irliklar: 400, 500, 600, 700, 800. Statik fayllar variable shriftdan
ajratib olingan:

```bash
python3 -m fontTools.varLib.instancer "Manrope[wght].ttf" wght=700 -o Manrope-Bold.ttf
```

Shkala `AppTheme._textTheme` da: sarlavhalar zich (manfiy `letterSpacing`) va
qalin, matn qatorlari `height: 1.45`. Bo'lim sarlavhalari (`titleSmall`) —
kichik, katta harfli, keng oraliqli.

## 3. Logotip

Belgi — konteyner panellari: to'rtta charcoal panel va o'ngida orange panel,
uning ichida oq tirqish. Nisbat **240 × 126** (≈ 1.905), burchak radiusi 13
birlik. Panellar orasidagi bo'shliqlar **shaffof**, shuning uchun belgi oq,
krem va to'q fonda bir xil to'g'ri ko'rinadi.

Ikki manba, ikkalasi ham bir xil geometriya:

* **Ilova ichida** — `lib/core/brand/alix_logo.dart` (vektor, `CustomPainter`):
  * `AlixMark` — faqat belgi;
  * `AlixWordmark` — "ALIX" so'z belgisi (katta harf, keng oraliq);
  * `AlixLogo` — gorizontal lockup (AppBar, login);
  * `AlixLogoStacked` — vertikal lockup (splash).
* **Raster fayllar** — `tool/brand/alix_mark.py` (ikonka, splash, favicon).

Ishlatish qoidalari:

* Belgi atrofida kamida belgining balandligicha bo'sh joy qoldiriladi.
* Minimal balandlik: ekranda 16 px, bosmada 5 mm.
* To'q fonda panellar krem rangda (`ON_DARK` / `AlixMark(inkColor: …)`).
* Belgi cho'zilmaydi, ranglari almashtirilmaydi, soya qo'shilmaydi.

## 4. Assetlar va ularni qayta yaratish

Barcha raster fayllar bitta skript bilan generatsiya qilinadi — ular qo'lda
tahrirlanmaydi:

```bash
python3 tool/brand/generate_assets.py
```

Yaratiladigan fayllar:

| Platforma | Fayl |
|---|---|
| Umumiy | `assets/brand/alix_mark.png`, `alix_icon.png` |
| Android | `mipmap-*/ic_launcher.png`, `drawable-*/ic_launcher_foreground.png`, `ic_launcher_monochrome.png` (Android 13 themed icon), `splash_logo.png`, `splash_icon.png` va ularning `drawable-night-*` variantlari |
| iOS | `AppIcon.appiconset/*` (alfa kanalsiz), `LaunchImage.imageset/*` |
| macOS | `AppIcon.appiconset/app_icon_*.png` |
| Web | `favicon.png`, `icons/Icon-{192,512}.png`, maskable variantlari |

Splash konfiguratsiyasi:

* Android ≤ 11 — `drawable/launch_background.xml` (+ `values-night/colors.xml`);
* Android 12+ — `values-v31/styles.xml` va `values-night-v31/styles.xml`;
* iOS — `Base.lproj/LaunchScreen.storyboard` (`LaunchImage`);
* Flutter tomoni — `AlixSplash` (`lib/core/brand/alix_splash.dart`), native
  ekran bilan bir xil kompozitsiya, shuning uchun o'tish sezilmaydi.

## 5. Komponentlar

`lib/core/theme/app_theme.dart` — yagona joy. Asosiy o'lchovlar
`AppPalette` da: karta radiusi 18, tugma 16, chip 12, input 14.

* **Asosiy CTA** — `GradientButton` (to'ldirilgan orange, oq matn, balandlik 52).
* **Ikkilamchi CTA** — `AlixInkButton` (charcoal; to'q rejimda teskarisiga —
  krem plastinka va to'q matn).
* **Uchinchi daraja** — `OutlinedButton` (charcoal chegara).
* **Kartalar** — oq yoki krem (`surfaceContainerHighest`), chegara 1 px.
* **To'q karta** — `AppPalette.inkStrong`, ichida orange progress (tracking).
* **Inputlar** — krem to'ldirish, fokusda orange chegara 1.6 px.

Qayta ishlatiladigan bloklar `lib/core/brand/alix_components.dart` da:

| Komponent | Vazifasi |
|---|---|
| `AlixCard` | Oq / krem / to'q yuzali karta |
| `AlixSectionTitle` | Bo'lim sarlavhasi (kichik, katta harfli) |
| `AlixStatTile` | Raqamli ko'rsatkich kartasi |
| `AlixTrackingCard` | Faol buyurtmaning to'q kartasi (progress + foiz) |
| `AlixStatusChip` | Holat chipi (neutral / progress / success / warning / danger) |
| `AlixEmptyState` | Bo'sh ro'yxat o'rniga keyingi qadam taklifi |
| `AlixBanner` | Ekran tepasidagi xato / ogohlantirish / ma'lumot |
| `AlixTxRow` | Hamyondagi pul harakati qatori |
| `AlixStepHeader` | Ko'p qadamli formada bosqich ko'rsatkichi |
| `AlixUploadRow` | Hujjat / rasm yuklash qatori |

Buyurtma statusining rangi `lib/core/brand/order_status_tone.dart` da —
bitta manba, shuning uchun bir buyurtma ro'yxatda, tafsilotda va haydovchi
ekranida bir xil rangda ko'rinadi.

## 6. Ko'rinish namunalari

`test/brand/` dagi golden rasmlar: splash, login, komponentlar (yorug' va to'q).
Ular odatdagi `flutter test` da o'tkazib yuboriladi (golden'lar platformaga
bog'liq). Yangilash:

```bash
flutter test test/brand --dart-define=brand_previews=true --update-goldens
```
