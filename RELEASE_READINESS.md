# ALIX Logistics — Release-Readiness Report

**Audit date:** 2026-05-21
**Scope:** Flutter mobile app (`com.example.mening_ilovam`) + Laravel 13 backend (`/Applications/my_projects/logistic`)
**Test platform:** Android emulator-5554 (1080×2400)
**Out of scope (per user constraint):** admin panel — untouched

---

## 1. Executive summary

End-to-end testing covered all three actor roles (Customer / Driver / Corporate-staff customer / Fleet-driver) across the full order lifecycle: registration → OTP → order creation → wallet payment → driver acceptance → status transitions → settlement → archive. Every wallet split (driver / avtopark / app commission / B2B billing) was verified both at the database layer and on the actual mobile UI.

**Verdict:** **READY for release** subject to the open items in §5.

---

## 2. Verified flows

### 2.1 Customer (personal) — Task #85
- OTP login → order creation → pay-from-wallet → driver pickup → completion → wallet history.
- Personal wallet debit (`owner_type=2`) verified.
- Final UI Hamyon balance matches DB to the kopeck.

### 2.2 Driver lifecycle — Task #86
Status machine driven through `1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9 → 10` and again `→ 10` from customer side:
- `arrived-pickup`, `loading-start`, `in-transit`, `arrived-delivery`, `delivered` all transition correctly via `UpdateOrderStatusByDriverAction`.
- `restoreDriverOnline()` re-enables driver feed after `Completed`.

### 2.3 Cancel + refund — Task #87
- Customer cancel before `Active` → 100% refund to billing wallet.
- Driver cancel after acceptance → escrow released, no settlement credited.
- `cancelled_by` audit column populated (1=customer, 2=driver).

### 2.4 Scheduled order + 1+1 limit — Task #88, #93
- Driver may hold **1 in-progress** + **1 future-scheduled Accepted** simultaneously.
- `CargoPreferencesController::set` correctly excludes `Accepted` with `scheduled_pickup_at > now()` from the "active" blocker (split via `ACTIVE_IN_PROGRESS_STATUSES` constant + dedicated `Accepted`-future branch).
- Bug fixed: previously a future-scheduled Accepted blocked online-toggle.

### 2.5 B2B staff + fleet driver — Task #89 ✓ closed today

| Wallet | Before | After | Δ | Tx |
|---|---:|---:|---:|---|
| `32` CustomerCompany #6 (ABC Trading LLC) | 19,876,540 / 223,460 blk | **19,776,540** / **123,460** blk | −100K, escrow released | #100 type=2 |
| `25` Avtopark #5 (MegaTrans) | 118,787 | **213,787** | +95,000 | #101 +90K + #102 +5K |
| `4`  App                  | 100,415.50 | **105,415.50** | +5,000 | #103 |
| `16` Driver #8 personal     | 10 | 10 | 0 (fleet skip) | — |
| `31` Customer #13 personal  | 9,970,000 | 9,970,000 | 0 (staff personal untouched) | — |

