import os
import sys
from langchain_ollama import ChatOllama
import logging

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from backend import logging_config
from backend.config import OLLAMA_API_KEY

logger = logging.getLogger(__name__)
os.environ["OLLAMA_API_KEY"] = OLLAMA_API_KEY
llm = ChatOllama(
    model="gpt-oss:120b-cloud",
    temperature=0
)

response = llm.invoke(
    "Explain LangGraph in simple terms"
)

logger.info("Ollama response: %s", response.content)