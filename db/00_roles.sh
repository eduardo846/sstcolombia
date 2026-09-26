#!/bin/bash
# Roles de PostgREST y secreto JWT. Idempotente.
set -e
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
  DO \$\$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticator') THEN
      CREATE ROLE authenticator LOGIN NOINHERIT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'web_anon') THEN CREATE ROLE web_anon NOLOGIN; END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN CREATE ROLE authenticated NOLOGIN; END IF;
  END \$\$;
  ALTER ROLE authenticator PASSWORD '${AUTHENTICATOR_PASSWORD}';
  GRANT CONNECT ON DATABASE "${POSTGRES_DB}" TO authenticator;
  GRANT web_anon TO authenticator;
  GRANT authenticated TO authenticator;

  CREATE SCHEMA IF NOT EXISTS auth;
  REVOKE ALL ON SCHEMA auth FROM PUBLIC;
  CREATE TABLE IF NOT EXISTS auth.config (clave text PRIMARY KEY, valor text NOT NULL);
  INSERT INTO auth.config VALUES ('jwt_secret', '${JWT_SECRET}')
    ON CONFLICT (clave) DO UPDATE SET valor = EXCLUDED.valor;
EOSQL
