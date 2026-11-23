-- Required for booking exclusion constraint (NFR-02.3), including in Prisma shadow DB
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- CreateEnum
CREATE TYPE "TenantStatus" AS ENUM ('ACTIVE', 'SUSPENDED', 'TERMINATED');

-- Required for booking exclusion constraint (NFR-02.3), including in Prisma shadow DB
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- CreateEnum
CREATE TYPE "DomainStatus" AS ENUM ('PENDING', 'VERIFIED', 'FAILED');

-- Required for booking exclusion constraint (NFR-02.3), including in Prisma shadow DB
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- CreateEnum
CREATE TYPE "RoomOpStatus" AS ENUM ('AVAILABLE', 'OCCUPIED', 'MAINTENANCE');

-- Required for booking exclusion constraint (NFR-02.3), including in Prisma shadow DB
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- CreateEnum
CREATE TYPE "BookingKind" AS ENUM ('GUEST', 'BLOCK');

-- Required for booking exclusion constraint (NFR-02.3), including in Prisma shadow DB
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- CreateEnum
CREATE TYPE "BookingStatus" AS ENUM ('PENDING', 'CONFIRMED', 'CHECKED_IN', 'CHECKED_OUT', 'CANCELLED', 'EXPIRED', 'NO_SHOW');

-- Required for booking exclusion constraint (NFR-02.3), including in Prisma shadow DB
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- CreateEnum
CREATE TYPE "PaymentStatus" AS ENUM ('NONE', 'REQUIRES_PAYMENT', 'DEPOSIT_PAID', 'PAID', 'PARTIALLY_REFUNDED', 'REFUNDED');

-- Required for booking exclusion constraint (NFR-02.3), including in Prisma shadow DB
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- CreateEnum
CREATE TYPE "TenantRole" AS ENUM ('TENANT_ADMIN', 'TENANT_STAFF');

