# ADR 0001: Prisma 7 Driver Adapter and Database Roles

- **Status:** Accepted
- **Date:** 2026-11-23
- **Requirements:** NFR-01.1, NFR-01.3

## Context

1. **Prisma 7 Client & Driver Adapter:** Prisma 7.10.1 splits CLI configuration into `prisma7.config.ts` (discovered automatically by `prisma` CLI) and generates the client into `app/generated/prisma` with `provider = "prisma-client"`. Unlike Prisma 5/6, Prisma 7 requires a SQL driver adapter (e.g., `@prisma/adapter-pg`) at runtime rather than a bare `new PrismaClient()` without an adapter. Therefore, the `new PrismaClient()` snippet in `data-isolation.md` §5 must be adapted when implementing `lib/db.ts` in a later prompt.
2. **Database Role Separation:** PostgreSQL Row-Level Security (RLS) is bypassed by superusers, `BYPASSRLS` roles, and table owners unless `FORCE ROW LEVEL SECURITY` is enabled—and even with `FORCE`, using a non-owner role without `BYPASSRLS` provides defense in depth.

## Decision

- **CLI / Migrations (`MIGRATE_DATABASE_URL`):** `prisma7.config.ts` uses `MIGRATE_DATABASE_URL` (role `migrator`), which owns the `hotel` database and `public` schema and holds `CREATEDB` for Prisma's shadow database.
- **Runtime Tenant Code (`DATABASE_URL`):** All tenant-facing server code will connect via `DATABASE_URL` as `app_user` (`NOSUPERUSER`, `NOBYPASSRLS`, non-owner), wrapped by `dbForTenant` / `withTenantTx`.
- **Platform Code (`ADMIN_DATABASE_URL`):** `platform_admin` (`NOSUPERUSER`, `BYPASSRLS`) is restricted strictly to platform-level code (auth, tenant provisioning, billing/DNS webhooks, scheduled purge/expiry jobs, and test/dev seeds).

## Consequences

- `prisma` CLI commands (`migrate`, `validate`, `generate`) never touch `DATABASE_URL` (`app_user`).
- Future runtime DB setup must install `@prisma/adapter-pg` and import the generated client from `@/app/generated/prisma/client`.
- ESLint `no-restricted-imports` will enforce that tenant-facing modules cannot import the `platform_admin` client.
