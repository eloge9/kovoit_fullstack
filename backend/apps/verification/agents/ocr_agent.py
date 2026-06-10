"""Agent OCR — extrait le texte et structure les données des documents.

Fournisseur configuré via la variable d'environnement VISION_PROVIDER :
  - "gemini"    (défaut) : Google Gemini 1.5 Flash — gratuit, 1500 req/jour
  - "anthropic"          : Claude Sonnet — payant, très haute qualité

Clés nécessaires :
  VISION_PROVIDER=gemini      → GEMINI_API_KEY   (gratuit sur ai.google.dev)
  VISION_PROVIDER=anthropic   → ANTHROPIC_API_KEY (payant sur console.anthropic.com)
"""
import base64
import json
import logging
import os
from pathlib import Path

from .base_agent import BaseAgent

logger = logging.getLogger(__name__)


def _encode_file(file_path: str) -> tuple[str, str]:
    ext = Path(file_path).suffix.lower()
    mime_map = {
        ".jpg":  "image/jpeg",
        ".jpeg": "image/jpeg",
        ".png":  "image/png",
        ".webp": "image/webp",
        ".pdf":  "application/pdf",
    }
    mime = mime_map.get(ext, "image/jpeg")
    with open(file_path, "rb") as f:
        return base64.standard_b64encode(f.read()).decode("utf-8"), mime


def _call_gemini_vision(prompt: str, file_path: str) -> str:
    """Appel Google Gemini 1.5 Flash — gratuit (1500 req/jour)."""
    api_key = os.getenv("GEMINI_API_KEY", "")
    if not api_key:
        raise RuntimeError("GEMINI_API_KEY non configuré — obtenez une clé gratuite sur https://ai.google.dev")

    import google.generativeai as genai

    genai.configure(api_key=api_key)
    model = genai.GenerativeModel("gemini-1.5-flash")

    b64, mime = _encode_file(file_path)

    # Gemini accepte l'image en inline_data base64
    image_part = {"inline_data": {"mime_type": mime, "data": b64}}
    response = model.generate_content([image_part, prompt])
    return response.text


def _call_claude_vision(prompt: str, file_path: str) -> str:
    """Appel Claude Sonnet — payant, qualité maximale."""
    api_key = os.getenv("ANTHROPIC_API_KEY", "")
    if not api_key:
        raise RuntimeError("ANTHROPIC_API_KEY non configuré")

    import anthropic

    b64, mime = _encode_file(file_path)
    client = anthropic.Anthropic(api_key=api_key)

    source: dict = {"type": "base64", "media_type": mime, "data": b64}
    message = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=1024,
        messages=[{
            "role": "user",
            "content": [
                {"type": "image", "source": source},
                {"type": "text", "text": prompt},
            ],
        }],
    )
    return message.content[0].text


def _call_vision_model(prompt: str, file_path: str) -> str:
    """Dispatche vers le bon fournisseur selon VISION_PROVIDER."""
    provider = os.getenv("VISION_PROVIDER", "gemini").lower()
    if provider == "anthropic":
        return _call_claude_vision(prompt, file_path)
    return _call_gemini_vision(prompt, file_path)


