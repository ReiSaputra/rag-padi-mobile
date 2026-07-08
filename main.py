"""
main.py — FastAPI Backend TanyaPadi
=====================================
Perubahan v3 (auth):
    - POST /auth/register  → daftar akun baru
    - POST /auth/login     → login, return JWT
    - GET  /auth/me        → info user dari token
    - Semua endpoint RAG sekarang butuh JWT token
    - /history filter by user_id
    - /analyze, /chat/new, /chat/{session_id} simpan user_id ke sesi

Cara menjalankan:
    python -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
"""

import os
import uuid
import logging
import time as _time
from contextlib import asynccontextmanager
from datetime import datetime, timezone

import asyncpg
from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, EmailStr
from dotenv import load_dotenv

from database import create_pool, close_pool, get_pool
from rag import init_rag, parse_sensor, retrieve_hybrid, format_context, build_prompt, generate
from auth import hash_password, verify_password, create_token, get_current_user

load_dotenv()

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger(__name__)



# LIFESPAN

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Membuka connection pool PostgreSQL...")
    await create_pool()
    logger.info("Connection pool siap.")
    logger.info("Memuat komponen RAG...")
    init_rag()
    logger.info("Komponen RAG siap.")
    yield
    logger.info("Menutup connection pool...")
    await close_pool()



# APLIKASI

app = FastAPI(
    title="TanyaPadi API",
    description="Backend sistem RAG rekomendasi penyiraman dan penanaman padi",
    version="3.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)



# SCHEMA


# ── Auth ──────────────────────────────────────────────────────────────────────
class RegisterRequest(BaseModel):
    name:     str
    email:    EmailStr
    password: str

class LoginRequest(BaseModel):
    email:    EmailStr
    password: str

class AuthResponse(BaseModel):
    token:      str
    user_id:    int
    name:       str
    email:      str

class UserResponse(BaseModel):
    user_id:    int
    name:       str
    email:      str
    created_at: str

class UpdateProfileRequest(BaseModel):
    name:             str | None = None
    email:            EmailStr | None = None
    current_password: str | None = None
    new_password:     str | None = None

# ── Sensor ────────────────────────────────────────────────────────────────────
class SensorResponse(BaseModel):
    id:   int
    sm:   float
    sph:  float
    sn:   float
    sp:   float
    sk:   float
    wtp:  float
    wrf:  float
    whm:  float | None
    wws:  float | None
    st:   float | None
    sc:   float | None
    time: str

# ── RAG ───────────────────────────────────────────────────────────────────────
class AnalyzeResponse(BaseModel):
    session_id:        str
    jawaban:           str
    sensor_parsed:     str
    retrieval_time_ms: float
    created_at:        str

class ChatRequest(BaseModel):
    message: str

class ChatMessageItem(BaseModel):
    role:       str
    content:    str
    created_at: str

class ChatResponse(BaseModel):
    session_id: str
    jawaban:    str
    history:    list[ChatMessageItem]

class NewChatResponse(BaseModel):
    session_id: str
    jawaban:    str
    created_at: str

class HistoryItem(BaseModel):
    session_id:    str
    created_at:    str
    preview:       str
    message_count: int
    type:          str



# AUTH ENDPOINTS

@app.post("/auth/register", response_model=AuthResponse, tags=["Auth"])
async def register(
    req:  RegisterRequest,
    pool: asyncpg.Pool = Depends(get_pool),
):
    """
    Mendaftarkan akun baru.
    Email harus unik — return 409 jika sudah terdaftar.
    Langsung return JWT token agar user tidak perlu login ulang setelah daftar.
    """
    async with pool.acquire() as conn:
        existing = await conn.fetchval(
            "SELECT id FROM users WHERE email = $1", req.email
        )
        if existing:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Email sudah terdaftar.",
            )

        hashed = hash_password(req.password)
        # SECURITY/BUG fix: ada celah waktu antara SELECT di atas dan INSERT
        # di bawah — kalau 2 request register email sama terjadi nyaris
        # bersamaan, keduanya bisa lolos pengecekan SELECT, lalu salah satu
        # INSERT gagal karena UNIQUE constraint. Sebelumnya exception ini
        # tidak ditangkap -> user dapat 500 yang membingungkan. Sekarang
        # ditangkap dan dikembalikan sebagai 409 yang jelas, sama seperti
        # kalau lolos dari pengecekan SELECT di atas.
        try:
            user_id = await conn.fetchval(
                """INSERT INTO users (name, email, password)
                   VALUES ($1, $2, $3) RETURNING id""",
                req.name, req.email, hashed,
            )
        except asyncpg.UniqueViolationError:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Email sudah terdaftar.",
            )

    token = create_token(user_id, req.email)
    logger.info("Register berhasil — user_id: %d | email: %s", user_id, req.email)

    return AuthResponse(
        token=token,
        user_id=user_id,
        name=req.name,
        email=req.email,
    )


