# EBIC User App — Security & Production-Readiness Audit

Scope: `ebic-user` Flutter app (227 files, ~103k lines), Android + iOS · 2026-10-31
Method: source review of the security core (API client, token storage, payments, network config),
`flutter analyze`, the `mobile-release-check` script (each hit verified by hand), WCAG contrast
computed from theme tokens, and a baseline-vs-branch test comparison. Runtime flows were not
exercised (no backend or test account in this session).

Branch: `chore/production-readiness-audit`. **FIXED** = in that branch.

## Critical

### 01 · Backend payment verification accepts forged signatures — owner action (backend)
`ebic-backend/src/payments/providers/razorpay-payment.provider.ts` → `verifyPayment()` returns
`true` whenever the client sends a signature starting with `sim_`, in any environment:
```ts
if (!configured || paymentId?.startsWith('sim_') || orderId?.startsWith('sim_') || signature?.startsWith('sim_'))
  return isTestMode || Boolean(params.signature?.startsWith('sim_'));
```
`isTestMode` is also true when the client-supplied payment ID starts with `sim_`, and that skips the
amount check later on. Any signed-in user can mark a Health Pass, order or chef booking as paid
without paying. `createPaymentIntent` also silently issues `sim_order_*` sessions in production when
Razorpay's `orders.create` fails.
FIX: in production (`NODE_ENV === 'production'` and no explicit `ALLOW_SIMULATED_PAYMENTS`), never
accept `sim_` IDs or signatures. Derive test mode only from server config, never from request fields.
Fail `createPaymentIntent` instead of simulating.

### 02 · Release builds could silently move all API traffic to a local HTTP port — **FIXED**
`ApiClient._trySwitchToReverseAdbFallback()` ran in release. After the first failed request (for
example a brief loss of signal), it probed `http://127.0.0.1:3000`. If anything answered, it
rewrote `AppConfig.apiBaseUrl` for the session. Any app on the phone can listen on that port and
would then receive every request, bearer token included, over plain HTTP.
FIX: `if (kReleaseMode) return false;`.

### 03 · Release network config allowed cleartext and trusted user-installed CAs — **FIXED**
`network_security_config.xml` had `cleartextTrafficPermitted="true"` plus `<certificates src="user"/>`
in `base-config`, and the manifest had `usesCleartextTraffic="true"`. A certificate installed on the
device could intercept payment and health traffic.
FIX: release config is HTTPS-only with system CAs. The old permissive config moved to
`src/debug/res/xml/` (debug builds only), with a matching debug-manifest override.

## Major

### 04 · Client fabricated payment signatures and fell back to a hard-coded test key — **FIXED**
`RazorpayService` used `rzp_test_Tb32WMsZscKtDf` when the backend sent no key, and generated
`sim_test_signature_*` / `pay_sim_*` values. Five screens did the same (`pass_payment`,
`quote_review`, `renewal`, `payment_checkout`, `order_detail`), and three force-unwrapped `paymentId!`.
FIX: simulation is debug-only. A release checkout with no real `order_…` fails with "You have not
been charged". A missing payment ID shows a clear error instead of crashing, and signatures are
sent as Razorpay returned them. Payment IDs and signatures are no longer logged.

### 05 · Tokens duplicated into plaintext SharedPreferences — **FIXED**
`TokenStorage.saveTokens` wrote the access and refresh tokens to SharedPreferences "in case Android
Keystore resets". The comment called it an "encrypted/fallback copy"; it was not encrypted.
FIX: tokens are written only to secure storage. Legacy plaintext copies are migrated once and deleted.

### 06 · Primary buttons and error text fail contrast (SC 1.4.3) — **FIXED**
```
white on primary #059669   3.77:1  → #047857  5.48:1
danger #EF4444 on white    3.76:1  → #DC2626  4.83:1
```
`test/unit/theme_contrast_test.dart` guards this. It fails on the old palette and passes now.

### 07 · Text size capped at 130% — owner action (SC 1.4.4)
`ResponsiveAppFrame.maxTextScale = 1.3` ignores larger system font settings. There are also 831
font sizes below 12 px. Raise the cap screen by screen after fixing fixed-height layouts.

### 08 · iOS: Health permission string invited rejection — **FIXED**
"This permission is required by the system but is unused." is now an accurate read-only statement.

## Notes
- `slate400` (#94A3B8, 2.56:1 on white) is used 429 times, partly as text. Audit those uses.
- Google Maps key is hard-coded as the `--dart-define` default (`AppConfig.googleMapsApiKey`).
  Restrict it in Google Cloud by package name, SHA-1 and bundle ID, and by API.
- No `PrivacyInfo.xcprivacy` for the app target. Add one in Xcode (UserDefaults reason, tracking = false).
- No `FLAG_SECURE`. Consider it for health and lab screens.
- Lint: 22 → 0 (dead code, an `if (false)` UI block, unused Health Hub strings, unused imports).

## Tests
14 widget/unit tests were **already failing on `main` before this branch**: stale copy assertions
such as "Precision Nutrition", "Skip" and "Payment Summary", the `SessionManager` state tests, and a
font-probe test. The branch introduces no new failures. Fix or delete these so CI can gate releases.

## Release checklist (owner)
1. Fix backend finding 01 — **blocker**.
2. Upload keystore + Play App Signing (`android/key.properties` is missing; release currently
   falls back to the debug key).
3. Repair the 14 failing tests.
4. Play Data safety: health data (Health Connect), location, camera/mic, payments. Health Connect
   needs its declaration form.
5. Bump `version:` for every upload.
