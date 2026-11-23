import fs from "node:fs";
import path from "node:path";
import { Pool, type PoolClient } from "pg";
import { afterAll, beforeAll, describe, expect, it } from "vitest";

function loadEnvIfNeeded(): void {
  const envPath = path.resolve(process.cwd(), ".env");
  if (!fs.existsSync(envPath)) return;
  const content = fs.readFileSync(envPath, "utf8");
  for (const rawLine of content.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith("#")) continue;
    const eqIdx = line.indexOf("=");
    if (eqIdx === -1) continue;
    const key = line.slice(0, eqIdx).trim();
    let val = line.slice(eqIdx + 1).trim();
    if (
      (val.startsWith('"') && val.endsWith('"')) ||
      (val.startsWith("'") && val.endsWith("'"))
    ) {
      val = val.slice(1, -1);
    }
    if (!(key in process.env)) {
      process.env[key] = val;
    }
  }
}

loadEnvIfNeeded();

const EXPECTED_TENANT_TABLES = [
  "AuditLog",
  "Booking",
  "BookingEvent",
  "Domain",
  "Membership",
  "OutboxEvent",
  "RateOverride",
  "Room",
  "RoomType",
  "StaffInvite",
].sort();

let appPool: Pool;
let adminPool: Pool;
let migratePool: Pool;

let tenantAId: string;
let tenantBId: string;
let roomTypeAId: string;
let roomTypeBId: string;
let roomAId: string;
let roomA2Id: string;
let roomBId: string;
let bookingAId: string;
let bookingBId: string;

async function withTenant<T>(
  pool: Pool,
  tenantId: string | null,
  fn: (client: PoolClient) => Promise<T>,
): Promise<T> {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    if (tenantId !== null) {
      await client.query("SELECT set_config('app.tenant_id', $1, true)", [tenantId]);
    }
    const res = await fn(client);
    await client.query("COMMIT");
    return res;
  } catch (err) {
    await client.query("ROLLBACK").catch(() => {});
    throw err;
  } finally {
    client.release();
  }
}

function pgCode(err: unknown): string | undefined {
  return (err as { code?: string })?.code;
}

