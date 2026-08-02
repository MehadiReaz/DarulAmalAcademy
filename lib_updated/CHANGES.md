# Student app — API alignment changes

Changes made to bring `lib/` in line with the Madrasha **Student API**
collection. Verified with `flutter analyze` (Flutter 3.44.8 / Dart 3.12.2):
no errors or warnings in any file touched below.

Two pre-existing errors remain, in files that were **not** modified:

```
lib/ui/screens/chat/chat_thread_screen.dart:84   FilePicker.pickFiles — static access to instance member
lib/ui/screens/homework/homework_detail_screen.dart:49   same
```

Both look like a `file_picker` version mismatch (`FilePicker.platform.pickFiles`
in v5+), not a logic fault. Worth checking the pinned version in `pubspec.yaml`.

---

## 1. Bug fixes

### Wrong path on today's / upcoming classes
`ApiEndpoints.classesToday` and `classesUpcoming` pointed at
`/student/classes/today` and `/student/classes/upcoming`. The real routes use
the **singular** segment: `/student/class/today`, `/student/class/upcoming`.

Consequences of the old paths:

- `ClassRepository.today()` had been silently rewritten to call
  `/student/my-classes` instead, so "Today's classes" was really "all my
  classes".
- `ClassProvider.liveEndpointsBlocked` was effectively always true, so the
  Classes tab permanently ran in routine-fallback mode.

`today()` now calls the real endpoint and keeps the my-classes call as a
fallback on error, so a genuine server fault still degrades gracefully.

**Files:** `core/constants/api_endpoints.dart`,
`data/repositories/class_repository.dart`, `providers/class_provider.dart`

### Null-unsafe profile photo crashed the Home tab
`home_tab.dart` did `profileImage: user!.profilePhotoUrl!`. A student with no
photo — or any cold start before `GET /auth/student/profile` returns — threw on
that line and blanked the entire Home tab. The header now takes a nullable URL
and falls through to the existing initials avatar; `_MetaChips` also stopped
force-unwrapping `user`.

**File:** `ui/screens/home/home_tab.dart`

### Payment initiate parameter name
The app sends `invoiceId`; the Postman collection sends `id`. Both are sent
until the controller is confirmed — Laravel ignores unexpected keys, so this
works against either validator. **Drop one once confirmed.**

**File:** `data/repositories/fee_repository.dart`

---

## 2. Password login — `POST /auth/login-with-password`

Previously OTP-only. Added:

- `AuthRepository.loginWithPassword({phone, password})` — returns the same
  `AuthSession` as `verifyOtp`, so nothing downstream knows the difference.
- `AuthProvider.loginWithPassword(...)` — stores the token, caches the user,
  flips status. The root gate swaps to the shell on its own.
- `AuthProvider.forgotPassword(...)` — wraps the repo method that already
  existed but had no caller.
- Login screen: a "Sign in with a password instead" toggle, a password field
  with show/hide, and a "Forgot password?" action that posts to
  `/auth/forgot-password` with whatever is in the phone field.

**Files:** `data/repositories/auth_repository.dart`, `providers/auth_provider.dart`,
`ui/screens/auth/login_screen.dart`, `core/constants/api_endpoints.dart`

---

## 3. Notifications — `GET /student/notifications`, `POST /auth/notifications/{id}/read`

Entirely absent before. Added model, repository, provider and screen.

- `AppNotification` parses **both** plausible payloads without a code change:
  Laravel's `DatabaseNotification` (UUID `id`, fields under `data`, `read_at`)
  and a flat resource (`{id, title, message, is_read, created_at}`). Every
  field is looked up at the root first, then inside `data`.
  `id` is a **String** because the notifications table is UUID-keyed, even
  though the Postman example shows `1`.
- `NotificationRepository.list()` accepts a raw paginator, `{notifications:
  [...]}`, a nested paginator, or a bare array.
- Read state is **server-side** here (unlike notices, which are tracked
  locally). Rows flip optimistically and roll back if the request fails, so
  the badge never lies. `markAllRead()` loops sequentially — there is no bulk
  endpoint.
- The header bell now opens the notification centre and shows its real unread
  dot. Unread **notices** moved to a badge on the Notice quick-action tile.
- Tapping a row marks it read and deep-links to homework / notice / fees /
  support when the payload names a target.

**New files:** `data/models/app_notification.dart`,
`data/repositories/notification_repository.dart`,
`providers/notification_provider.dart`,
`ui/screens/notifications/notifications_screen.dart`

---

## 4. My Lessons — `GET /student/my-lessons`

The endpoint constant existed but nothing consumed it.

- `Lesson` reads nested relations (`subject: {name}`) and flattened ones
  (`subject_name`) alike, plus attachment and link fields.
- `LessonRepository.list()` handles bare array / paginator / `{lessons: [...]}`.
- `LessonsScreen` with pull-to-refresh, infinite scroll, and chips that open
  attachments or links externally.
- Reachable from the Home quick-actions grid and the Profile menu.

> This endpoint was returning **500** the last time it was exercised, so the
> parser is written defensively rather than against a confirmed shape.

**New files:** `data/models/lesson.dart`, `data/repositories/lesson_repository.dart`,
`providers/lesson_provider.dart`, `ui/screens/lessons/lessons_screen.dart`

---

## 5. Razorpay checkout URL — `GET /student/fees/pay/webview-url`

Some gateways (Razorpay in particular) answer `/pay/initiate` with a
transaction but no redirect link; the hosted page has to be requested
separately. `FeeRepository.webviewUrl(transactionId)` and
`FeeProvider.checkoutUrl(...)` now provide that, and `PayFeesScreen` falls back
to it before showing "the gateway sent no checkout link".

**Files:** `data/repositories/fee_repository.dart`, `providers/fee_provider.dart`,
`ui/screens/payment/pay_fees_screen.dart`, `core/constants/api_endpoints.dart`

---

## 6. Wiring

- `NotificationProvider` and `LessonProvider` registered in `app.dart`.
- Both `reset()` on logout alongside every other provider in
  `profile_tab.dart` — missing one there leaks the previous student's data
  into the next session.

---

## Open questions

1. **`FeesController@initiate`** — is the validated field `id` or `invoiceId`?
   Sending both is a hedge, not a fix.
2. **Notification controller** — which envelope does it actually return? The
   parser accepts several; pinning it down would let the guessing go.
3. **`/student/my-lessons`** — same question, and its 500 needs a look.
4. **`POST /fees/pay/razorpay/verify`** sits outside the `student/` prefix and
   takes `razorpay_payment_id` / `razorpay_order_id` / `razorpay_signature`.
   If that is the gateway's own server-to-server callback, the app should never
   call it — it currently doesn't. Confirm and it can be removed from the
   collection's student folder.
5. **Notice read state** is still tracked locally (`ReadStateStorage`) because
   `POST /student/notices/{id}/read` doesn't persist. If a `notice_reads` table
   lands, that workaround can be deleted.
