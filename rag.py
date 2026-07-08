"""
rag.py — Pipeline RAG untuk TanyaPadi
=======================================
Perubahan v2:
    - build_prompt() sekarang handle sensor_text=None (chat mandiri tanpa sensor)
      → system prompt tidak menyertakan bagian data sensor
"""

import os
import re
import json
import logging
from typing import Optional

from sentence_transformers import SentenceTransformer
from rank_bm25 import BM25Okapi
import chromadb
from groq import Groq
import google.genai
from dotenv import load_dotenv

load_dotenv()

logger = logging.getLogger(__name__)

# Path
BASE_DIR    = os.path.dirname(os.path.abspath(__file__))
CHUNKS_PATH = os.path.join(BASE_DIR, "data", "chunks_2.json")
CHROMA_PATH = os.path.join(BASE_DIR, "chroma_db_intfloat_multilingual-e5-base")
EMBED_MODEL = "intfloat/multilingual-e5-base"

# State 
_embedder:   SentenceTransformer | None = None
_collection: chromadb.Collection | None = None
_bm25:       BM25Okapi | None           = None
_chunks:     list[dict]                 = []
_chunk_map:  dict[str, dict]            = {}


def init_rag():
    global _embedder, _collection, _bm25, _chunks, _chunk_map

    logger.info("Memuat chunks dari %s ...", CHUNKS_PATH)
    with open(CHUNKS_PATH, "r", encoding="utf-8") as f:
        _chunks = json.load(f)
    _chunk_map = {c["chunk_id"]: c for c in _chunks}
    logger.info("Chunks dimuat: %d dokumen", len(_chunks))

    logger.info("Memuat embedding model: %s ...", EMBED_MODEL)
    _embedder = SentenceTransformer(EMBED_MODEL)

    logger.info("Memuat ChromaDB dari %s ...", CHROMA_PATH)
    client      = chromadb.PersistentClient(path=CHROMA_PATH)
    _collection = client.get_or_create_collection(
        name="knowledge_padi",
        metadata={"hnsw:space": "cosine"},
    )
    if _collection.count() == 0:
        logger.info("ChromaDB kosong — mengisi ulang dari chunks ...")
        texts      = [c["text"]     for c in _chunks]
        ids        = [c["chunk_id"] for c in _chunks]
        metas      = [{"title": c["title"]} for c in _chunks]
        embeddings = _embedder.encode(texts).tolist()
        _collection.add(documents=texts, embeddings=embeddings, ids=ids, metadatas=metas)
        logger.info("ChromaDB terisi: %d chunk", _collection.count())
    else:
        logger.info("ChromaDB sudah ada: %d chunk", _collection.count())
        # BUG-007: validasi apakah chunk_id di ChromaDB masih sinkron dengan
        # chunks_2.json saat ini. Kalau chunks_2.json pernah direvisi (chunk
        # ditambah/dihapus/di-rename) tanpa reindex ulang, ChromaDB bisa
        # menyimpan chunk_id "basi" yang sudah tidak ada di _chunk_map —
        # menyebabkan KeyError saat retrieve_hybrid() dipanggil.
        try:
            existing_ids = set(_collection.get(include=[])["ids"])
            current_ids  = set(_chunk_map.keys())
            stale_ids    = existing_ids - current_ids
            if stale_ids:
                sample = ", ".join(sorted(stale_ids)[:5])
                logger.warning(
                    "ChromaDB berisi %d chunk_id yang TIDAK ADA di "
                    "chunks_2.json saat ini (contoh: %s%s). Kemungkinan "
                    "chunks_2.json sudah direvisi tapi ChromaDB belum "
                    "di-reindex. Hapus folder '%s' lalu restart server "
                    "untuk membangun ulang index dari data terkini.",
                    len(stale_ids), sample,
                    "..." if len(stale_ids) > 5 else "",
                    CHROMA_PATH,
                )
        except Exception as e:
            logger.warning("Gagal validasi sinkronisasi ChromaDB: %s", e)

    logger.info("Membangun BM25 index ...")
    corpus = [re.findall(r"\w+", c["text"].lower()) for c in _chunks]
    _bm25  = BM25Okapi(corpus)
    logger.info("BM25 index siap.")

    logger.info("=== Semua komponen RAG siap ===")


