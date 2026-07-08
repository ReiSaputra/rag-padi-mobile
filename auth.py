"""
auth.py — Autentikasi JWT untuk TanyaPadi
==========================================
Berisi:
    1. hash_password()      — bcrypt hash password
    2. verify_password()    — verifikasi password vs hash
    3. create_token()       — buat JWT access token
    4. decode_token()       — decode + validasi JWT
    5. get_current_user()   — FastAPI dependency: ambil user dari token

Diperlukan di .env:
    JWT_SECRET   — secret key untuk signing JWT (wajib, minimal 32 karakter)
    JWT_EXPIRE   — masa berlaku token dalam menit (default: 10080 = 7 hari)
"""

import os
from datetime import datetime, timedelta, timezone

import bcrypt
import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

# ── Konfigurasi ───────────────────────────────────────────────────────────────
# SECURITY FIX: sebelumnya ada fallback ke string default
# ("ganti-dengan-secret-yang-kuat-minimal-32-karakter") yang tertulis jelas di
# source code ini. Kalau .env lupa/belum diset, server tetap jalan pakai
# secret yang sudah "publik" (siapa pun yang baca source code ini bisa forge
# JWT token untuk user_id mana pun). Sekarang: server MENOLAK START kalau
# JWT_SECRET tidak diset di .env, daripada diam-diam pakai secret lemah.
JWT_SECRET = os.getenv("JWT_SECRET")
if not JWT_SECRET:
    raise RuntimeError(
        "JWT_SECRET tidak diset di .env — server tidak bisa start demi "
        "keamanan. Set JWT_SECRET ke string acak & kuat, minimal 32 "
        "karakter (contoh generate: `openssl rand -hex 32`), lalu "
        "tambahkan ke file .env sebagai JWT_SECRET=<hasil generate>."
    )
if len(JWT_SECRET) < 32:
    raise RuntimeError(
        f"JWT_SECRET terlalu pendek ({len(JWT_SECRET)} karakter) — minimal "
        "32 karakter demi keamanan. Generate ulang dengan `openssl rand "
        "-hex 32` dan update .env."
    )

JWT_ALGORITHM = "HS256"
JWT_EXPIRE_MINUTES = int(os.getenv("JWT_EXPIRE", 10080))  # default 7 hari

_bearer = HTTPBearer()


# ══════════════════════════════════════════════════════════════════════════════
# 1. PASSWORD HASHING
# ══════════════════════════════════════════════════════════════════════════════
def hash_password(plain: str) -> str:
    """Menghasilkan bcrypt hash dari password plain text."""
    return bcrypt.hashpw(plain.encode(), bcrypt.gensalt()).decode()


def verify_password(plain: str, hashed: str) -> bool:
    """Memverifikasi password plain text terhadap bcrypt hash."""
    return bcrypt.checkpw(plain.encode(), hashed.encode())


# ══════════════════════════════════════════════════════════════════════════════
# 2. JWT TOKEN
# ══════════════════════════════════════════════════════════════════════════════
def create_token(user_id: int, email: str) -> str:
    """
    Membuat JWT access token.

    Payload:
        sub   — user_id (subject)
        email — email user
        exp   — waktu kadaluarsa
        iat   — waktu dibuat
    """
    now = datetime.now(timezone.utc)
    payload = {
        "sub":   str(user_id),
        "email": email,
        "iat":   now,
        "exp":   now + timedelta(minutes=JWT_EXPIRE_MINUTES),
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)


def decode_token(token: str) -> dict:
    """
    Mendecode dan memvalidasi JWT token.
    Raises HTTPException 401 jika token tidak valid atau kadaluarsa.
    """
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        return payload
    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token sudah kadaluarsa, silakan login kembali.",
        )
    except jwt.InvalidTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token tidak valid.",
        )


# ══════════════════════════════════════════════════════════════════════════════
# 3. FASTAPI DEPENDENCY
# ══════════════════════════════════════════════════════════════════════════════
def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(_bearer),
) -> dict:
    """
    FastAPI dependency — ekstrak dan validasi JWT dari header Authorization.

    Dipakai di endpoint:
        current_user = Depends(get_current_user)
        user_id = int(current_user["sub"])

    Return dict:
        {"sub": "1", "email": "user@example.com", "iat": ..., "exp": ...}
    """
    return decode_token(credentials.credentials)