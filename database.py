"""
database.py — Setup database PostgreSQL untuk TanyaPadi
========================================================
Menggunakan asyncpg untuk koneksi asinkron.

Tabel:
    1. users         — akun pengguna (email + password bcrypt)
    2. sensor        — data sensor AWS-003
    3. chat_session  — satu sesi = satu analisis atau chat mandiri
    4. chat_message  — pesan dalam satu sesi

Perubahan v3 (auth):
    - Tambah tabel users
    - chat_session.user_id ditambahkan (FK ke users, nullable untuk data lama)
    - migrate_db() menangani upgrade tabel yang sudah ada
"""

import asyncio
import os
from datetime import datetime, timedelta

import asyncpg
from dotenv import load_dotenv

load_dotenv()

# ── Konfigurasi koneksi ───────────────────────────────────────────────────────
DB_CONFIG = {
    "host":     os.getenv("DB_HOST", "localhost"),
    "port":     int(os.getenv("DB_PORT", 5432)),
    "database": os.getenv("DB_NAME", "tanyapadi"),
    "user":     os.getenv("DB_USER", "postgres"),
    "password": os.getenv("DB_PASSWORD", ""),
}

# ── Connection pool ───────────────────────────────────────────────────────────
pool: asyncpg.Pool | None = None


async def create_pool() -> asyncpg.Pool:
    global pool
    pool = await asyncpg.create_pool(**DB_CONFIG, min_size=2, max_size=10)
    return pool


async def close_pool():
    global pool
    if pool:
        await pool.close()
        pool = None


def get_pool() -> asyncpg.Pool:
    if pool is None:
        raise RuntimeError("Connection pool belum diinisialisasi.")
    return pool


# ══════════════════════════════════════════════════════════════════════════════
# DDL — Buat tabel
# ══════════════════════════════════════════════════════════════════════════════
async def init_db(conn: asyncpg.Connection):
    """Membuat semua tabel jika belum ada."""

    # ── Tabel users ───────────────────────────────────────────────────────────
    await conn.execute("""
        CREATE TABLE IF NOT EXISTS users (
            id          SERIAL PRIMARY KEY,
            name        TEXT NOT NULL,
            email       TEXT NOT NULL UNIQUE,
            password    TEXT NOT NULL,
            created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
        )
    """)

    # ── Tabel sensor ──────────────────────────────────────────────────────────
    await conn.execute("""
        CREATE TABLE IF NOT EXISTS sensor (
            id      SERIAL PRIMARY KEY,
            sm      REAL NOT NULL,
            sph     REAL NOT NULL,
            sn      REAL NOT NULL,
            sp      REAL NOT NULL,
            sk      REAL NOT NULL,
            wtp     REAL NOT NULL,
            wrf     REAL NOT NULL,
            whm     REAL,
            wws     REAL,
            st      REAL,
            sc      REAL,
            time    TIMESTAMPTZ NOT NULL
        )
    """)

    # ── Tabel chat_session ────────────────────────────────────────────────────
    await conn.execute("""
        CREATE TABLE IF NOT EXISTS chat_session (
            id          TEXT PRIMARY KEY,
            sensor_id   INTEGER,
            user_id     INTEGER,
            type        TEXT NOT NULL DEFAULT 'analisis',
            created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            FOREIGN KEY (sensor_id) REFERENCES sensor(id),
            FOREIGN KEY (user_id)   REFERENCES users(id)
        )
    """)

    # ── Tabel chat_message ────────────────────────────────────────────────────
    await conn.execute("""
        CREATE TABLE IF NOT EXISTS chat_message (
            id          SERIAL PRIMARY KEY,
            session_id  TEXT NOT NULL,
            role        TEXT NOT NULL,
            content     TEXT NOT NULL,
            created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            FOREIGN KEY (session_id) REFERENCES chat_session(id)
        )
    """)

    print("Tabel berhasil dibuat / sudah ada.")