# 1. PARSE SENSOR
def parse_sensor(data: dict) -> str:
    sm  = data["sm"]
    sph = data["sph"]
    wtp = data["wtp"]
    wrf = data["wrf"]
    sn  = data["sn"]
    sp  = data["sp"]
    sk  = data["sk"]

    if sm >= 80:
        kondisi_sm = "optimal"
    elif sm >= 60:
        kondisi_sm = "Monitor setiap 6 jam, siram jika tidak ada prediksi hujan."
    elif sm >= 40:
        kondisi_sm = "Segera siram dengan volume 3–5 liter per meter persegi."
    else:
        kondisi_sm = "Siram segera dengan volume 5–8 liter per meter persegi, kondisi darurat."

    if 5.5 <= sph <= 8.2:
        kondisi_ph = "Sangat sesuai (S1), kondisi optimal untuk padi sawah"
    elif 5.0 <= sph < 5.5:
        kondisi_ph = "Cukup sesuai (S2), pertumbuhan mulai terhambat, pertimbangkan pengapuran dengan dolomit."
    elif 8.2 < sph <= 8.5:
        # BUG-001 (fixed): sebelumnya zona ini tertangkap branch else di bawah
        # dan dilabeli "pH > 8.5: Tidak sesuai (N)", padahal KB (Dokumen 2,
        # Pujiharti et al., 2008) menyebut 8.2-8.5 sebagai S2 cukup sesuai,
        # setara dengan zona 5.0-5.5.
        kondisi_ph = "Cukup sesuai (S2), pertumbuhan mulai terhambat, pertimbangkan pengapuran dengan dolomit."
    elif sph < 5.0:
        kondisi_ph = "Tidak sesuai (N), tambahkan kapur pertanian sebelum tanam."
    else:
        kondisi_ph = "pH > 8.5: Tidak sesuai (N), lakukan penggenangan dan perbaikan tanah."

    if 22 <= wtp <= 28:
        kondisi_wtp = "Optimal untuk pertumbuhan vegetatif."
    elif 28 < wtp <= 32:
        kondisi_wtp = "Masih dapat diterima, monitor kelembaban tanah lebih sering."
    elif 32 < wtp <= 33.7:
        kondisi_wtp = "Mulai terganggu: tinggi tanaman dan jumlah anakan berkurang."
    elif 33.7 < wtp <= 35:
        kondisi_wtp = "Risiko tinggi saat pembungaan: spikelet bisa hampa, fertilitas turun."
    elif wtp > 35:
        kondisi_wtp = "Stres panas berat, kurangi interval penyiraman menjadi setiap 4 jam."
    elif wtp < 20:
        kondisi_wtp = "Pertumbuhan melambat, tunda pemupukan nitrogen."
    else:
        kondisi_wtp = "Suhu tidak dalam kategori khusus, tetap lakukan monitoring."

    if wrf > 5:
        kondisi_wrf = "Tidak perlu penyiraman tambahan."
    elif 2 <= wrf <= 5:
        kondisi_wrf = "Kurangi volume penyiraman 50%."
    elif wrf < 2:
        kondisi_wrf = "Lakukan penyiraman normal sesuai kondisi kelembaban tanah."
    else:
        kondisi_wrf = "Data curah hujan tidak valid."

    if sn < 50:
        kondisi_sn = "Defisiensi nitrogen, daun menguning. Perlu pemupukan Urea"
    elif 50 <= sn < 150:
        kondisi_sn = "Cukup untuk fase vegetatif awal"
    elif 150 <= sn <= 250:
        kondisi_sn = "Optimal untuk pertumbuhan padi"
    elif sn > 300:
        kondisi_sn = "Kelebihan nitrogen, rentan hama & penyakit blast"
    else:
        kondisi_sn = "Kadar nitrogen di zona transisi, tetap monitor"

    if sp < 87:
        kondisi_sp = "Status P rendah → dosis SP-36 = 100 kg/ha"
    elif 87 <= sp <= 174:
        kondisi_sp = "Status P sedang → dosis SP-36 = 75 kg/ha"
    else:
        kondisi_sp = "Status P tinggi → dosis SP-36 = 50 kg/ha"

    if sk < 83:
        kondisi_sk = "K rendah → KCl = 100 kg/ha (tanpa jerami)"
    elif 83 <= sk <= 166:
        kondisi_sk = "K sedang → KCl = 50 kg/ha (tanpa jerami)"
    else:
        kondisi_sk = "K tinggi → KCl = 50 kg/ha (tanpa jerami)"

    teks = (
        f"Kelembaban tanah : {sm}% — {kondisi_sm}\n"
        f"pH tanah         : {sph} — {kondisi_ph}\n"
        f"Suhu udara       : {wtp}°C — {kondisi_wtp}\n"
        f"Curah hujan      : {wrf} mm — {kondisi_wrf}\n"
        f"Nitrogen         : {sn} mg/kg — {kondisi_sn}\n"
        f"Fosfor           : {sp} mg/kg — {kondisi_sp}\n"
        f"Kalium           : {sk} mg/kg — {kondisi_sk}"
    )
    return teks.strip()