class OcrAgent(BaseAgent):
    """
    Agent 1 : OCR + validation du type de document.
    Chaque prompt demande à Claude de vérifier que l'image est bien le bon
    type de document AVANT d'extraire les données.
    """
    name = "OcrAgent"

    # Les champs obligatoires qui DOIVENT être présents pour que le document soit valide
    REQUIRED_FIELDS: dict[str, list[str]] = {
        "CNI":                  ["nom", "prenom", "date_expiration", "numero_document"],
        "DRIVING_LICENSE":      ["nom", "prenom", "numero_permis", "date_expiration"],
        "VEHICLE_REGISTRATION": ["plaque", "marque", "modele", "proprietaire_nom"],
        "INSURANCE":            ["plaque", "date_expiration", "nom_assure"],
        "TECHNICAL_INSPECTION": ["plaque", "date_validite", "resultat"],
    }

    PROMPTS = {
        "CNI": """
Analyse cette image.

ÉTAPE 1 — Vérifie que c'est bien une carte nationale d'identité (CNI) ou une pièce d'identité officielle.
Si l'image NE montre PAS une CNI/pièce d'identité (ex: photo de paysage, facture, image aléatoire),
réponds UNIQUEMENT :
{"document_valid": false, "reason": "Ce n'est pas une CNI"}

ÉTAPE 2 — Si c'est bien une CNI, extrais les données :
{
  "document_valid": true,
  "nom": "",
  "prenom": "",
  "date_naissance": "YYYY-MM-DD",
  "lieu_naissance": "",
  "numero_document": "",
  "date_emission": "YYYY-MM-DD",
  "date_expiration": "YYYY-MM-DD",
  "sexe": "",
  "nationalite": "",
  "adresse": ""
}
Réponds UNIQUEMENT avec le JSON, sans texte supplémentaire.
""",
        "PASSPORT": """
Analyse cette image.
ÉTAPE 1 — Vérifie que c'est un passeport officiel.
Si non, réponds : {"document_valid": false, "reason": "Ce n'est pas un passeport"}
ÉTAPE 2 — Si oui :
{
  "document_valid": true,
  "nom": "", "prenom": "", "numero_document": "",
  "date_naissance": "YYYY-MM-DD", "date_expiration": "YYYY-MM-DD",
  "nationalite": "", "sexe": "", "lieu_naissance": ""
}
Réponds UNIQUEMENT avec le JSON.
""",
        "DRIVING_LICENSE": """
Analyse cette image.

ÉTAPE 1 — Vérifie que c'est bien un permis de conduire officiel.
Si l'image NE montre PAS un permis de conduire, réponds UNIQUEMENT :
{"document_valid": false, "reason": "Ce n'est pas un permis de conduire"}

ÉTAPE 2 — Si c'est bien un permis de conduire :
{
  "document_valid": true,
  "nom": "",
  "prenom": "",
  "date_naissance": "YYYY-MM-DD",
  "numero_permis": "",
  "categories": [],
  "date_emission": "YYYY-MM-DD",
  "date_expiration": "YYYY-MM-DD",
  "autorite_delivrance": "",
  "lieu_delivrance": ""
}
Réponds UNIQUEMENT avec le JSON.
""",
        "VEHICLE_REGISTRATION": """
Analyse cette image.

ÉTAPE 1 — Vérifie que c'est bien une carte grise (certificat d'immatriculation) d'un véhicule.
Si l'image NE montre PAS une carte grise, réponds UNIQUEMENT :
{"document_valid": false, "reason": "Ce n'est pas une carte grise"}

ÉTAPE 2 — Si c'est bien une carte grise :
{
  "document_valid": true,
  "proprietaire_nom": "",
  "proprietaire_prenom": "",
  "plaque": "",
  "marque": "",
  "modele": "",
  "annee": "",
  "numero_chassis": "",
  "type_vehicule": "",
  "couleur": "",
  "date_emission": "YYYY-MM-DD",
  "energie": ""
}
Réponds UNIQUEMENT avec le JSON.
""",
        "INSURANCE": """
Analyse cette image.

ÉTAPE 1 — Vérifie que c'est bien une attestation ou police d'assurance véhicule.
Si l'image NE montre PAS un document d'assurance véhicule, réponds UNIQUEMENT :
{"document_valid": false, "reason": "Ce n'est pas une attestation d'assurance"}

ÉTAPE 2 — Si c'est bien une attestation d'assurance :
{
  "document_valid": true,
  "compagnie": "",
  "numero_contrat": "",
  "nom_assure": "",
  "plaque": "",
  "marque_vehicule": "",
  "date_debut": "YYYY-MM-DD",
  "date_expiration": "YYYY-MM-DD",
  "type_garantie": ""
}
Réponds UNIQUEMENT avec le JSON.
""",
        "TECHNICAL_INSPECTION": """
Analyse cette image.

ÉTAPE 1 — Vérifie que c'est bien un certificat de contrôle technique de véhicule.
Si l'image NE montre PAS un contrôle technique, réponds UNIQUEMENT :
{"document_valid": false, "reason": "Ce n'est pas un certificat de contrôle technique"}

ÉTAPE 2 — Si c'est bien un certificat de contrôle technique :
{
  "document_valid": true,
  "plaque": "",
  "marque": "",
  "date_inspection": "YYYY-MM-DD",
  "date_validite": "YYYY-MM-DD",
  "centre_controle": "",
  "resultat": "",
  "numero_certificat": ""
}
Réponds UNIQUEMENT avec le JSON.
""",
        # Documents photo — on demande seulement si c'est lisible
        "SELFIE_ID": """
Analyse cette image. Est-ce que l'image montre clairement une personne tenant une pièce d'identité ?
Réponds UNIQUEMENT :
{"document_valid": true/false, "reason": "explication si invalide", "face_visible": true/false, "id_visible": true/false}
""",
        "PORTRAIT": """
Analyse cette image. Est-ce que l'image montre clairement le visage d'une personne (photo portrait) ?
Réponds UNIQUEMENT :
{"document_valid": true/false, "reason": "explication si invalide", "face_visible": true/false}
""",
        "VEHICLE_FRONT":          '{"document_valid": true}',  # Vérifié par VehicleAgent
        "VEHICLE_REAR":           '{"document_valid": true}',
        "VEHICLE_LEFT":           '{"document_valid": true}',
        "VEHICLE_RIGHT":          '{"document_valid": true}',
        "VEHICLE_INTERIOR_FRONT": '{"document_valid": true}',
        "VEHICLE_INTERIOR_REAR":  '{"document_valid": true}',
        "DEFAULT": """
Analyse ce document officiel. Est-ce bien un document officiel lisible ?
Si non, réponds : {"document_valid": false, "reason": "description"}
Si oui :
{
  "document_valid": true, "nom": "", "prenom": "", "numero_document": "",
  "date_emission": "YYYY-MM-DD", "date_expiration": "YYYY-MM-DD",
  "type_document": "", "autres_infos": {}
}
Réponds UNIQUEMENT avec le JSON.
""",
    }

    def _is_valid_result(self, doc_type: str, data: dict) -> tuple[bool, str]:
        """Vérifie que les champs obligatoires sont présents et non vides."""
        if not data.get("document_valid", True):
            return False, data.get("reason", "Document non valide")

        required = self.REQUIRED_FIELDS.get(doc_type, [])
        missing = [f for f in required if not data.get(f)]
        if missing:
            return False, f"Champs manquants dans le document: {', '.join(missing)}"

        return True, ""

    def process(self, context: dict) -> dict:
        documents = context.get("documents", [])
        results = {}

        for doc in documents:
            doc_type  = doc.get("type", "DEFAULT")
            file_path = doc.get("file_path", "")

            if not file_path or not Path(file_path).exists():
                results[doc_type] = {"error": "Fichier introuvable", "success": False, "document_valid": False}
                continue

            # Les photos de véhicule sont traitées par VehicleAgent, on les marque juste présentes
            if doc_type in {"VEHICLE_FRONT", "VEHICLE_REAR", "VEHICLE_LEFT", "VEHICLE_RIGHT",
                            "VEHICLE_INTERIOR_FRONT", "VEHICLE_INTERIOR_REAR"}:
                results[doc_type] = {"data": {"document_valid": True}, "success": True, "document_valid": True}
                continue

            prompt = self.PROMPTS.get(doc_type, self.PROMPTS["DEFAULT"])
            try:
                raw = _call_vision_model(prompt, file_path)
                # Nettoyer le JSON potentiellement encadré par ```json
                raw = raw.strip()
                if raw.startswith("```"):
                    raw = raw.split("```")[1]
                    if raw.startswith("json"):
                        raw = raw[4:]
                parsed = json.loads(raw.strip())

                is_valid, reason = self._is_valid_result(doc_type, parsed)
                results[doc_type] = {
                    "data":           parsed,
                    "success":        True,
                    "document_valid": is_valid,
                    "invalid_reason": reason if not is_valid else "",
                    "raw":            raw,
                }
                if not is_valid:
                    logger.warning("OCR: document invalide type=%s reason=%s", doc_type, reason)

            except json.JSONDecodeError as exc:
                results[doc_type] = {
                    "error": f"JSON invalide: {exc}", "raw": raw if "raw" in dir() else "",
                    "success": False, "document_valid": False,
                }
            except Exception as exc:
                logger.warning("OCR failed for %s: %s", doc_type, exc)
                results[doc_type] = {"error": str(exc), "success": False, "document_valid": False}

        return {
            "results":               results,
            "documents_processed":   len(documents),
            "documents_succeeded":   sum(1 for r in results.values() if r.get("success")),
            "documents_valid":       sum(1 for r in results.values() if r.get("document_valid")),
        }
