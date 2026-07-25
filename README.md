# Darul Amal — Student App (Flutter)

Flutter client wired to the **existing Laravel + Sanctum** endpoints.
State management: **Provider**. **No code generation** — all models use
hand-written `fromJson`.

---

## 1. Setup

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
```

| Where you run | Base URL to use |
|---|---|
| Android emulator | `http://10.0.2.2:8000/api` (default) |
| iOS simulator | `http://127.0.0.1:8000/api` |
| Real device | `http://<your-LAN-ip>:8000/api` |
| Production | `https://api.yourdomain.com/api` |

For **Android cleartext HTTP in development**, add to
`android/app/src/main/AndroidManifest.xml` on the `<application>` tag:
`android:usesCleartextTraffic="true"`.

Also set `minSdkVersion 23` in `android/app/build.gradle` — required by
`flutter_secure_storage`.

---

## 2. Folder structure

```
lib/
├── main.dart                  # entry — builds ApiClient + TokenStorage
├── app.dart                   # MultiProvider + theme + auth gate
│
├── core/
│   ├── config/app_config.dart         # base URL, timeouts
│   ├── constants/api_endpoints.dart   # every path, one place
│   ├── network/
│   │   ├── api_client.dart            # Dio, token header, envelope unwrap, 401 hook
│   │   └── api_exception.dart         # single error type (incl. 422 field errors)
│   ├── storage/token_storage.dart     # secure token + cached profile
│   ├── theme/                         # teal + gold design tokens
│   └── utils/                         # safe JSON readers, formatters
│
├── data/
│   ├── models/                # StudentUser, ClassRoutine, EnrolledCourse,
│   │                          # SupportTicket, TicketReply, Pagination
│   └── repositories/          # AuthRepository, ClassRepository, TicketRepository
│
├── providers/                 # BaseProvider, Auth, Class, Ticket
│
└── ui/
    ├── screens/               # splash, auth, shell, home, classes, support, profile
    └── widgets/               # AppButton, ClassCard, Loading/Error/Empty views
```

**Rule of thumb:** widgets never call repositories, repositories never touch
widgets. Providers are the only bridge.

---

## 3. Endpoints wired

| Endpoint | Repository method |
|---|---|
| `POST /auth/send-otp` | `AuthRepository.sendOtp` |
| `POST /auth/verify-otp` | `AuthRepository.verifyOtp` |
| `GET /auth/student/profile` | `AuthRepository.profile` |
| `PUT /auth/student/profile` | `AuthRepository.updateProfile` |
| `POST /auth/refresh` | `AuthRepository.refresh` |
| `POST /auth/logout` | `AuthRepository.logout` |
| `POST /auth/forgot-password` | `AuthRepository.forgotPassword` |
| `POST /auth/reset-password` | `AuthRepository.resetPassword` |
| `GET /student/my-courses` | `ClassRepository.myCourses` |
| `GET /student/classes/today` | `ClassRepository.today` |
| `GET /student/classes/upcoming` | `ClassRepository.upcoming` |
| `GET /tickets` | `TicketRepository.list` |
| `POST /tickets` | `TicketRepository.create` |
| `GET /tickets/{id}` | `TicketRepository.show` |
| `DELETE /tickets/{id}` | `TicketRepository.delete` |
| `POST /tickets/{id}/reply` | `TicketRepository.reply` *(admin-only server-side)* |

### Response shapes handled

The client unwraps the `ApiResponse` envelope (`{success, message, data}`)
automatically, then reads the specific key each controller uses:

- `verify-otp` → `data.user`, `data.token`
- `student/profile` → `data.user`
- `my-courses` → `data.courses`
- `classes/today` / `classes/upcoming` → **bare array** in `data`
- `tickets` → `data.tickets` + `data.pagination`
- `tickets/{id}` → `data.ticket` + `data.replies`

If your `ApiResponse` trait uses a different envelope, the only file to change
is `_unwrap()` in `core/network/api_client.dart`.

---

## 4. Auth model (important)

Sanctum issues **plain bearer tokens with no refresh-token flow**. So:

- `POST /auth/refresh` needs an already-valid token — it **cannot** rescue an
  expired session. It only rotates the token.
- Therefore the client treats **any 401 as "session over"**: `ApiClient`
  fires `onUnauthorized`, `AuthProvider` clears storage, and `_RootGate`
  swaps to the login screen automatically. No retry loop.
- On launch, `bootstrap()` shows the **cached profile instantly**, then
  revalidates in the background — so the app opens fast and works offline.

---

## 5. Backend notes & issues found

Things worth checking on the Laravel side:

1. **Sunday classes never appear.** `StudentMyClassController@today` uses
   `Carbon::today()->dayOfWeek`, which returns **0 for Sunday** (0–6), but the
   comment and `WEEK_DAYS` assume 1–7 with 7 = Sunday. Use `dayOfWeekIso`
   (1 = Monday … 7 = Sunday) instead.

2. **Ticket routes have no auth middleware.** In `routes/api.php` the
   `tickets` group is not wrapped in `auth:sanctum`. The controller sets it in
   the constructor via `$this->middleware(...)` — that **no longer works in
   Laravel 11+** (the base controller dropped the method). Move it to the
   route group to be safe.

3. **Students can't reply to their own tickets** — `reply()` is admin-only, so
   a ticket is one-way for the student. The method exists in the repository
   for when you open it up.

4. **Edit Profile can't pre-fill.** `updateProfile()` accepts `phone`,
   `address`, `date_of_birth`, `gender`, `blood_group`, but `formatUserData()`
   doesn't return them — so the app can't show current values. Adding them to
   the profile response would fix it; the Flutter model just needs the fields.

5. **OTP is returned in the API response.** Both `PasswordResetController@forgot`
   and `ApiStudentOtpController@send` return the OTP in `data`. Fine for dev,
   but must be gated behind an env check before production — anyone can read it.

6. **`upcoming` includes today.** It loops weekdays 1–7 and keeps recurring
   routines whose weekday is ≤ today, so today's classes also show under
   "Upcoming". Worth excluding today's weekday.

### Endpoints the app still needs

Not yet on the backend, so not wired here: **notices, Qur'an progress,
remarks, fees/payment, recordings, homework, notifications/FCM, join-class
(Zoom)**. When they land, each is one new model + repository method + provider
— the structure won't change.

---

## 6. Adding a new endpoint (the pattern)

1. Add the path to `core/constants/api_endpoints.dart`.
2. Add a model in `data/models/` with a `fromJson` using the safe readers from
   `core/utils/json_utils.dart`.
3. Add a method to the matching repository — unwrap the controller's key.
4. Expose state + a `load…()` on the provider (use `guard()` from
   `BaseProvider` for free loading/error handling).
5. Consume it with `context.watch<…Provider>()` and switch on `LoadState`.