# ADR 0002: Schema and Database Privilege Model

- **Status:** Accepted
- **Date:** 2026-11-23
- **Requirements:** FR-01.1, FR-01.4, FR-02.1, FR-02.4.3, FR-08, NFR-01.1, NFR-02.3

## Context

The hotel platform uses a shared-database, shared-schema multi-tenancy model where PostgreSQL Row-Level Security (RLS) acts as the mandatory second layer of defense behind application-level query scoping. Certain tables, columns, and invariants must be protected even if application code has a bug.

## Decisions

1. **Platform Tables (`Tenant`, `User`, `PlatformAuditLog`):**
   - `User` is a platform-level table (no `tenantId`) because a single person (e.g., a hotel group manager or multi-property staff member) can belong to multiple tenants via the tenant-scoped `Membership` table.
   - `Tenant` is the root entity; `PlatformAuditLog` records Super Admin and platform-wide actions.
   - `app_user` is granted **zero** privileges on `User` and `PlatformAuditLog` so tenant-facing code can never query or mutate global user credentials or platform audit records.
2. **Column-Level `UPDATE` on `Tenant`:**
   - `Tenant` has forced RLS scoped to `id = NULLIF(current_setting('app.tenant_id', true), '')::uuid`, and `app_user` is granted `SELECT` plus column-level `UPDATE ("name", "branding", "timezone", "currency")` only.
   - `app_user` cannot update `status`, `slug`, `plan`, `sessionVersion`, or lifecycle timestamps (`suspendedAt`, `graceEndsAt`, `terminatedAt`, `purgeAfter`). Those columns are mutated exclusively by `platform_admin` via `setTenantStatus` and billing/admin flows.
3. **Database-Level Constraints:**
   - **Exclusion constraint (`no_overlapping_bookings` with `btree_gist`):** Enforces at the database level that no two active bookings (`PENDING`, `CONFIRMED`, `CHECKED_IN`) for the same `roomId` can have overlapping `[checkIn, checkOut)` date ranges, eliminating race conditions under concurrent requests (NFR-02.3).
   - **Composite Foreign Keys `(tenantId, id)`:** Children (`Room`, `RateOverride`, `Booking`, `BookingEvent`) reference parents by `(tenantId, parentId)`, making cross-tenant foreign-key references structurally impossible even for `platform_admin`.
   - **Partial Unique Index (`domain_host_verified_uniq`):** Allows multiple tenants to hold `PENDING` claims on a host while guaranteeing at most one `VERIFIED` owner (FR-02.4.3).
   - **`CHECK` Constraints:** Enforce slug format/reserved-word rules (FR-01.4, FR-02.1), ISO-4217 currency format, non-negative rates/totals, valid date ranges, and booking hold/guest-contact invariants directly in Postgres.
4. **`BookingEvent` Column Naming (`fromStatus` / `toStatus`):**
   - `FROM` and `TO` are reserved SQL keywords. Using `fromStatus` and `toStatus` avoids fragile identifier quoting in raw SQL queries and triggers.

## Consequences

- Tenant-facing code (`app_user`) is structurally incapable of reading `User`/`PlatformAuditLog`, mutating tenant subscription status/plan/slug, or tampering with `AuditLog`/`BookingEvent` (`REVOKE UPDATE, DELETE`).
- All migrations must be written to preserve these raw SQL constraints and grants, and CI runs SQL-level verification tests (`pnpm test:db`) on every push and pull request.
