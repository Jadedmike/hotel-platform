import fs from "node:fs";
import net from "node:net";
import path from "node:path";
import { Client } from "pg";

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

let failures = 0;

function report(name: string, ok: boolean, detail?: string): void {
  const tag = ok ? "PASS" : "FAIL";
  const suffix = detail ? ` (${detail})` : "";
  console.log(`[${tag}] ${name}${suffix}`);
  if (!ok) failures += 1;
}

async function checkPostgres(): Promise<void> {
  const appUrl = process.env.DATABASE_URL;
  const adminUrl = process.env.ADMIN_DATABASE_URL;
  const migrateUrl = process.env.MIGRATE_DATABASE_URL;

  if (!appUrl || !adminUrl || !migrateUrl) {
    report(
      "env: DATABASE_URL, ADMIN_DATABASE_URL, MIGRATE_DATABASE_URL set",
      false,
      "missing one or more connection strings",
    );
    return;
  }

  // 1. app_user checks
  const appClient = new Client({ connectionString: appUrl });
  try {
    await appClient.connect();
    const roleRes = await appClient.query<{
      rolname: string;
      rolbypassrls: boolean;
      rolsuper: boolean;
    }>("SELECT rolname, rolbypassrls, rolsuper FROM pg_roles WHERE rolname = current_user");
    const role = roleRes.rows[0];
    report(
      "app_user: rolbypassrls = false",
      role?.rolbypassrls === false,
      `rolbypassrls=${role?.rolbypassrls}`,
    );
    report("app_user: rolsuper = false", role?.rolsuper === false, `rolsuper=${role?.rolsuper}`);

    const ownRes = await appClient.query<{ cnt: number }>(
      "SELECT count(*)::int AS cnt FROM pg_tables WHERE tableowner = current_user AND schemaname = 'public'",
    );
    const ownedCount = ownRes.rows[0]?.cnt ?? -1;
    report(
      "app_user: owns zero tables in schema public",
      ownedCount === 0,
      `owned=${ownedCount}`,
    );

    const extRes = await appClient.query<{ extname: string }>(
      "SELECT extname FROM pg_extension WHERE extname = 'btree_gist'",
    );
    report(
      "hotel db: extension btree_gist exists",
      extRes.rows[0]?.extname === "btree_gist",
      `found=${extRes.rows.length}`,
    );
  } catch (err) {
    report("app_user: connection & assertions", false, String(err));
  } finally {
    await appClient.end().catch(() => {});
  }

  // 2. platform_admin checks
  const adminClient = new Client({ connectionString: adminUrl });
  try {
    await adminClient.connect();
    const roleRes = await adminClient.query<{ rolbypassrls: boolean }>(
      "SELECT rolbypassrls FROM pg_roles WHERE rolname = current_user",
    );
    const bypass = roleRes.rows[0]?.rolbypassrls;
    report("platform_admin: rolbypassrls = true", bypass === true, `rolbypassrls=${bypass}`);
  } catch (err) {
    report("platform_admin: connection & assertions", false, String(err));
  } finally {
    await adminClient.end().catch(() => {});
  }

  // 3. migrator checks (CREATE + DROP table in rolled-back scratch transaction)
  const migrateClient = new Client({ connectionString: migrateUrl });
  try {
    await migrateClient.connect();
    await migrateClient.query("BEGIN");
    await migrateClient.query("CREATE TABLE _db_check_scratch (id int PRIMARY KEY)");
    await migrateClient.query("DROP TABLE _db_check_scratch");
    await migrateClient.query("ROLLBACK");
    report("migrator: CREATE and DROP table in scratch transaction", true);
  } catch (err) {
    await migrateClient.query("ROLLBACK").catch(() => {});
    report("migrator: CREATE and DROP table in scratch transaction", false, String(err));
  } finally {
    await migrateClient.end().catch(() => {});
  }
}

async function checkRedis(): Promise<void> {
  const redisUrl = process.env.REDIS_URL;
  if (!redisUrl) {
    report("redis: answers PING", false, "REDIS_URL is not set");
    return;
  }

  const parsed = new URL(redisUrl);
  const host = parsed.hostname || "localhost";
  const port = Number(parsed.port || 6379);

  await new Promise<void>((resolve) => {
    const socket = net.createConnection({ host, port });
    let settled = false;

    const finish = (ok: boolean, detail?: string) => {
      if (settled) return;
      settled = true;
      socket.destroy();
      report("redis: answers PING", ok, detail);
      resolve();
    };

    socket.setTimeout(3000);
    socket.on("connect", () => {
      socket.write("*1\r\n$4\r\nPING\r\n");
    });
    socket.on("data", (chunk) => {
      const reply = chunk.toString("utf8").trim();
      finish(reply === "+PONG", `reply=${reply}`);
    });
    socket.on("timeout", () => finish(false, "timeout"));
    socket.on("error", (err) => finish(false, err.message));
  });
}

async function main(): Promise<void> {
  loadEnvIfNeeded();
  await checkPostgres();
  await checkRedis();

  if (failures > 0) {
    console.error(`\ndb:check failed with ${failures} failing assertion(s).`);
    process.exitCode = 1;
  } else {
    console.log("\ndb:check passed all assertions.");
  }
}

void main();
