-- DEV-ONLY initialization script for local PostgreSQL 17.
-- Creates roles, the "hotel" database, the btree_gist extension, and default privileges.
-- Never reuse these DEV-ONLY passwords outside local development.

-- 1. Roles (per data-isolation.md section 3)
CREATE ROLE migrator LOGIN PASSWORD 'migrator_dev_pw_only' CREATEDB NOSUPERUSER NOBYPASSRLS;
CREATE ROLE app_user LOGIN PASSWORD 'app_user_dev_pw_only' NOSUPERUSER NOBYPASSRLS;
CREATE ROLE platform_admin LOGIN PASSWORD 'platform_admin_dev_pw_only' NOSUPERUSER BYPASSRLS;

-- 2. Database owned by migrator
CREATE DATABASE hotel OWNER migrator;

\connect hotel

-- 3. Extensions required for booking overlap exclusion constraints (NFR-02.3)
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- 4. Schema ownership & privileges
ALTER SCHEMA public OWNER TO migrator;

GRANT USAGE ON SCHEMA public TO app_user;
GRANT USAGE ON SCHEMA public TO platform_admin;

-- Tables and sequences later created by migrator are accessible to app_user and platform_admin
ALTER DEFAULT PRIVILEGES FOR ROLE migrator IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_user;
ALTER DEFAULT PRIVILEGES FOR ROLE migrator IN SCHEMA public
  GRANT USAGE, SELECT ON SEQUENCES TO app_user;

ALTER DEFAULT PRIVILEGES FOR ROLE migrator IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO platform_admin;
ALTER DEFAULT PRIVILEGES FOR ROLE migrator IN SCHEMA public
  GRANT USAGE, SELECT ON SEQUENCES TO platform_admin;