# 2. RETRIEVE HYBRID
def retrieve_hybrid(query: str, top_k: int = 3, candidates: int = 6) -> list[dict]:
    query_embedding = _embedder.encode([query]).tolist()
    dense_res  = _collection.query(query_embeddings=query_embedding, n_results=candidates)
    dense_ids  = dense_res["ids"][0]

    tokenized_query = re.findall(r"\w+", query.lower())
    bm25_scores     = _bm25.get_scores(tokenized_query)
    sparse_ranked   = sorted(range(len(bm25_scores)), key=lambda i: bm25_scores[i], reverse=True)
    sparse_ids      = [_chunks[i]["chunk_id"] for i in sparse_ranked[:candidates]]

    rrf_scores: dict[str, float] = {}
    for rank, cid in enumerate(dense_ids):
        rrf_scores[cid] = rrf_scores.get(cid, 0.0) + 1 / (60 + rank)
    for rank, cid in enumerate(sparse_ids):
        rrf_scores[cid] = rrf_scores.get(cid, 0.0) + 1 / (60 + rank)

    final_ids = sorted(rrf_scores, key=rrf_scores.get, reverse=True)

    results: list[dict] = []
    for cid in final_ids:
        chunk = _chunk_map.get(cid)
        if chunk is None:
            # BUG-007 (fixed): sebelumnya _chunk_map[cid] langsung dipanggil
            # dan crash KeyError kalau ChromaDB menyimpan chunk_id basi yang
            # sudah tidak ada di chunks_2.json terkini (lihat validasi di
            # init_rag()). Sekarang: skip chunk ini, jangan sampai satu ID
            # basi bikin seluruh request /chat atau /analyze gagal 500.
            logger.warning(
                "chunk_id '%s' dari hasil retrieval tidak ditemukan di "
                "_chunk_map — kemungkinan ChromaDB stale (lihat log startup "
                "init_rag()). Chunk ini dilewati.",
                cid,
            )
            continue
        results.append({
            "chunk_id": cid,
            "title":    chunk["title"],
            "text":     chunk["text"],
            "score":    round(rrf_scores[cid], 6),
        })
        if len(results) >= top_k:
            break

    return results


# 3. FORMAT CONTEXT
def format_context(chunks: list[dict]) -> str:
    parts = []
    for i, c in enumerate(chunks, 1):
        parts.append(f"[Referensi {i}: {c['title']}]\n{c['text']}")
    return "\n\n---\n\n".join(parts)


