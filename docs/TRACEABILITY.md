# Requirements Traceability Matrix

Seeded from SRS v1.1 (`docs/reference/hotel/SRS-v1.1-Multi-Tenant-Hotel-Platform.md`) and Section 11 of `docs/reference/hotel/skills/multi-tenant-waas/references/hotel-platform-spec.md`.

| Requirement | Phase | Status | Code | Test |
|---|---|---|---|---|
| **FR-01.1** — Immutable UUID (`gen_random_uuid()`) on `Tenant` | Phase 1 | DONE (DB level) | `prisma/schema.prisma`, `prisma/migrations/20261123133438_init/migration.sql` | `tests/db/isolation-and-constraints.test.ts` (`Tenant table` & `catalog check`) |
| **FR-01.2–01.3** — Defaults seeded atomically; status changes effective everywhere ≤ 60 s | Phase 1 | TODO | — | — |
| **FR-01.4** — Reserved subdomains blocked (`www`, `app`, `admin`, `api`, `mail`, `static`, `assets`, `status`, `help`) | Phase 1 | DONE (DB level) | `prisma/migrations/20261123133438_init/migration.sql` (`tenant_slug_not_reserved_chk`) | `tests/db/isolation-and-constraints.test.ts` (`FR-01.4 & FR-02.1: slug CHECK constraints...`) |
| **FR-02.1** — Slug format rules (3–32 chars, no `--` / `xn--`, unique) | Phase 1 | DONE (DB level) | `prisma/schema.prisma`, `prisma/migrations/20261123133438_init/migration.sql` (`tenant_slug_format_chk`) | `tests/db/isolation-and-constraints.test.ts` (`FR-01.4 & FR-02.1: slug CHECK constraints...`) |
| **FR-02.2–02.3** — Branding admin-only and injected from resolved tenant | Phase 1 | TODO | — | — |
| **FR-02.4** — Custom domains served only when VERIFIED; apex/www 308 to canonical; release on removal/termination | Phase 2 | TODO | — | — |
| **FR-03** — JWT has `tid`, `role`, `sv`; URL/token tenant mismatch → 403; MFA for admins; staff invite/revoke ≤ 60 s | Phase 1 | TODO | — | — |
| **FR-04.1–04.2** — Room types + physical rooms; staff maintenance blocks; seasonal pricing resolves most specific override | Phase 1 | TODO | — | — |
| **FR-04.3** — Search by type; auto room assignment; 50 parallel requests for last room → exactly one success | Phase 1 | TODO | — | — |
| **FR-04.4** — Illegal transitions rejected; holds expire and free inventory; guest + front desk notified via outbox | Phase 1 | TODO | — | — |
| **FR-04.6–04.8** — Signed guest links; cancellation policy snapshot applied; booking modification is atomic | Phase 1 | TODO | — | — |
| **FR-05** — Prepay confirms only on verified payment webhook; late payment after expiry handled; refunds follow snapshot | Phase 2 | TODO | — | — |
| **FR-06.1–06.3** — Subscription plans & limits; billing webhooks & 7-day grace period; unified `setTenantStatus` | Phase 2 | TODO | — | — |
| **FR-06.4** — SUSPENDED → storefront 503, guests can still view bookings, staff blocked, admin billing/export only | Phase 1 | TODO | — | — |
| **FR-07** — Hotel time zone and currency respected everywhere; multi-language / RTL support | Phase 1 | TODO | — | — |
| **FR-08** — Immutable audit entries written for all listed actions (append-only `AuditLog` & `BookingEvent`) | Phase 1 | DONE (DB append-only) | `prisma/migrations/20261123133438_init/migration.sql` (`REVOKE UPDATE, DELETE`) | `tests/db/isolation-and-constraints.test.ts` (`NFR-01.1 & FR-08: app_user is denied...`) |
| **FR-09** — CSV/JSON export; data-subject requests; purge after termination window; PII anonymization job | Phase 2 | TODO | — | — |
| **FR-10.2** — Super Admin support access requires reason, time-limited (≤ 1 h), read-only default, audited | Phase 2 | TODO | — | — |
| **NFR-01.1** — Scoped client + forced RLS + non-owner role; catalog & cross-tenant tests pass | Phase 1 | DONE (DB layer) | `docker/postgres/init/01-init.sql`, `prisma/migrations/20261123133438_init/migration.sql` | `tests/db/isolation-and-constraints.test.ts` (`catalog check`, `role safety`, `tenant isolation`, `composite FK`) |
| **NFR-01.2–01.5** — TLS ≥ 1.2; Argon2id; managed secrets; OWASP ASVS L2; PII log masking | Phase 1 | TODO | — | — |
| **NFR-02.3** — Exclusion constraint (`btree_gist`) prevents overlapping active bookings; 50 parallel requests → 1 success | Phase 1 | DONE (DB level) | `prisma/migrations/20261123133438_init/migration.sql` (`no_overlapping_bookings`) | `tests/db/isolation-and-constraints.test.ts` (`exclusion constraint...`, `concurrency — 50 parallel...`) |
| **NFR-02.1–02.2, 02.4** — Resolution ≤ 30 ms p95; LCP target met; search ≤ 500 ms p95 | Phase 1 | TODO | — | — |
| **NFR-03** — Each limiter returns 429 + `Retry-After`; per-tenant quota isolates noisy neighbors | Phase 1 | TODO | — | — |
| **NFR-04 – NFR-08** — Backups/PITR tested, observability/alerts, scale test (1k tenants/50k rooms), compliance, WCAG 2.1 AA | Phase 2 | TODO | — | — |