@app.post("/auth/login", response_model=AuthResponse, tags=["Auth"])
async def login(
    req:  LoginRequest,
    pool: asyncpg.Pool = Depends(get_pool),
):
    """
    Login dengan email + password.
    Return JWT token jika berhasil.
    """
    async with pool.acquire() as conn:
        row = await conn.fetchrow(
            "SELECT id, name, email, password FROM users WHERE email = $1",
            req.email,
        )

    # Pesan error sengaja sama untuk keduanya (tidak bocorkan info email terdaftar)
    if not row or not verify_password(req.password, row["password"]):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Email atau password salah.",
        )

    token = create_token(row["id"], row["email"])
    logger.info("Login berhasil — user_id: %d | email: %s", row["id"], row["email"])

    return AuthResponse(
        token=token,
        user_id=row["id"],
        name=row["name"],
        email=row["email"],
    )


@app.get("/auth/me", response_model=UserResponse, tags=["Auth"])
async def me(
    current_user: dict = Depends(get_current_user),
    pool: asyncpg.Pool = Depends(get_pool),
):
    """Info user yang sedang login (dari JWT token)."""
    user_id = int(current_user["sub"])
    async with pool.acquire() as conn:
        row = await conn.fetchrow(
            "SELECT id, name, email, created_at FROM users WHERE id = $1", user_id
        )
    if not row:
        raise HTTPException(status_code=404, detail="User tidak ditemukan.")
    return UserResponse(
        user_id=row["id"],
        name=row["name"],
        email=row["email"],
        created_at=row["created_at"].isoformat(),
    )


@app.put("/auth/me", response_model=UserResponse, tags=["Auth"])
async def update_profile(
    req:          UpdateProfileRequest,
    current_user: dict = Depends(get_current_user),
    pool:         asyncpg.Pool = Depends(get_pool),
):
    """
    Update profil user yang sedang login.

    - name / email: opsional, kirim kalau mau diubah.
    - new_password: opsional. Kalau diisi, current_password WAJIB diisi
      dan harus cocok dengan password yang tersimpan saat ini.
    - email baru divalidasi unik (tidak boleh dipakai akun lain).
    """
    user_id = int(current_user["sub"])

    async with pool.acquire() as conn:
        row = await conn.fetchrow("SELECT * FROM users WHERE id = $1", user_id)
        if not row:
            raise HTTPException(status_code=404, detail="User tidak ditemukan.")

        new_name  = req.name.strip() if req.name and req.name.strip() else row["name"]
        new_email = row["email"]
        new_password_hash = row["password"]

        if req.email and req.email != row["email"]:
            existing = await conn.fetchval(
                "SELECT id FROM users WHERE email = $1 AND id != $2",
                req.email, user_id,
            )
            if existing:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="Email sudah digunakan oleh akun lain.",
                )
            new_email = req.email

        if req.new_password:
            if not req.current_password or not verify_password(
                req.current_password, row["password"]
            ):
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Password saat ini salah.",
                )
            new_password_hash = hash_password(req.new_password)

        updated = await conn.fetchrow(
            """UPDATE users SET name = $1, email = $2, password = $3
               WHERE id = $4
               RETURNING id, name, email, created_at""",
            new_name, new_email, new_password_hash, user_id,
        )

    logger.info("Update profil — user_id: %d", user_id)

    return UserResponse(
        user_id=updated["id"],
        name=updated["name"],
        email=updated["email"],
        created_at=updated["created_at"].isoformat(),
    )



# UTILITAS

@app.get("/health", tags=["Utilitas"])
async def health_check():
    pool = get_pool()
    async with pool.acquire() as conn:
        await conn.fetchval("SELECT 1")
    return {"status": "ok", "database": "connected"}



# SENSOR

