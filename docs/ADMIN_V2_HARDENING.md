# Admin Console v2 — Production checklist (PR15)

## Deploy targets (alljob1)

| Wave | What | Command sketch |
|------|------|----------------|
| 0 | Indexes | `firebase deploy --only firestore:indexes` — wait READY |
| 1–3 | Shell + RBAC + stats | functions + hosting `alljob1-admin` + rules |
| 4 | Moderation CFs | `adminModerateJob`, `adminSetArtisanFlags`, `adminHideReview`, `adminGetChatTranscript` |
| 5 | Ops | `adminUpdateConfig`, `adminBulkSuspend`, `adminLogExport` + rules `adminConfig` |

```bash
# DNS flaky on some Windows resolvers: prefer Google DNS / IPv6.
set NODE_OPTIONS=--dns-result-order=verbatim
firebase deploy --only functions:adminModerateJob,functions:adminSetArtisanFlags,functions:adminHideReview,functions:adminGetChatTranscript,functions:adminUpdateConfig,functions:adminBulkSuspend,functions:adminLogExport,firestore:rules --project alljob1
flutter build web -t lib/main_admin.dart
firebase deploy --only hosting:alljob1-admin --project alljob1
```

## App Check

- Admin web: enable App Check (reCAPTCHA v3) when ready; callables already Gen2.
- Consumer: separate rollout; do not block admin bootstrap on App Check enforce until keys are live.

## Capability enforce

- `CAP_ASSERT_MODE = "enforce"` in `functions/index.js`.
- Missing roster `capabilities` → `DEFAULT_MODERATOR_CAPABILITIES` (no chats/export/staff/audit/config).
- Sensitive: `chats.read`, `export.run`, `config.manage`, `staff.manage`, `audit.read` are opt-in.

## Smoke tests (superadmin)

1. Login bootstrap email → Özet KPIs load (or rebuild).
2. Kadro: invite / capabilities toggle.
3. İlanlar: hide / unhide; consumer feed hides job.
4. Ustalar: platform onay + gizle; badge on consumer.
5. Yorumlar: hide; disclaimer visible.
6. Şikayet + `chats.read`: transcript only with reportId+chatId.
7. Ayarlar: toggle maintenanceMode → audit `update_config`.
8. Kullanıcılar: select ≤25 bulk suspend; CSV copy without phone; audit `export_run` / `bulk_suspend`.

## Known network note

Local `getaddrinfo ENOTFOUND cloudfunctions.googleapis.com` can occur when A records fail and resolver is unstable. Retry deploy; use alternate DNS (8.8.8.8) if list-functions keeps failing.
