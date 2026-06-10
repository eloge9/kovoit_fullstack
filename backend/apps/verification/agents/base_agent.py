"""Agent de base — contrat commun à tous les agents IA."""
import logging
from abc import ABC, abstractmethod
from typing import Any

logger = logging.getLogger(__name__)


class BaseAgent(ABC):
    name: str = "BaseAgent"

    @abstractmethod
    def process(self, context: dict) -> dict:
        """Traite le contexte et retourne un rapport structuré."""

    def run(self, context: dict) -> dict:
        try:
            result = self.process(context)
            result.setdefault("agent", self.name)
            result.setdefault("success", True)
            return result
        except Exception as exc:
            logger.exception("%s error: %s", self.name, exc)
            return {
                "agent":   self.name,
                "success": False,
                "error":   str(exc),
            }