@app.get("/sensor/latest", response_model=SensorResponse, tags=["Sensor"])
async def get_latest_sensor(
    current_user: dict = Depends(get_current_user),
    pool: asyncpg.Pool = Depends(get_pool),
):
    """Ambil data sensor terbaru. Butuh token."""
    async with pool.acquire() as conn:
        row = await conn.fetchrow("SELECT * FROM sensor ORDER BY time DESC LIMIT 1")
    if not row:
        raise HTTPException(status_code=404, detail="Belum ada data sensor.")
    return SensorResponse(
        id=row["id"], sm=row["sm"], sph=row["sph"],
        sn=row["sn"], sp=row["sp"], sk=row["sk"],
        wtp=row["wtp"], wrf=row["wrf"], whm=row["whm"],
        wws=row["wws"], st=row["st"], sc=row["sc"],
        time=row["time"].isoformat(),
    )



# RAG ENDPOINTS

@app.post("/analyze", response_model=AnalyzeResponse, tags=["RAG"])
async def analyze(
    current_user: dict = Depends(get_current_user),
    pool: asyncpg.Pool = Depends(get_pool),
):
    """
    Analisis otomatis berdasarkan sensor terbaru.
    Sesi disimpan dengan user_id dari token.
    """
    user_id = int(current_user["sub"])

    async with pool.acquire() as conn:
        sensor_row = await conn.fetchrow(
            "SELECT * FROM sensor ORDER BY time DESC LIMIT 1"
        )
        if not sensor_row:
            raise HTTPException(status_code=404, detail="Belum ada data sensor.")

        sensor_dict = dict(sensor_row)
        time_str    = sensor_row["time"].isoformat()
        sensor_text = parse_sensor(sensor_dict)

        t0           = _time.perf_counter()
        chunks       = retrieve_hybrid(sensor_text, top_k=3)
        retrieval_ms = round((_time.perf_counter() - t0) * 1000, 2)

        context  = format_context(chunks)
        messages = build_prompt(
            sensor_text=sensor_text,
            context=context,
            time=time_str,
            user_message=None,
            history=None,
        )

        try:
            jawaban = generate(messages, llm="groq")
        except Exception as e:
            logger.error("LLM error: %s", e)
            raise HTTPException(status_code=502, detail=f"LLM error: {str(e)}")

        session_id = str(uuid.uuid4())
        now        = datetime.now(timezone.utc)

        await conn.execute(
            """INSERT INTO chat_session (id, sensor_id, user_id, type, created_at)
               VALUES ($1, $2, $3, 'analisis', $4)""",
            session_id, sensor_row["id"], user_id, now,
        )
        await conn.execute(
            """INSERT INTO chat_message (session_id, role, content, created_at)
               VALUES ($1, 'assistant', $2, $3)""",
            session_id, jawaban, now,
        )

    logger.info("Analisis — user: %d | session: %s | %.0fms", user_id, session_id, retrieval_ms)

    return AnalyzeResponse(
        session_id=session_id,
        jawaban=jawaban,
        sensor_parsed=sensor_text,
        retrieval_time_ms=retrieval_ms,
        created_at=now.isoformat(),
    )


@app.post("/chat/new", response_model=NewChatResponse, tags=["RAG"])
async def new_chat(
    req:          ChatRequest,
    current_user: dict = Depends(get_current_user),
    pool:         asyncpg.Pool = Depends(get_pool),
):
    """Chat mandiri tanpa sensor. Sesi disimpan dengan user_id dari token."""
    user_id = int(current_user["sub"])

    chunks   = retrieve_hybrid(req.message, top_k=3)
    context  = format_context(chunks)
    messages = build_prompt(
        sensor_text=None,
        context=context,
        time=None,
        user_message=req.message,
        history=None,
    )

    try:
        jawaban = generate(messages, llm="groq")
    except Exception as e:
        logger.error("LLM error: %s", e)
        raise HTTPException(status_code=502, detail=f"LLM error: {str(e)}")

    session_id = str(uuid.uuid4())
    now        = datetime.now(timezone.utc)

    async with pool.acquire() as conn:
        await conn.execute(
            """INSERT INTO chat_session (id, sensor_id, user_id, type, created_at)
               VALUES ($1, NULL, $2, 'tanya_jawab', $3)""",
            session_id, user_id, now,
        )
        await conn.execute(
            """INSERT INTO chat_message (session_id, role, content, created_at)
               VALUES ($1, 'user', $2, $3)""",
            session_id, req.message, now,
        )
        await conn.execute(
            """INSERT INTO chat_message (session_id, role, content, created_at)
               VALUES ($1, 'assistant', $2, $3)""",
            session_id, jawaban, now,
        )

    logger.info("Chat mandiri — user: %d | session: %s", user_id, session_id)

    return NewChatResponse(
        session_id=session_id,
        jawaban=jawaban,
        created_at=now.isoformat(),
    )