UI confirmed on emulator:
- Home `Hamyon` card → `19 776 540 UZS`.
- Hamyon tab → corporate badge "Korporativ", header "Kompaniya hamyoni — ABC Trading LLC", footer "Hamyonni faqat administrator to'ldira oladi".
- Tx list shows `Order payment (korporativ — staff user_id=32) Buyurtma #42 −100 000` plus prior staff orders (#37/#19/#34) all correctly tagged.
- `Joriy/Arxiv` counters refresh correctly (Arxiv 3→4 after settle).

### 2.6 i18n round-trip — Task #90
- Russian ↔ Uzbek toggle on Profile screen is **instant across the whole app** (single `ChangeNotifier` flip).
- Verified every label flips: Профиль/Profil, Заказчик/Buyurtmachi, Сессия активна/Sessiya faol, Аккаунт подтверждён/Hisob tasdiqlangan, Тёмный режим/Tungi rejim, Включено/Yoqilgan, Безопасность/Xavfsizlik, Помощь/Yordam, Выйти/Chiqish, plus the 4 bottom-nav items on every tab.
- Locale picker uses native endonyms `O'zbekcha / Русский` (no English fallback).

### 2.7 Polish bugs — Tasks #83, #84, #91
- **#83** Profile "Customer" string now localized (was hard-coded English on toggle).
- **#84** Wallet transaction amount now colored (green credit / red debit) for legibility.
- **#91** Logout button gets a confirmation dialog (was firing on first tap).

### 2.8 Manual long-running settlement — Task #92
- Order #34 driven through full lifecycle independently to validate `SettleOrderPaymentAction` end-to-end against a non-test order. Splits matched config snapshots stored on the order row (`project_commission_pct`, `company_commission_pct`, `driver_income_amount`).

---

## 3. Backend invariants (verified at code level)

1. **Auth model** — bearer token IS the refresh token; `AuthenticateWithRefreshToken` middleware resolves user from `refresh_tokens` table (single-token model, no separate access token).
2. **B2B billing routing** — `ResolveCustomerBillingWalletAction`:
   - `is_company_staff=false` → personal wallet (`owner_type=2`).
   - `is_company_staff=true` + valid `company_id` + `companies.type=2` + `is_active=true` → CustomerCompany wallet (`owner_type=5`).
   - Any inconsistency throws `conflict` rather than silent fallback.
3. **Settlement splits** — `SettleOrderPaymentAction`:
   - Fleet driver (`driver_added_by_company=true` + `company_id`) → income goes to Avtopark wallet, not personal.
   - Avtopark commission booked as **separate** tx (audit clarity).
   - App commission → App wallet (`3,1`).
   - Customer billing wallet `blocked_amount` released (balance already debited at pay time).
4. **Driver online gate** — `Accepted` with future `scheduled_pickup_at` does NOT block going online; only present/past Accepted + the six "in-flight" statuses do.
5. **Snapshot fields** — `project_commission_pct`, `company_commission_pct`, `project_commission_amount`, `company_commission_amount`, `driver_income_amount` written to `orders` row at settle time for downstream reporting.

---

## 4. End-state DB snapshot (post-test)

```
orders by status:
  Pending(1)   = 4
  Active(2)    = 2
  Accepted(3)  = 3
  Completed(10) = 22
  Cancelled(11) =  8
  Total        = 39
```

Wallets touched by tests are consistent (balance + blocked_amount sum across system matches order-pipeline state).

---

## 5. Open items / known limitations

| # | Item | Severity | Action |
|---|---|---|---|
| O1 | Admin panel untouched (per user constraint) | n/a | Out of scope — separate task |
| O2 | Push notifications: scaffold present, FCM credentials not wired | medium | Add `google-services.json`; needs admin/devops |
| O3 | iOS build not exercised (emulator was Android only) | medium | Run smoke on iOS simulator before TestFlight |
| O4 | Geolocation background tracking permission rationale text not localized in one path | low | One string in `lang/uz` / `lang/ru` |
| O5 | Cleartext HTTP enabled in manifest for staging (`usesCleartextTraffic=true`) | medium | Disable for production build; backend is HTTPS-ready |

---

## 6. Pre-release checklist

- [x] All authored E2E flows pass (Tasks #85–#93)
- [x] No FATAL/ERROR in `adb logcat` during full lifecycle
- [x] DB invariants hold post-settlement
- [x] i18n hot-flip verified on every screen
- [x] All known UI polish bugs (#83, #84, #91) fixed
- [ ] Disable `usesCleartextTraffic` and point to production HTTPS endpoint
- [ ] Bump `versionCode`/`versionName` in `android/app/build.gradle`
- [ ] iOS smoke test
- [ ] FCM credentials added (or push feature gated off for first release)
- [ ] Generate signed AAB and upload to internal testing track

---

*Generated from session E2E run; backend code paths cross-referenced. Admin panel intentionally not modified.*
