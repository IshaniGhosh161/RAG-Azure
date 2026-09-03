import logging

from fastapi import FastAPI
from backend.config import APPLICATIONINSIGHTS_CONNECTION_STRING, OTEL_SERVICE_NAME
from azure.monitor.opentelemetry import configure_azure_monitor
from opentelemetry import metrics
from opentelemetry import trace
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor

logger = logging.getLogger(__name__)

meter = metrics.get_meter(OTEL_SERVICE_NAME)
RAG_QUESTIONS_TOTAL = meter.create_counter("rag_questions_total")
RAG_RESPONSE_LATENCY_SECONDS = meter.create_histogram("rag_response_latency_seconds", unit="s")
RAG_TOKENS_PER_QUESTION = meter.create_histogram("rag_tokens_per_question", unit="tokens")
RAG_TOKEN_COST_PER_QUESTION = meter.create_histogram("rag_token_cost_per_question", unit="USD")
RAG_TOKENS_TOTAL = meter.create_counter("rag_tokens_total", unit="tokens")
RAG_TOKEN_COST_TOTAL = meter.create_counter("rag_token_cost_total", unit="USD")
RAG_WEB_SEARCH_TOTAL = meter.create_counter("rag_web_search_total")
RAG_LLM_CALLS_TOTAL = meter.create_counter("rag_llm_calls_total")
TOKEN_COST_PER_1K_TOKENS = 0.005


def estimate_tokens(text: str) -> int:
    cleaned = (text or "").strip()
    if not cleaned:
        return 0
    return max(1, len(cleaned.split()))


def record_llm_usage(prompt: str | None, response_text: str | None = None) -> None:
    prompt_tokens = estimate_tokens(prompt or "")
    response_tokens = estimate_tokens(response_text or "")
    total_tokens = prompt_tokens + response_tokens
    if not total_tokens:
        return

    total_cost = (total_tokens / 1000) * TOKEN_COST_PER_1K_TOKENS
    RAG_TOKENS_TOTAL.inc(total_tokens)
    RAG_TOKEN_COST_TOTAL.inc(total_cost)
    RAG_LLM_CALLS_TOTAL.inc()


def record_rag_metrics(question: str, response: str, latency_seconds: float) -> None:
    if not question:
        return

    total_tokens = estimate_tokens(question) + estimate_tokens(response)
    per_question_cost = (total_tokens / 1000) * TOKEN_COST_PER_1K_TOKENS
    RAG_QUESTIONS_TOTAL.inc()
    RAG_RESPONSE_LATENCY_SECONDS.observe(latency_seconds)
    RAG_TOKENS_PER_QUESTION.observe(total_tokens)
    RAG_TOKEN_COST_PER_QUESTION.observe(per_question_cost)


def configure_observability(app: FastAPI) -> None:
    if APPLICATIONINSIGHTS_CONNECTION_STRING:
        configure_azure_monitor(
            connection_string=APPLICATIONINSIGHTS_CONNECTION_STRING,
            service_name=OTEL_SERVICE_NAME,
        )
        logger.info("Azure Monitor configured for %s", OTEL_SERVICE_NAME)
    else:
        logger.warning("Application Insights connection string is not configured")
    FastAPIInstrumentor.instrument_app(app)