@app.post("/chat/{session_id}", response_model=ChatResponse, tags=["RAG"])
async def chat(
    session_id:   str,
    req:          ChatRequest,
    current_user: dict = Depends(get_current_user),
    pool:         asyncpg.Pool = Depends(get_pool),
):
    """
    Pesan lanjutan dalam satu sesi.
    Validasi bahwa sesi milik user yang sedang login.
    """
    user_id = int(current_user["sub"])

    async with pool.acquire() as conn:
        # Validasi sesi + kepemilikan
        session_row = await conn.fetchrow(
            "SELECT * FROM chat_session WHERE id = $1", session_id
        )
        if not session_row:
            raise HTTPException(status_code=404, detail="Sesi tidak ditemukan.")
        if session_row["user_id"] != user_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Sesi ini bukan milik kamu.",
            )

        # Ambil sensor jika sesi analisis
        sensor_text = None
        time_str    = None
        if session_row["sensor_id"] is not None:
            sensor_row  = await conn.fetchrow(
                "SELECT * FROM sensor WHERE id = $1", session_row["sensor_id"]
            )
            sensor_text = parse_sensor(dict(sensor_row))
            time_str    = sensor_row["time"].isoformat()

        # Ambil riwayat
        # BUG-011 (fixed): tanpa tie-breaker "id ASC", urutan pesan dengan
        # created_at yang identik (user+assistant disimpan dengan timestamp
        # sama persis dalam satu request) TIDAK DIJAMIN oleh PostgreSQL —
        # bisa kembali sebagai [assistant, user] alih-alih [user, assistant].
        # History ini dikirim ke LLM sebagai konteks percakapan, jadi urutan
        # yang salah bisa bikin LLM salah baca alur tanpa ada error yang
        # kelihatan (silent quality degradation).
        msg_rows = await conn.fetch(
            """SELECT role, content, created_at FROM chat_message
               WHERE session_id = $1 ORDER BY created_at ASC, id ASC""",
            session_id,
        )
        history = [{"role": r["role"], "content": r["content"]} for r in msg_rows]

        # Retrieve + build + generate
        chunks   = retrieve_hybrid(req.message, top_k=3)
        context  = format_context(chunks)
        messages = build_prompt(
            sensor_text=sensor_text,
            context=context,
            time=time_str,
            user_message=req.message,
            history=history,
        )

        try:
            jawaban = generate(messages, llm="groq")
        except Exception as e:
            logger.error("LLM error: %s", e)
            raise HTTPException(status_code=502, detail=f"LLM error: {str(e)}")

        now = datetime.now(timezone.utc)
        await conn.execute(
            """INSERT INTO chat_message (session_id, role, content, created_at)
               VALUES ($1, 'user', $2, $3)""",
            session_id, req.message, now,
        )
        await conn.execute(
            """INSERT INTO chat_message (session_id, role, content, created_at)
               VALUES ($1, 'assistant', $2, $3)""",
            session_id, jawaban, now,
        )

        updated_rows = await conn.fetch(
            """SELECT role, content, created_at FROM chat_message
               WHERE session_id = $1 ORDER BY created_at ASC, id ASC""",
            session_id,
        )

    logger.info("Chat — user: %d | session: %s | %.30s...", user_id, session_id, req.message)

    return ChatResponse(
        session_id=session_id,
        jawaban=jawaban,
        history=[
            ChatMessageItem(
                role=row["role"],
                content=row["content"],
                created_at=row["created_at"].isoformat(),
            )
            for row in updated_rows
        ],
    )


@app.delete("/chat/{session_id}", tags=["RAG"])
async def delete_chat_session(
    session_id:   str,
    current_user: dict = Depends(get_current_user),
    pool:         asyncpg.Pool = Depends(get_pool),
):
    """
    Hapus satu sesi chat beserta seluruh pesan di dalamnya.
    Validasi bahwa sesi milik user yang sedang login.

    chat_message tidak punya ON DELETE CASCADE ke chat_session, jadi
    pesan harus dihapus manual dulu sebelum sesi-nya, dalam satu
    transaksi supaya tidak ada data yatim kalau salah satu gagal.
    """
    user_id = int(current_user["sub"])

    async with pool.acquire() as conn:
        session_row = await conn.fetchrow(
            "SELECT * FROM chat_session WHERE id = $1", session_id
        )
        if not session_row:
            raise HTTPException(status_code=404, detail="Sesi tidak ditemukan.")
        if session_row["user_id"] != user_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Sesi ini bukan milik kamu.",
            )

        async with conn.transaction():
            await conn.execute(
                "DELETE FROM chat_message WHERE session_id = $1", session_id
            )
            await conn.execute(
                "DELETE FROM chat_session WHERE id = $1", session_id
            )

    logger.info("Hapus sesi chat — user: %d | session: %s", user_id, session_id)
    return {"status": "deleted", "session_id": session_id}


