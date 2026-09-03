import os
from pathlib import Path

from dotenv import load_dotenv

load_dotenv()


def _get_setting(name: str, default=None):
	return os.getenv(name, default)


def _get_bool(name: str, default: bool) -> bool:
	value = _get_setting(name)
	if value is None:
		return default
	return str(value).strip().lower() in {"1", "true", "yes", "on"}


def _get_int(name: str, default: int) -> int:
	value = _get_setting(name)
	return default if value is None else int(value)


API_BASE_URL = _get_setting("API_BASE_URL")
GOOGLE_API_KEY = _get_setting("GOOGLE_API_KEY", "")
MONGO_URI = _get_setting("MONGO_URI")
TAVILY_API_KEY = _get_setting("TAVILY_API_KEY", "")
OLLAMA_HOST = _get_setting("OLLAMA_HOST", "https://ollama.com")
OLLAMA_MODEL = _get_setting("OLLAMA_MODEL", "gpt-oss:20b-cloud")
OLLAMA_API_KEY = _get_setting("OLLAMA_API_KEY", "")
HF_EMBEDDING_MODEL = _get_setting("HF_EMBEDDING_MODEL", "nomic-ai/nomic-embed-text-v1.5")
HF_EMBEDDING_DEVICE = _get_setting("HF_EMBEDDING_DEVICE", "cpu")
HF_EMBEDDING_BATCH_SIZE = _get_int("HF_EMBEDDING_BATCH_SIZE", 8)

RETRIEVAL_K = _get_int("RETRIEVAL_K", 10)
RERANK_TOP_N = _get_int("RERANK_TOP_N", 5)
ENABLE_RERANKER = _get_bool("ENABLE_RERANKER", True)
FAST_MODE = _get_bool("FAST_MODE", False)

LOG_LEVEL = _get_setting("LOG_LEVEL", "INFO")
LOG_FILE = _get_setting("LOG_FILE", str(Path(__file__).resolve().parent / "log" / "app.log"))

HOST = _get_setting("HOST", "0.0.0.0")
PORT = _get_int("PORT", 5000)
OTEL_SERVICE_NAME = _get_setting("OTEL_SERVICE_NAME", "rag-chat-api")
APPLICATIONINSIGHTS_CONNECTION_STRING = _get_setting("APPLICATIONINSIGHTS_CONNECTION_STRING", "")