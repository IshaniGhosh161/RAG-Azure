import logging
import os
from pathlib import Path
from backend.config import LOG_LEVEL, LOG_FILE

def configure_logging() -> None:
    """Configure application-wide logging once for console and optional file output."""
    if logging.getLogger().handlers:
        return

    level_name = LOG_LEVEL.upper()
    level = getattr(logging, level_name, logging.INFO)
    formatter = logging.Formatter(
        "%(asctime)s %(levelname)s [%(name)s] %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )

    console_handler = logging.StreamHandler()
    console_handler.setFormatter(formatter)
    handlers = [console_handler]

    log_file = LOG_FILE
    if log_file:
        Path(log_file).parent.mkdir(parents=True, exist_ok=True)
        file_handler = logging.FileHandler(log_file, encoding="utf-8")
        file_handler.setFormatter(formatter)
        handlers.append(file_handler)

    logging.basicConfig(level=level, handlers=handlers, force=True)


configure_logging()