describe("Database isolation, privileges, and constraints", () => {
  beforeAll(async () => {
    appPool = new Pool({ connectionString: process.env.DATABASE_URL, max: 55 });
    adminPool = new Pool({ connectionString: process.env.ADMIN_DATABASE_URL, max: 5 });
    migratePool = new Pool({ connectionString: process.env.MIGRATE_DATABASE_URL, max: 2 });

    // Clean any leftover test tenants from prior interrupted runs
    await adminPool.query(
      `DELETE FROM "Tenant" WHERE "slug" IN ('test-hotel-a', 'test-hotel-b', 'grand-hotel')`,
    );

    const tA = await adminPool.query<{ id: string }>(
      `INSERT INTO "Tenant" ("name", "slug", "branding")
       VALUES ('Hotel Alpha', 'test-hotel-a', '{"primary":"#111111"}')
       RETURNING "id"`,
    );
    const tB = await adminPool.query<{ id: string }>(
      `INSERT INTO "Tenant" ("name", "slug", "branding")
       VALUES ('Hotel Beta', 'test-hotel-b', '{"primary":"#222222"}')
       RETURNING "id"`,
    );
    tenantAId = tA.rows[0]!.id;
    tenantBId = tB.rows[0]!.id;

    roomTypeAId = "rt_test_a";
    roomTypeBId = "rt_test_b";
    roomAId = "room_test_a1";
    roomA2Id = "room_test_a2";
    roomBId = "room_test_b1";
    bookingAId = "bkg_test_a1";
    bookingBId = "bkg_test_b1";

    await adminPool.query(
      `INSERT INTO "RoomType" ("id", "tenantId", "name", "bedConfig", "maxAdults", "amenities", "baseRateMinor")
       VALUES ($1, $2, 'Deluxe', '1 King', 2, ARRAY['wifi'], 15000),
              ($3, $4, 'Deluxe', '1 King', 2, ARRAY['wifi'], 18000)`,
      [roomTypeAId, tenantAId, roomTypeBId, tenantBId],
    );

    await adminPool.query(
      `INSERT INTO "Room" ("id", "tenantId", "roomTypeId", "number")
       VALUES ($1, $2, $3, '101'),
              ($4, $2, $3, '102'),
              ($5, $6, $7, '101')`,
      [roomAId, tenantAId, roomTypeAId, roomA2Id, roomBId, tenantBId, roomTypeBId],
    );

    await adminPool.query(
      `INSERT INTO "Booking" (
         "id", "tenantId", "kind", "reference", "roomTypeId", "roomId",
         "checkIn", "checkOut", "status", "guestName", "guestEmail", "totalMinor", "currency", "updatedAt"
       ) VALUES (
         $1, $2, 'GUEST', 'REF-A1', $3, $4,
         '2026-12-01', '2026-12-05', 'CONFIRMED', 'Alice', 'alice@example.com', 60000, 'USD', now()
       ), (
         $5, $6, 'GUEST', 'REF-B1', $7, $8,
         '2026-12-01', '2026-12-05', 'CONFIRMED', 'Bob', 'bob@example.com', 72000, 'USD', now()
       )`,
      [bookingAId, tenantAId, roomTypeAId, roomAId, bookingBId, tenantBId, roomTypeBId, roomBId],
    );
  });

  afterAll(async () => {
    if (adminPool) {
      await adminPool
        .query(`DELETE FROM "Tenant" WHERE "slug" IN ('test-hotel-a', 'test-hotel-b', 'grand-hotel')`)
        .catch(() => {});
    }
    await Promise.all([
      appPool?.end().catch(() => {}),
      adminPool?.end().catch(() => {}),
      migratePool?.end().catch(() => {}),
    ]);
  });

  it("NFR-01.1: catalog check — every tenantId table and Tenant have forced RLS and policy", async () => {
    const res = await adminPool.query<{
      relname: string;
      relrowsecurity: boolean;
      relforcerowsecurity: boolean;
      has_policy: boolean;
    }>(`
      SELECT c.relname, c.relrowsecurity, c.relforcerowsecurity,
             EXISTS (SELECT 1 FROM pg_policies p WHERE p.tablename = c.relname) AS has_policy
      FROM pg_class c
      JOIN information_schema.columns col
        ON col.table_name = c.relname AND col.column_name = 'tenantId'
      WHERE c.relkind = 'r' AND col.table_schema = 'public'
      ORDER BY c.relname
    `);

    const tableNames = res.rows.map((r) => r.relname).sort();
    expect(tableNames).toEqual(EXPECTED_TENANT_TABLES);
    for (const row of res.rows) {
      expect(row.relrowsecurity, `${row.relname} relrowsecurity`).toBe(true);
      expect(row.relforcerowsecurity, `${row.relname} relforcerowsecurity`).toBe(true);
      expect(row.has_policy, `${row.relname} has_policy`).toBe(true);
    }

    const tenantRes = await adminPool.query<{
      relrowsecurity: boolean;
      relforcerowsecurity: boolean;
      has_policy: boolean;
    }>(`
      SELECT c.relrowsecurity, c.relforcerowsecurity,
             EXISTS (SELECT 1 FROM pg_policies p WHERE p.tablename = c.relname) AS has_policy
      FROM pg_class c
      WHERE c.relname = 'Tenant' AND c.relkind = 'r'
    `);
    expect(tenantRes.rows[0]).toEqual({
      relrowsecurity: true,
      relforcerowsecurity: true,
      has_policy: true,
    });
  });

  it("NFR-01.1: role safety — app_user is non-owner, non-super, and NOBYPASSRLS", async () => {
    const roleRes = await appPool.query<{ rolbypassrls: boolean; rolsuper: boolean }>(
      `SELECT rolbypassrls, rolsuper FROM pg_roles WHERE rolname = current_user`,
    );
    expect(roleRes.rows[0]).toEqual({ rolbypassrls: false, rolsuper: false });

    const ownRes = await appPool.query<{ cnt: number }>(
      `SELECT count(*)::int AS cnt FROM pg_tables WHERE tableowner = current_user AND schemaname = 'public'`,
    );
    expect(ownRes.rows[0]?.cnt).toBe(0);
  });

  it("NFR-01.1: tenant isolation — app_user scoped to A sees only A, cannot mutate/insert B, fails closed, and does not leak across transactions", async () => {
    await withTenant(appPool, tenantAId, async (c) => {
      const bookings = await c.query<{ id: string; tenantId: string }>(
        `SELECT "id", "tenantId" FROM "Booking"`,
      );
      expect(bookings.rows.map((r) => r.tenantId)).toEqual([tenantAId]);

      const rooms = await c.query<{ tenantId: string }>(`SELECT "tenantId" FROM "Room"`);
      expect(rooms.rows.every((r) => r.tenantId === tenantAId)).toBe(true);
      expect(rooms.rows.length).toBe(2);

      const roomTypes = await c.query<{ tenantId: string }>(`SELECT "tenantId" FROM "RoomType"`);
      expect(roomTypes.rows.map((r) => r.tenantId)).toEqual([tenantAId]);

      const updB = await c.query(`UPDATE "Booking" SET "guestName" = 'Hacked' WHERE "id" = $1`, [
        bookingBId,
      ]);
      expect(updB.rowCount).toBe(0);

      const delB = await c.query(`DELETE FROM "Booking" WHERE "id" = $1`, [bookingBId]);
      expect(delB.rowCount).toBe(0);

      await expect(
        c.query(
          `INSERT INTO "RoomType" ("id", "tenantId", "name", "bedConfig", "maxAdults", "amenities", "baseRateMinor")
           VALUES ('rt_evil', $1, 'Evil', '1 King', 2, ARRAY[]::text[], 1000)`,
          [tenantBId],
        ),
      ).rejects.toMatchObject({ code: "42501" });
    });

    // Fail closed with no setting
    await withTenant(appPool, null, async (c) => {
      const res = await c.query(`SELECT "id" FROM "Booking"`);
      expect(res.rowCount).toBe(0);
    });

    // Fail closed with empty string ''
    await withTenant(appPool, "", async (c) => {
      const res = await c.query(`SELECT "id" FROM "Booking"`);
      expect(res.rowCount).toBe(0);
    });

    // Does not leak to next transaction on the exact same connection
    const conn = await appPool.connect();
    try {
      await conn.query("BEGIN");
      await conn.query("SELECT set_config('app.tenant_id', $1, true)", [tenantAId]);
      const r1 = await conn.query(`SELECT "id" FROM "Booking"`);
      expect(r1.rowCount).toBe(1);
      await conn.query("COMMIT");

      await conn.query("BEGIN");
      const r2 = await conn.query(`SELECT "id" FROM "Booking"`);
      expect(r2.rowCount).toBe(0);
      await conn.query("COMMIT");
    } finally {
      conn.release();
    }
  });

  it("NFR-01.1 & FR-02.2: Tenant table — app_user sees only A, can update branding, cannot update status/slug/plan/sessionVersion or B", async () => {
    await withTenant(appPool, tenantAId, async (c) => {
      const rows = await c.query<{ id: string }>(`SELECT "id" FROM "Tenant"`);
      expect(rows.rows.map((r) => r.id)).toEqual([tenantAId]);

      const updBranding = await c.query(
        `UPDATE "Tenant" SET "branding" = '{"primary":"#abcdef"}'::jsonb WHERE "id" = $1`,
        [tenantAId],
      );
      expect(updBranding.rowCount).toBe(1);

      const updB = await c.query(
        `UPDATE "Tenant" SET "branding" = '{"primary":"#000000"}'::jsonb WHERE "id" = $1`,
        [tenantBId],
      );
      expect(updB.rowCount).toBe(0);
    });

    for (const colSql of [
      `"status" = 'SUSPENDED'`,
      `"slug" = 'hijacked-slug'`,
      `"plan" = 'enterprise'`,
      `"sessionVersion" = 999`,
    ]) {
      await expect(
        withTenant(appPool, tenantAId, (c) =>
          c.query(`UPDATE "Tenant" SET ${colSql} WHERE "id" = $1`, [tenantAId]),
        ),
      ).rejects.toMatchObject({ code: "42501" });
    }
  });

  it("NFR-01.1 & FR-08: app_user is denied on User/PlatformAuditLog and UPDATE/DELETE on AuditLog/BookingEvent", async () => {
    await expect(
      withTenant(appPool, tenantAId, (c) => c.query(`SELECT * FROM "User"`)),
    ).rejects.toMatchObject({ code: "42501" });

    await expect(
      withTenant(appPool, tenantAId, (c) => c.query(`SELECT * FROM "PlatformAuditLog"`)),
    ).rejects.toMatchObject({ code: "42501" });

    await expect(
      withTenant(appPool, tenantAId, (c) =>
        c.query(`UPDATE "AuditLog" SET "action" = 'tamper'`),
      ),
    ).rejects.toMatchObject({ code: "42501" });

    await expect(
      withTenant(appPool, tenantAId, (c) => c.query(`DELETE FROM "AuditLog"`)),
    ).rejects.toMatchObject({ code: "42501" });

    await expect(
      withTenant(appPool, tenantAId, (c) =>
        c.query(`UPDATE "BookingEvent" SET "actorType" = 'tamper'`),
      ),
    ).rejects.toMatchObject({ code: "42501" });

    await expect(
      withTenant(appPool, tenantAId, (c) => c.query(`DELETE FROM "BookingEvent"`)),
    ).rejects.toMatchObject({ code: "42501" });
  });

  it("NFR-02.3: exclusion constraint rejects overlapping CONFIRMED, allows back-to-back and CANCELLED/EXPIRED/NO_SHOW", async () => {
    await withTenant(appPool, tenantAId, async (c) => {
      // Overlapping CONFIRMED -> 23P01
      await expect(
        c.query(
          `INSERT INTO "Booking" (
             "id", "tenantId", "kind", "reference", "roomTypeId", "roomId",
             "checkIn", "checkOut", "status", "guestName", "guestEmail", "totalMinor", "currency", "updatedAt"
           ) VALUES (
             'bkg_overlap', $1, 'GUEST', 'REF-OVL', $2, $3,
             '2026-12-03', '2026-12-07', 'CONFIRMED', 'Carl', 'carl@example.com', 60000, 'USD', now()
           )`,
          [tenantAId, roomTypeAId, roomAId],
        ),
      ).rejects.toMatchObject({ code: "23P01" });
    });

    // Back-to-back (checkIn = 2026-12-05 == previous checkOut) -> succeeds
    await withTenant(appPool, tenantAId, async (c) => {
      await c.query(
        `INSERT INTO "Booking" (
           "id", "tenantId", "kind", "reference", "roomTypeId", "roomId",
           "checkIn", "checkOut", "status", "guestName", "guestEmail", "totalMinor", "currency", "updatedAt"
         ) VALUES (
           'bkg_b2b', $1, 'GUEST', 'REF-B2B', $2, $3,
           '2026-12-05', '2026-12-08', 'CONFIRMED', 'Dana', 'dana@example.com', 45000, 'USD', now()
         )`,
        [tenantAId, roomTypeAId, roomAId],
      );

      // Overlapping CANCELLED, EXPIRED, NO_SHOW -> all allowed
      for (const [idx, st] of ["CANCELLED", "EXPIRED", "NO_SHOW"].entries()) {
        await c.query(
          `INSERT INTO "Booking" (
             "id", "tenantId", "kind", "reference", "roomTypeId", "roomId",
             "checkIn", "checkOut", "status", "guestName", "guestEmail", "totalMinor", "currency", "updatedAt"
           ) VALUES (
             $1, $2, 'GUEST', $3, $4, $5,
             '2026-12-01', '2026-12-05', $6, 'Eve', 'eve@example.com', 45000, 'USD', now()
           )`,
          [`bkg_inactive_${idx}`, tenantAId, `REF-INACT-${idx}`, roomTypeAId, roomAId, st],
        );
      }
    });
  });

  it("NFR-02.3: concurrency — 50 parallel transactions for the same room & dates yield exactly 1 success and 49 23P01 failures", async () => {
    const attempts = Array.from({ length: 50 }, (_, i) =>
      withTenant(appPool, tenantAId, async (c) => {
        await c.query(
          `INSERT INTO "Booking" (
             "id", "tenantId", "kind", "reference", "roomTypeId", "roomId",
             "checkIn", "checkOut", "status", "guestName", "guestEmail", "totalMinor", "currency", "updatedAt"
           ) VALUES (
             $1, $2, 'GUEST', $3, $4, $5,
             '2027-01-10', '2027-01-12', 'CONFIRMED', 'Guest', 'guest@example.com', 30000, 'USD', now()
           )`,
          [`bkg_race_${i}`, tenantAId, `REF-RACE-${i}`, roomTypeAId, roomA2Id],
        );
      }),
    );

    const results = await Promise.allSettled(attempts);
    const successes = results.filter((r) => r.status === "fulfilled");
    const failures = results.filter((r) => r.status === "rejected");

    expect(successes).toHaveLength(1);
    expect(failures).toHaveLength(49);
    for (const f of failures) {
      expect(pgCode((f as PromiseRejectedResult).reason)).toBe("23P01");
    }
  });

  it("NFR-01.1: composite FK rejects Booking of tenant A pointing at Room of tenant B", async () => {
    await expect(
      adminPool.query(
        `INSERT INTO "Booking" (
           "id", "tenantId", "kind", "reference", "roomTypeId", "roomId",
           "checkIn", "checkOut", "status", "guestName", "guestEmail", "totalMinor", "currency", "updatedAt"
         ) VALUES (
           'bkg_cross_fk', $1, 'GUEST', 'REF-XFK', $2, $3,
           '2027-02-01', '2027-02-03', 'CONFIRMED', 'Mallory', 'm@example.com', 30000, 'USD', now()
         )`,
        [tenantAId, roomTypeAId, roomBId],
      ),
    ).rejects.toMatchObject({ code: "23503" });
  });

  it("FR-01.4 & FR-02.1: slug CHECK constraints reject invalid/reserved slugs and accept 'grand-hotel'", async () => {
    const badSlugs = ["xn--abc", "a--b", "www", "ab", "Acme", "-acme", "acme-", "a.b"];
    for (const bad of badSlugs) {
      await expect(
        adminPool.query(
          `INSERT INTO "Tenant" ("name", "slug", "branding") VALUES ('Bad', $1, '{}'::jsonb)`,
          [bad],
        ),
      ).rejects.toMatchObject({ code: "23514" });
    }

    const ok = await adminPool.query<{ slug: string }>(
      `INSERT INTO "Tenant" ("name", "slug", "branding") VALUES ('Grand', 'grand-hotel', '{}'::jsonb) RETURNING "slug"`,
    );
    expect(ok.rows[0]?.slug).toBe("grand-hotel");
  });

  it("FR-02.4.3: Domain allows two PENDING rows with same host, rejects two VERIFIED rows with same host", async () => {
    await adminPool.query(
      `INSERT INTO "Domain" ("id", "tenantId", "host", "status")
       VALUES ('dom_p1', $1, 'pending.example.com', 'PENDING'),
              ('dom_p2', $2, 'pending.example.com', 'PENDING')`,
      [tenantAId, tenantBId],
    );

    await adminPool.query(
      `INSERT INTO "Domain" ("id", "tenantId", "host", "status", "verifiedAt")
       VALUES ('dom_v1', $1, 'verified.example.com', 'VERIFIED', now())`,
      [tenantAId],
    );

    await expect(
      adminPool.query(
        `INSERT INTO "Domain" ("id", "tenantId", "host", "status", "verifiedAt")
         VALUES ('dom_v2', $1, 'verified.example.com', 'VERIFIED', now())`,
        [tenantBId],
      ),
    ).rejects.toMatchObject({ code: "23505" });
  });
});
