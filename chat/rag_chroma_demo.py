"""
Demo mínimo de RAG con Chroma + embeddings (Sentence-Transformers) + generación con Transformers.

Requisitos (CPU):
  pip install chromadb sentence-transformers transformers accelerate
  pip install --index-url https://download.pytorch.org/whl/cpu torch

Ejecución:
  python rag_chroma_demo.py
"""
from __future__ import annotations

import os
from typing import List

from utils.logger import get_logger

# Embeddings y Vector Store
import chromadb
from chromadb.config import Settings
from chromadb.utils import embedding_functions

# Generación (LLM pequeño)
from transformers import pipeline

logger = get_logger(__name__)

# ----------------------------------------------------------------------------
# Configuración
# ----------------------------------------------------------------------------
PERSIST_DIR = os.path.join(os.path.dirname(__file__), ".chroma")
COLLECTION_NAME = "docs_ajo_negro"
EMBED_MODEL = "intfloat/multilingual-e5-small"  # embeddings multilingües ligeros
GEN_MODEL = os.getenv("HF_GEN_MODEL", "Qwen/Qwen2.5-1.5B-Instruct")  # alterna: TinyLlama/TinyLlama-1.1B-Chat-v1.0
TOP_K = 3

# ----------------------------------------------------------------------------
# Datos de ejemplo (dominio: ajo negro)
# ----------------------------------------------------------------------------
DOCS = [
    {
        "id": "d1",
        "text": "El ajo negro se obtiene por un proceso de fermentación controlada del ajo fresco.",
        "meta": {"fuente": "manual", "tema": "proceso"},
    },
    {
        "id": "d2",
        "text": "El proceso suele durar entre 2 y 4 semanas manteniendo temperatura y humedad constantes.",
        "meta": {"fuente": "manual", "tema": "tiempos"},
    },
    {
        "id": "d3",
        "text": "El sabor del ajo negro es dulce y umami, con menor pungencia que el ajo crudo.",
        "meta": {"fuente": "manual", "tema": "sabor"},
    },
    {
        "id": "d4",
        "text": "Durante la fermentación se favorecen reacciones de Maillard que oscurecen los bulbos.",
        "meta": {"fuente": "manual", "tema": "quimica"},
    },
    {
        "id": "d5",
        "text": "El ajo negro puede emplearse en salsas, pastas, carnes y postres por su perfil umami-dulce.",
        "meta": {"fuente": "manual", "tema": "usos"},
    },
    {
        "id": "d6",
        "text": "Controlar la actividad de agua y evitar contaminación es clave para un lote consistente.",
        "meta": {"fuente": "manual", "tema": "calidad"},
    },
]

# ----------------------------------------------------------------------------
# Setup Chroma + embeddings
# ----------------------------------------------------------------------------

def get_chroma_collection():
    os.makedirs(PERSIST_DIR, exist_ok=True)

    client = chromadb.PersistentClient(path=PERSIST_DIR, settings=Settings(anonymized_telemetry=False))
    emb_fn = embedding_functions.SentenceTransformerEmbeddingFunction(
        model_name=EMBED_MODEL,
        device="cpu",  # ajusta a "cuda" si tienes GPU
    )

    col = client.get_or_create_collection(
        name=COLLECTION_NAME,
        embedding_function=emb_fn,
        metadata={"desc": "Documentos de ejemplo sobre el proceso del ajo negro"},
    )
    return col


def ensure_index_seed_data():
    col = get_chroma_collection()
    existing = col.count()
    if existing and existing >= len(DOCS):
        logger.info(f"Colección ya poblada (docs={existing}).")
        return col

    # Limpia y vuelve a indexar
    if existing:
        logger.info("Reseteando colección para reindexar datos de ejemplo…")
        col.delete(where={})

    logger.info("Indexando documentos de ejemplo en Chroma…")
    col.add(
        ids=[d["id"] for d in DOCS],
        documents=[d["text"] for d in DOCS],
        metadatas=[d["meta"] for d in DOCS],
    )
    logger.info(f"Indexados {len(DOCS)} documentos.")
    return col


# ----------------------------------------------------------------------------
# Recuperación (R) + Generación (G)
# ----------------------------------------------------------------------------

def retrieve(query: str, k: int = TOP_K) -> List[str]:
    col = ensure_index_seed_data()
    res = col.query(query_texts=[query], n_results=k)
    docs = res.get("documents", [[]])[0]
    return docs


def build_prompt(context_chunks: List[str], question: str) -> str:
    context = "\n".join(f"- {c}" for c in context_chunks)
    prompt = (
        "Eres un asistente en español. Responde SOLO usando el contexto dado.\n"
        "Si la respuesta no está en el contexto, di que no hay información suficiente.\n\n"
        f"Contexto:\n{context}\n\nPregunta: {question}\nRespuesta concisa:"
    )
    return prompt


def generate_answer(prompt: str) -> str:
    logger.info(f"Usando modelo generativo: {GEN_MODEL}")
    gen = pipeline("text-generation", model=GEN_MODEL)
    out = gen(prompt, max_new_tokens=256, temperature=0.3, top_p=0.9)[0]["generated_text"]
    return out


def answer(question: str, k: int = TOP_K) -> str:
    chunks = retrieve(question, k=k)
    prompt = build_prompt(chunks, question)
    return generate_answer(prompt)


if __name__ == "__main__":
    q = "¿Cuánto tarda el proceso para obtener ajo negro?"
    logger.info(f"Pregunta: {q}")
    resp = answer(q)
    print("\n--- Respuesta ---\n")
    print(resp)