# 4. BUILD PROMPT
def build_prompt(
    sensor_text:  Optional[str],
    context:      str,
    time:         Optional[str] = None,
    user_message: Optional[str] = None,
    history:      Optional[list[dict]] = None,
) -> list[dict]:
    """
    Menyusun messages untuk LLM.

    Args:
        sensor_text:  output parse_sensor(), atau None untuk chat mandiri
        context:      output format_context()
        time:         timestamp sensor, atau None
        user_message: pertanyaan petani (None = analisis otomatis dari sensor)
        history:      riwayat chat sebelumnya

    Jika sensor_text=None (chat mandiri):
        → system prompt tidak menyertakan bagian data sensor
        → LLM tetap bisa menjawab pertanyaan umum padi dari knowledge base
    """
    # System prompt ─────
    base_intro = (
        "Kamu adalah sistem rekomendasi pertanian padi berbasis AI bernama TanyaPadi. "
        "Tugasmu adalah memberikan rekomendasi penyiraman dan penanaman padi "
        "berdasarkan panduan pertanian berikut.\n\n"
        f"PANDUAN PERTANIAN (dari knowledge base):\n{context}"
    )

    if sensor_text is not None:
        # Sesi analisis — sertakan data sensor
        sensor_section = (
            f"\n\nDATA SENSOR LAHAN SAWAH (AWS-003)\n"
            f"Waktu pembacaan: {time or '-'}\n"
            f"{sensor_text}"
        )
        system_content = base_intro + sensor_section
    else:
        # Chat mandiri — tanpa data sensor
        system_content = (
            base_intro
            + "\n\nCatatan: Tidak ada data sensor aktif saat ini. "
            "Jawab pertanyaan petani berdasarkan panduan pertanian di atas."
        )

    system_content += "\n\nSelalu jawab dalam Bahasa Indonesia yang jelas dan mudah dipahami petani."

    messages = [{"role": "system", "content": system_content}]

    # History
    if history:
        messages.extend(history)

    # Pesan user saat ini
    if user_message:
        messages.append({"role": "user", "content": user_message})
    else:
        # Analisis otomatis (hanya dipanggil dari /analyze, sensor_text pasti ada)
        messages.append({
            "role": "user",
            "content": (
                "Berdasarkan data sensor di atas, berikan rekomendasi terstruktur mencakup:\n"
                "1. REKOMENDASI PENYIRAMAN: perlu disiram atau tidak, kapan, dan berapa banyak\n"
                "2. REKOMENDASI PEMUPUKAN: pupuk apa yang perlu ditambahkan (jika ada)\n"
                "3. KONDISI TANAH: apakah perlu koreksi pH atau kondisi lainnya\n"
                "4. PERINGATAN: kondisi yang perlu diwaspadai\n"
                "5. STATUS KESELURUHAN: Baik / Perlu Perhatian / Kritis"
            ),
        })

    return messages


# 5. GENERATE
def generate(messages: list[dict], llm: str = "groq") -> str:
    if llm == "groq":
        api_key = os.getenv("GROQ_API_KEY")
        if not api_key:
            raise ValueError("GROQ_API_KEY tidak ditemukan di .env")
        client   = Groq(api_key=api_key)
        response = client.chat.completions.create(
            model="llama-3.3-70b-versatile",
            messages=messages,
        )
        return response.choices[0].message.content

    elif llm == "gemini":
        api_key = os.getenv("GEMINI_API_KEY")
        if not api_key:
            raise ValueError("GEMINI_API_KEY tidak ditemukan di .env")
        client = google.genai.Client(api_key=api_key)
        full_prompt = "\n\n".join(
            f"[{m['role'].upper()}]: {m['content']}" for m in messages
        )
        response = client.models.generate_content(
            model="gemini-2.0-flash",
            contents=full_prompt,
        )
        return response.text

    else:
        raise ValueError(f"LLM tidak dikenal: {llm}. Gunakan 'groq' atau 'gemini'.")