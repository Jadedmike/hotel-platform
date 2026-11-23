# Requirements Traceability Matrix

Seeded from SRS v1.1 (`docs/reference/hotel/SRS-v1.1-Multi-Tenant-Hotel-Platform.md`) and Section 11 of `docs/reference/hotel/skills/multi-tenant-waas/references/hotel-platform-spec.md`.

| Requirement | Phase | Status | Code | Test |
|---|---|---|---|---|
| **FR-01** — Immutable UUID; defaults seeded atomically; status changes effective everywhere ≤ 60 s; reserved subdomains blocked | Phase 1 | TODO | — | — |
| **FR-02.1–02.3** — Slug rules (no `--`), unique; branding admin-only and injected from resolved tenant | Phase 1 | TODO | — | — |
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
| **FR-08** — Immutable audit entries written for all listed actions; tenant & platform audit views | Phase 1 | TODO | — | — |
| **FR-09** — CSV/JSON export; data-subject requests; purge after termination window; PII anonymization job | Phase 2 | TODO | — | — |
| **FR-10.2** — Super Admin support access requires reason, time-limited (≤ 1 h), read-only default, audited | Phase 2 | TODO | — | — |
| **NFR-01** — Scoped client + forced RLS + non-owner role; catalog & cross-tenant tests pass; TLS ≥ 1.2; Argon2id | Phase 1 | TODO | — | — |
| **NFR-02** — Resolution ≤ 30 ms p95; LCP target met; exclusion constraint (`btree_gist`) in place; search ≤ 500 ms p95 | Phase 1 | TODO | — | — |
| **NFR-03** — Each limiter returns 429 + `Retry-After`; per-tenant quota isolates noisy neighbors | Phase 1 | TODO | — | — |
| **NFR-04 – NFR-08** — Backups/PITR tested, observability/alerts, scale test (1k tenants/50k rooms), compliance, WCAG 2.1 AA | Phase 2 | TODO | — | — |