@app.get("/history", response_model=list[HistoryItem], tags=["RAG"])
async def get_history(
    current_user: dict = Depends(get_current_user),
    pool: asyncpg.Pool = Depends(get_pool),
):
    """
    Daftar sesi percakapan milik user yang sedang login.
    Filter by user_id dari token.
    """
    user_id = int(current_user["sub"])

    async with pool.acquire() as conn:
        # BUG-006 (fixed): sebelumnya pakai MIN(m.content), yang mengurutkan
        # teks secara ALFABETIS (lexicographic), bukan kronologis — akibatnya
        # preview kadang menampilkan potongan jawaban LLM alih-alih pesan
        # pertama yang sebenarnya, dan judul histori jadi tidak konsisten.
        #
        # Fix: pakai correlated subquery yang ambil pesan dengan created_at
        # paling awal. Tie-breaker "m2.id ASC" diperlukan karena /chat/new
        # dan /analyze menyimpan pesan user+assistant dengan timestamp
        # (`now`) yang identik dalam satu request — id auto-increment
        # menjamin urutan insert asli (user dulu, baru assistant) tetap
        # terjaga meski timestamp sama.
        rows = await conn.fetch("""
            SELECT
                s.id           AS session_id,
                s.created_at   AS created_at,
                s.type         AS type,
                (
                    SELECT m2.content FROM chat_message m2
                    WHERE m2.session_id = s.id
                    ORDER BY m2.created_at ASC, m2.id ASC
                    LIMIT 1
                )              AS first_message,
                (
                    SELECT COUNT(*) FROM chat_message m3
                    WHERE m3.session_id = s.id
                )              AS message_count
            FROM chat_session s
            WHERE s.user_id = $1
            ORDER BY s.created_at DESC
        """, user_id)

    return [
        HistoryItem(
            session_id=row["session_id"],
            created_at=row["created_at"].isoformat(),
            # Bersihkan newline/whitespace berlebih supaya potongan teks
            # panjang (terutama dari sesi analisis) tidak tampil berantakan.
            preview=" ".join((row["first_message"] or "").split())[:100],
            message_count=row["message_count"] or 0,
            type=row["type"],
        )
        for row in rows
    ]

@app.get("/chat/{session_id}", response_model=ChatResponse, tags=["RAG"])
async def get_chat_session(
    session_id:   str,
    current_user: dict = Depends(get_current_user),
    pool:         asyncpg.Pool = Depends(get_pool),
):
    """
    Ambil history sebuah sesi TANPA mengirim pesan baru.
    Dipakai saat user membuka kembali sesi lama dari daftar histori.
    Validasi bahwa sesi milik user yang sedang login.
    """
    user_id = int(current_user["sub"])

    async with pool.acquire() as conn:
        session_row = await conn.fetchrow(
            "SELECT * FROM chat_session WHERE id = $1", session_id
        )
        if not session_row:
            raise HTTPException(status_code=404, detail="Sesi tidak ditemukan.")
        if session_row["user_id"] != user_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Sesi ini bukan milik kamu.",
            )

        msg_rows = await conn.fetch(
            """SELECT role, content, created_at FROM chat_message
               WHERE session_id = $1 ORDER BY created_at ASC, id ASC""",
            session_id,
        )

    history = [
        ChatMessageItem(
            role=row["role"],
            content=row["content"],
            created_at=row["created_at"].isoformat(),
        )
        for row in msg_rows
    ]
    # jawaban diisi dengan pesan assistant terakhir (jika ada), agar tetap
    # kompatibel dengan model ChatResponse yang sudah ada di frontend
    last_assistant = next(
        (m.content for m in reversed(history) if m.role == "assistant"), ""
    )

    return ChatResponse(session_id=session_id, jawaban=last_assistant, history=history)