-- CreateTable
CREATE TABLE "Tenant" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "name" TEXT NOT NULL,
    "slug" TEXT NOT NULL,
    "status" "TenantStatus" NOT NULL DEFAULT 'ACTIVE',
    "suspendedReason" TEXT,
    "suspendedAt" TIMESTAMP(3),
    "graceEndsAt" TIMESTAMP(3),
    "terminatedAt" TIMESTAMP(3),
    "purgeAfter" TIMESTAMP(3),
    "plan" TEXT NOT NULL DEFAULT 'starter',
    "timezone" TEXT NOT NULL DEFAULT 'UTC',
    "currency" TEXT NOT NULL DEFAULT 'USD',
    "branding" JSONB NOT NULL,
    "sessionVersion" INTEGER NOT NULL DEFAULT 1,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Tenant_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "User" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "email" TEXT NOT NULL,
    "passwordHash" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "disabledAt" TIMESTAMP(3),

    CONSTRAINT "User_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "PlatformAuditLog" (
    "id" TEXT NOT NULL,
    "actor" TEXT NOT NULL,
    "actorId" TEXT,
    "action" TEXT NOT NULL,
    "before" JSONB,
    "after" JSONB,
    "ip" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "PlatformAuditLog_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Domain" (
    "id" TEXT NOT NULL,
    "tenantId" UUID NOT NULL,
    "host" TEXT NOT NULL,
    "isCanonical" BOOLEAN NOT NULL DEFAULT false,
    "status" "DomainStatus" NOT NULL DEFAULT 'PENDING',
    "providerRef" TEXT,
    "verifiedAt" TIMESTAMP(3),
    "expiresAt" TIMESTAMP(3),
    "lastError" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Domain_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "RoomType" (
    "id" TEXT NOT NULL,
    "tenantId" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "bedConfig" TEXT NOT NULL,
    "maxAdults" INTEGER NOT NULL,
    "maxChildren" INTEGER NOT NULL DEFAULT 0,
    "amenities" TEXT[],
    "baseRateMinor" INTEGER NOT NULL,

    CONSTRAINT "RoomType_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Room" (
    "id" TEXT NOT NULL,
    "tenantId" UUID NOT NULL,
    "roomTypeId" TEXT NOT NULL,
    "number" TEXT NOT NULL,
    "opStatus" "RoomOpStatus" NOT NULL DEFAULT 'AVAILABLE',

    CONSTRAINT "Room_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "RateOverride" (
    "id" TEXT NOT NULL,
    "tenantId" UUID NOT NULL,
    "roomTypeId" TEXT NOT NULL,
    "startDate" DATE NOT NULL,
    "endDate" DATE NOT NULL,
    "rateMinor" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "RateOverride_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Booking" (
    "id" TEXT NOT NULL,
    "tenantId" UUID NOT NULL,
    "kind" "BookingKind" NOT NULL DEFAULT 'GUEST',
    "reference" TEXT NOT NULL,
    "roomTypeId" TEXT NOT NULL,
    "roomId" TEXT NOT NULL,
    "checkIn" DATE NOT NULL,
    "checkOut" DATE NOT NULL,
    "adults" INTEGER NOT NULL DEFAULT 1,
    "children" INTEGER NOT NULL DEFAULT 0,
    "status" "BookingStatus" NOT NULL DEFAULT 'PENDING',
    "holdExpiresAt" TIMESTAMP(3),
    "guestName" TEXT,
    "guestEmail" TEXT,
    "guestPhone" TEXT,
    "specialRequests" TEXT,
    "totalMinor" INTEGER NOT NULL DEFAULT 0,
    "currency" TEXT NOT NULL,
    "cancellationPolicy" JSONB,
    "paymentStatus" "PaymentStatus" NOT NULL DEFAULT 'NONE',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Booking_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "BookingEvent" (
    "id" TEXT NOT NULL,
    "tenantId" UUID NOT NULL,
    "bookingId" TEXT NOT NULL,
    "fromStatus" "BookingStatus" NOT NULL,
    "toStatus" "BookingStatus" NOT NULL,
    "actorType" TEXT NOT NULL,
    "actorId" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "BookingEvent_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Membership" (
    "id" TEXT NOT NULL,
    "tenantId" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "role" "TenantRole" NOT NULL,
    "disabledAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Membership_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "StaffInvite" (
    "id" TEXT NOT NULL,
    "tenantId" UUID NOT NULL,
    "email" TEXT NOT NULL,
    "role" "TenantRole" NOT NULL,
    "tokenHash" TEXT NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "usedAt" TIMESTAMP(3),
    "createdByUserId" UUID NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "StaffInvite_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AuditLog" (
    "id" TEXT NOT NULL,
    "tenantId" UUID NOT NULL,
    "action" TEXT NOT NULL,
    "actor" TEXT NOT NULL,
    "actorId" TEXT,
    "before" JSONB,
    "after" JSONB,
    "ip" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "AuditLog_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "OutboxEvent" (
    "id" TEXT NOT NULL,
    "tenantId" UUID NOT NULL,
    "type" TEXT NOT NULL,
    "payload" JSONB NOT NULL,
    "availableAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "processedAt" TIMESTAMP(3),
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "lastError" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "OutboxEvent_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "Tenant_slug_key" ON "Tenant"("slug");

-- CreateIndex
CREATE UNIQUE INDEX "User_email_key" ON "User"("email");

-- CreateIndex
CREATE INDEX "PlatformAuditLog_createdAt_idx" ON "PlatformAuditLog"("createdAt");

-- CreateIndex
CREATE INDEX "Domain_tenantId_idx" ON "Domain"("tenantId");

-- CreateIndex
CREATE INDEX "Domain_host_idx" ON "Domain"("host");

-- CreateIndex
CREATE UNIQUE INDEX "Domain_tenantId_id_key" ON "Domain"("tenantId", "id");

-- CreateIndex
CREATE UNIQUE INDEX "Domain_tenantId_host_key" ON "Domain"("tenantId", "host");

-- CreateIndex
CREATE INDEX "RoomType_tenantId_idx" ON "RoomType"("tenantId");

-- CreateIndex
CREATE UNIQUE INDEX "RoomType_tenantId_id_key" ON "RoomType"("tenantId", "id");

-- CreateIndex
CREATE UNIQUE INDEX "RoomType_tenantId_name_key" ON "RoomType"("tenantId", "name");

-- CreateIndex
CREATE INDEX "Room_tenantId_idx" ON "Room"("tenantId");

-- CreateIndex
CREATE INDEX "Room_tenantId_roomTypeId_idx" ON "Room"("tenantId", "roomTypeId");

-- CreateIndex
CREATE UNIQUE INDEX "Room_tenantId_id_key" ON "Room"("tenantId", "id");

-- CreateIndex
CREATE UNIQUE INDEX "Room_tenantId_number_key" ON "Room"("tenantId", "number");

-- CreateIndex
CREATE INDEX "RateOverride_tenantId_idx" ON "RateOverride"("tenantId");

-- CreateIndex
CREATE INDEX "RateOverride_tenantId_roomTypeId_startDate_endDate_idx" ON "RateOverride"("tenantId", "roomTypeId", "startDate", "endDate");

-- CreateIndex
CREATE UNIQUE INDEX "RateOverride_tenantId_id_key" ON "RateOverride"("tenantId", "id");

-- CreateIndex
CREATE INDEX "Booking_tenantId_idx" ON "Booking"("tenantId");

-- CreateIndex
CREATE INDEX "Booking_tenantId_checkIn_idx" ON "Booking"("tenantId", "checkIn");

-- CreateIndex
CREATE INDEX "Booking_tenantId_checkOut_idx" ON "Booking"("tenantId", "checkOut");

-- CreateIndex
CREATE INDEX "Booking_roomId_idx" ON "Booking"("roomId");

-- CreateIndex
CREATE UNIQUE INDEX "Booking_tenantId_id_key" ON "Booking"("tenantId", "id");

-- CreateIndex
CREATE UNIQUE INDEX "Booking_tenantId_reference_key" ON "Booking"("tenantId", "reference");

-- CreateIndex
CREATE INDEX "BookingEvent_tenantId_idx" ON "BookingEvent"("tenantId");

-- CreateIndex
CREATE INDEX "BookingEvent_tenantId_bookingId_idx" ON "BookingEvent"("tenantId", "bookingId");

-- CreateIndex
CREATE UNIQUE INDEX "BookingEvent_tenantId_id_key" ON "BookingEvent"("tenantId", "id");

-- CreateIndex
CREATE INDEX "Membership_tenantId_idx" ON "Membership"("tenantId");

-- CreateIndex
CREATE INDEX "Membership_userId_idx" ON "Membership"("userId");

-- CreateIndex
CREATE UNIQUE INDEX "Membership_tenantId_id_key" ON "Membership"("tenantId", "id");

-- CreateIndex
CREATE UNIQUE INDEX "Membership_tenantId_userId_key" ON "Membership"("tenantId", "userId");

-- CreateIndex
CREATE UNIQUE INDEX "StaffInvite_tokenHash_key" ON "StaffInvite"("tokenHash");

-- CreateIndex
CREATE INDEX "StaffInvite_tenantId_idx" ON "StaffInvite"("tenantId");

-- CreateIndex
CREATE INDEX "StaffInvite_tenantId_email_idx" ON "StaffInvite"("tenantId", "email");

-- CreateIndex
CREATE UNIQUE INDEX "StaffInvite_tenantId_id_key" ON "StaffInvite"("tenantId", "id");

-- CreateIndex
CREATE INDEX "AuditLog_tenantId_idx" ON "AuditLog"("tenantId");

-- CreateIndex
CREATE INDEX "AuditLog_tenantId_createdAt_idx" ON "AuditLog"("tenantId", "createdAt");

-- CreateIndex
CREATE UNIQUE INDEX "AuditLog_tenantId_id_key" ON "AuditLog"("tenantId", "id");

-- CreateIndex
CREATE INDEX "OutboxEvent_tenantId_idx" ON "OutboxEvent"("tenantId");

-- CreateIndex
CREATE INDEX "OutboxEvent_processedAt_availableAt_idx" ON "OutboxEvent"("processedAt", "availableAt");

-- CreateIndex
CREATE UNIQUE INDEX "OutboxEvent_tenantId_id_key" ON "OutboxEvent"("tenantId", "id");

-- AddForeignKey
ALTER TABLE "Domain" ADD CONSTRAINT "Domain_tenantId_fkey" FOREIGN KEY ("tenantId") REFERENCES "Tenant"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "RoomType" ADD CONSTRAINT "RoomType_tenantId_fkey" FOREIGN KEY ("tenantId") REFERENCES "Tenant"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Room" ADD CONSTRAINT "Room_tenantId_fkey" FOREIGN KEY ("tenantId") REFERENCES "Tenant"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Room" ADD CONSTRAINT "Room_tenantId_roomTypeId_fkey" FOREIGN KEY ("tenantId", "roomTypeId") REFERENCES "RoomType"("tenantId", "id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "RateOverride" ADD CONSTRAINT "RateOverride_tenantId_fkey" FOREIGN KEY ("tenantId") REFERENCES "Tenant"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "RateOverride" ADD CONSTRAINT "RateOverride_tenantId_roomTypeId_fkey" FOREIGN KEY ("tenantId", "roomTypeId") REFERENCES "RoomType"("tenantId", "id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Booking" ADD CONSTRAINT "Booking_tenantId_fkey" FOREIGN KEY ("tenantId") REFERENCES "Tenant"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Booking" ADD CONSTRAINT "Booking_tenantId_roomTypeId_fkey" FOREIGN KEY ("tenantId", "roomTypeId") REFERENCES "RoomType"("tenantId", "id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Booking" ADD CONSTRAINT "Booking_tenantId_roomId_fkey" FOREIGN KEY ("tenantId", "roomId") REFERENCES "Room"("tenantId", "id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "BookingEvent" ADD CONSTRAINT "BookingEvent_tenantId_fkey" FOREIGN KEY ("tenantId") REFERENCES "Tenant"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "BookingEvent" ADD CONSTRAINT "BookingEvent_tenantId_bookingId_fkey" FOREIGN KEY ("tenantId", "bookingId") REFERENCES "Booking"("tenantId", "id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Membership" ADD CONSTRAINT "Membership_tenantId_fkey" FOREIGN KEY ("tenantId") REFERENCES "Tenant"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Membership" ADD CONSTRAINT "Membership_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "StaffInvite" ADD CONSTRAINT "StaffInvite_tenantId_fkey" FOREIGN KEY ("tenantId") REFERENCES "Tenant"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "StaffInvite" ADD CONSTRAINT "StaffInvite_createdByUserId_fkey" FOREIGN KEY ("createdByUserId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AuditLog" ADD CONSTRAINT "AuditLog_tenantId_fkey" FOREIGN KEY ("tenantId") REFERENCES "Tenant"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "OutboxEvent" ADD CONSTRAINT "OutboxEvent_tenantId_fkey" FOREIGN KEY ("tenantId") REFERENCES "Tenant"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- ============================================================================
-- Custom Constraints, Indexes, Forced RLS, and Least-Privilege Grants
-- ============================================================================

-- 1. Tenant slug & currency CHECK constraints (FR-01.4, FR-02.1, FR-07.2)
ALTER TABLE "Tenant"
  ADD CONSTRAINT "tenant_slug_format_chk"
    CHECK ("slug" ~ '^[a-z0-9][a-z0-9-]{1,30}[a-z0-9]$' AND "slug" !~ '--'),
  ADD CONSTRAINT "tenant_slug_not_reserved_chk"
    CHECK ("slug" NOT IN ('www', 'app', 'admin', 'api', 'mail', 'static', 'assets', 'status', 'help')),
  ADD CONSTRAINT "tenant_currency_iso_chk"
    CHECK ("currency" ~ '^[A-Z]{3}$');

-- 2. RateOverride CHECK constraints (FR-04.2)
ALTER TABLE "RateOverride"
  ADD CONSTRAINT "rate_override_dates_valid_chk" CHECK ("endDate" > "startDate"),
  ADD CONSTRAINT "rate_override_non_negative_chk" CHECK ("rateMinor" >= 0);

-- 3. Booking CHECK & exclusion constraints (FR-04.3, FR-04.4.3, NFR-02.3)
ALTER TABLE "Booking"
  ADD CONSTRAINT "booking_dates_valid_chk" CHECK ("checkOut" > "checkIn"),
  ADD CONSTRAINT "booking_adults_min_chk" CHECK ("adults" >= 1),
  ADD CONSTRAINT "booking_children_non_negative_chk" CHECK ("children" >= 0),
  ADD CONSTRAINT "booking_total_non_negative_chk" CHECK ("totalMinor" >= 0),
  ADD CONSTRAINT "booking_pending_requires_hold_chk"
    CHECK ("status" <> 'PENDING' OR "holdExpiresAt" IS NOT NULL),
  ADD CONSTRAINT "booking_guest_requires_contact_chk"
    CHECK ("kind" <> 'GUEST' OR ("guestName" IS NOT NULL AND "guestEmail" IS NOT NULL)),
  ADD CONSTRAINT "no_overlapping_bookings"
    EXCLUDE USING gist (
      "roomId" WITH =,
      daterange("checkIn", "checkOut", '[)') WITH &&
    ) WHERE ("status" IN ('PENDING', 'CONFIRMED', 'CHECKED_IN'));

-- 4. Partial unique index for verified custom domains (FR-02.4.3)
CREATE UNIQUE INDEX "domain_host_verified_uniq" ON "Domain"("host") WHERE "status" = 'VERIFIED';

-- 5. Mandatory forced RLS on all 10 tenant-owned tables (NFR-01.1)
DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'Domain', 'RoomType', 'Room', 'RateOverride', 'Booking',
    'BookingEvent', 'Membership', 'StaffInvite', 'AuditLog', 'OutboxEvent'
  ]
  LOOP
    EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('ALTER TABLE %I FORCE ROW LEVEL SECURITY', t);
    EXECUTE format(
      'CREATE POLICY tenant_isolation ON %I USING ("tenantId" = NULLIF(current_setting(''app.tenant_id'', true), '''')::uuid) WITH CHECK ("tenantId" = NULLIF(current_setting(''app.tenant_id'', true), '''')::uuid)',
      t
    );
  END LOOP;
END $$;

-- 6. Forced RLS on Tenant table (self-scoped by id) (NFR-01.1)
ALTER TABLE "Tenant" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Tenant" FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_self_isolation ON "Tenant"
  USING      ("id" = NULLIF(current_setting('app.tenant_id', true), '')::uuid)
  WITH CHECK ("id" = NULLIF(current_setting('app.tenant_id', true), '')::uuid);

-- 7. Least-privilege grants (tighten init SQL defaults) (FR-08, NFR-01.1)
REVOKE ALL ON "Tenant", "User", "PlatformAuditLog" FROM app_user;
GRANT SELECT ON "Tenant" TO app_user;
GRANT UPDATE ("name", "branding", "timezone", "currency") ON "Tenant" TO app_user;

-- Audit tables are append-only for app_user (FR-08)
REVOKE UPDATE, DELETE ON "AuditLog", "BookingEvent" FROM app_user;

-- Ensure platform_admin retains full access
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO platform_admin;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO platform_admin;
