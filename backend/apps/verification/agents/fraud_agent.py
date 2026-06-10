"""Agent 6 : Détection de fraude — documents falsifiés, deepfake, cohérence métadonnées."""
import base64
import json
import logging
import os
from pathlib import Path

from .base_agent import BaseAgent

logger = logging.getLogger(__name__)


def _call_claude_fraud_check(file_path: str) -> dict:
    """Demande à Claude d'analyser un document pour détecter une fraude."""
    api_key = os.getenv("ANTHROPIC_API_KEY", "")
    if not api_key:
        return {"fraud_indicators": [], "fraud_probability": 0, "note": "API non configurée"}

    import anthropic

    ext = Path(file_path).suffix.lower()
    mime_map = {".jpg": "image/jpeg", ".jpeg": "image/jpeg",
                ".png": "image/png", ".webp": "image/webp",
                ".pdf": "application/pdf"}
    mime = mime_map.get(ext, "image/jpeg")

    with open(file_path, "rb") as f:
        b64 = base64.standard_b64encode(f.read()).decode()

    prompt = """
Analyse ce document officiel pour détecter des signes de fraude ou de falsification.
Retourne uniquement un JSON avec ces champs :
{
  "fraud_indicators": ["liste des indicateurs détectés"],
  "fraud_probability": 0-100,
  "is_likely_ai_generated": false,
  "image_quality": "good|poor|suspicious",
  "text_consistency": "consistent|inconsistent|partially_consistent",
  "font_uniformity": "uniform|suspicious_variations",
  "signature_present": false,
  "seal_present": false,
  "overall_assessment": "genuine|suspicious|likely_fake"
}
Réponds UNIQUEMENT avec le JSON.
"""

    client = anthropic.Anthropic(api_key=api_key)
    message = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=512,
        messages=[{
            "role": "user",
            "content": [
                {"type": "image", "source": {"type": "base64", "media_type": mime, "data": b64}},
                {"type": "text", "text": prompt},
            ],
        }],
    )
    raw = message.content[0].text.strip()
    if raw.startswith("```"):
        raw = raw.split("```")[1]
        if raw.startswith("json"):
            raw = raw[4:]
    try:
        return json.loads(raw.strip())
    except json.JSONDecodeError:
        return {"fraud_probability": 50, "overall_assessment": "suspicious", "parse_error": True}


class FraudDetectionAgent(BaseAgent):
    name = "FraudDetectionAgent"

    # Documents à analyser prioritairement pour la fraude
    PRIORITY_DOCS = ["CNI", "DRIVING_LICENSE", "VEHICLE_REGISTRATION", "INSURANCE"]

    def process(self, context: dict) -> dict:
        file_paths   = context.get("file_paths", {})
        docs_present = context.get("documents_present", {})

        doc_results    = {}
        total_fraud_p  = 0
        analyzed_count = 0

        for doc_type in self.PRIORITY_DOCS:
            path = file_paths.get(doc_type)
            if not path or not Path(path).exists():
                continue
            result          = _call_claude_fraud_check(path)
            doc_results[doc_type] = result
            total_fraud_p  += result.get("fraud_probability", 0)
            analyzed_count += 1

        avg_fraud_score = round(total_fraud_p / max(analyzed_count, 1), 1)

        # Indicateurs globaux
        suspicious_docs = [
            doc for doc, res in doc_results.items()
            if res.get("overall_assessment") in ["suspicious", "likely_fake"]
        ]

        all_indicators = []
        for res in doc_results.values():
            all_indicators.extend(res.get("fraud_indicators", []))

        fraud_level = "low"
        if avg_fraud_score >= 60:
            fraud_level = "high"
        elif avg_fraud_score >= 30:
            fraud_level = "medium"

        return {
            "fraud_score": avg_fraud_score,
            "fraud_level": fraud_level,
            "suspicious_documents": suspicious_docs,
            "fraud_indicators": list(set(all_indicators)),
            "document_results": doc_results,
            "fraud_detected": avg_fraud_score >= 50 or len(suspicious_docs) >= 2,
        }
