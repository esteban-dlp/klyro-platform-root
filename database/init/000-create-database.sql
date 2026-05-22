-- Klyro Platform - Initial Database Setup
-- This script runs automatically when PostgreSQL starts for the first time.

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 000-create-database.sql
-- Klyro database bootstrap script.
-- Recommended Docker order:
-- 000-create-database.sql
-- 001-enums.sql
-- 002-tables.sql

-- If you set POSTGRES_DB=klyro in Docker, Postgres will already create it.
-- This command only creates it if it does not exist.
SELECT 'CREATE DATABASE klyro'
WHERE NOT EXISTS (
    SELECT 1
    FROM pg_database
    WHERE datname = 'klyro'
)\gexec

\connect klyro

CREATE EXTENSION IF NOT EXISTS pgcrypto;