# ══════════════════════════════════════════════════════════════════════════════
# MIGRATION — Upgrade tabel yang sudah ada
# ══════════════════════════════════════════════════════════════════════════════
async def migrate_db(conn: asyncpg.Connection):
    """
    Menambahkan kolom baru ke tabel yang sudah ada.
    Aman dijalankan berulang kali.
    """
    migrations = [
        # v2: tambah kolom type
        "ALTER TABLE chat_session ADD COLUMN IF NOT EXISTS type TEXT NOT NULL DEFAULT 'analisis'",
        # v2: ubah sensor_id jadi nullable
        "ALTER TABLE chat_session ALTER COLUMN sensor_id DROP NOT NULL",
        # v3: tambah kolom user_id
        "ALTER TABLE chat_session ADD COLUMN IF NOT EXISTS user_id INTEGER REFERENCES users(id)",
    ]

    for sql in migrations:
        try:
            await conn.execute(sql)
            print(f"Migrasi OK: {sql[:60]}...")
        except Exception as e:
            print(f"Migrasi skip/error: {e}")


# ══════════════════════════════════════════════════════════════════════════════
# SEED — Dummy data sensor
# ══════════════════════════════════════════════════════════════════════════════
async def seed_sensor(conn: asyncpg.Connection):
    count = await conn.fetchval("SELECT COUNT(*) FROM sensor")
    if count > 0:
        print(f"Tabel sensor sudah berisi {count} baris, skip seeding.")
        return

    base_time = datetime(2026, 12, 12, 21, 0, 0)

    dummy_data = [
        (28.5,  4.8,  38.0,  42.0,  35.0,  31.2, 0.0,  55.0, 2.1, 30.1, 620.0, -9),
        (35.0,  5.2,  55.0,  90.0,  85.0,  29.5, 1.5,  60.0, 1.8, 28.5, 580.0, -8),
        (45.0,  6.0,  120.0, 100.0, 90.0,  27.0, 3.0,  65.0, 1.5, 27.0, 540.0, -7),
        (60.0,  6.5,  160.0, 130.0, 120.0, 25.5, 6.0,  70.0, 1.2, 26.0, 500.0, -6),
        (72.0,  6.8,  200.0, 150.0, 140.0, 24.0, 8.0,  72.0, 1.0, 25.5, 480.0, -5),
        (55.0,  5.8,  90.0,  80.0,  75.0,  30.0, 0.5,  58.0, 2.5, 29.0, 610.0, -4),
        (40.0,  4.9,  45.0,  50.0,  40.0,  33.0, 0.0,  52.0, 3.0, 32.0, 650.0, -3),
        (82.0,  7.0,  220.0, 160.0, 155.0, 26.0, 10.0, 75.0, 0.8, 25.0, 460.0, -2),
        (65.0,  6.2,  140.0, 110.0, 100.0, 28.0, 2.0,  68.0, 1.6, 27.5, 520.0, -1),
        (32.0,  4.6,  25.0,  5.3,   20.0,  37.3, 2.1,  50.0, 2.8, 36.0, 700.0,  0),
    ]

    await conn.executemany("""
        INSERT INTO sensor (sm, sph, sn, sp, sk, wtp, wrf, whm, wws, st, sc, time)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
    """, [
        (
            row[0], row[1], row[2], row[3], row[4],
            row[5], row[6], row[7], row[8], row[9], row[10],
            base_time + timedelta(hours=row[11])
        )
        for row in dummy_data
    ])

    print(f"Dummy data sensor berhasil dimasukkan: {len(dummy_data)} baris.")


# ══════════════════════════════════════════════════════════════════════════════
# ENTRY POINT
# ══════════════════════════════════════════════════════════════════════════════
async def main():
    conn = await asyncpg.connect(**DB_CONFIG)
    try:
        await init_db(conn)
        await migrate_db(conn)
        await seed_sensor(conn)

        rows = await conn.fetch("SELECT * FROM sensor ORDER BY time DESC LIMIT 3")
        print("\n3 data sensor terbaru:")
        for row in rows:
            print(dict(row))
    finally:
        await conn.close()


if __name__ == "__main__":
    asyncio.run(main())