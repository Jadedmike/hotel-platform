# Multi-Tenant Hotel Platform (SaaS / WaaS)

A cloud-based, multi-tenant hotel management and booking platform built on Next.js App Router, Prisma, and PostgreSQL. Each hotel operates as an autonomous tenant with its own storefront (`{slug}.platform.com` or verified custom domain), room inventory, pricing, branding, and reservations — served by one codebase and one deployment.

## Architecture in One Picture

```text
Request (Host: www.acme.com)
  -> proxy.ts: strip client x-tenant-* headers -> normalize host
  -> resolve tenant from KV (+10 s in-memory cache)        // never Prisma here
  -> unknown host? 404 · non-canonical host? 308 to canonical
  -> SUSPENDED? 503 page (allow-listed guest paths only) · TERMINATED? 410
  -> set x-tenant-id; rewrite pages to /[tenantId]/..., pass /api/* through with header
  -> server code: dbForTenant(tenantId) (app filter) + Postgres RLS (DB filter)
```

## Prerequisites

- **Node.js** 20.19+ / 22.12+ / 24+ (tested on v26)
- **pnpm** 10+
- **Docker Desktop** (for local PostgreSQL 17 and Redis 7)

## Quick Start

```bash
# 1. Install dependencies
pnpm install

# 2. Create local environment file (already created during scaffold; otherwise copy)
cp .env.example .env

# 3. Start PostgreSQL 17 and Redis 7 containers
pnpm db:up

# 4. Verify DB roles (app_user, migrator, platform_admin), btree_gist, and Redis PING
pnpm db:check

# 5. Start the Next.js development server
pnpm dev
```

Open `http://localhost:3000`.

## Useful Scripts

- `pnpm lint` — run ESLint
- `pnpm typecheck` — generate Next.js route types and run `tsc --noEmit`
- `pnpm test` — run Vitest unit/integration tests
- `pnpm format` — format files with Prettier
- `pnpm db:up` / `pnpm db:down` / `pnpm db:reset` — manage local Docker Postgres & Redis
- `pnpm db:check` — verify DB role privileges, `btree_gist` extension, and Redis connectivity

## Delivery Phases

- **Phase 1 (Core Multi-Tenancy, Isolation & Hotel Operations):**
  - `FR-01` (Tenant lifecycle & immutable UUID), `FR-02.1–02.3` (Subdomain slugs & branding), `FR-03` (Auth, RBAC, MFA, revocation), `FR-04` (Inventory, pricing, booking engine, holds, lifecycle, guest self-service), `FR-06.4` (Suspended storefront 503 & read-only guest booking view), `FR-07` (Timezone, currency, i18n), `FR-08` (Immutable audit logging)
  - `NFR-01` (Scoped Prisma client + forced Postgres RLS + non-owner `app_user`), `NFR-02` (Sub-30ms tenant resolution & Postgres exclusion constraint for double-booking prevention), `NFR-03` (Rate limiting & per-tenant quotas)
- **Phase 2 (Custom Domains, Payments, Billing, Lifecycle & Production Hardening):**
  - `FR-02.4` (Custom domains & SSL), `FR-05` (Guest payments & refunds), `FR-06.1–06.3` (Subscription plans & billing webhooks), `FR-09` (Data export, termination purge, PII anonymization), `FR-10.2` (Audited Super Admin support access)
  - `NFR-04` to `NFR-08` (Availability/PITR, observability/alerts, scale targets, compliance/GDPR/PCI, WCAG 2.1 AA)
