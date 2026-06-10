"""Agent 5 : Contrôle technique — validité et cohérence plaque."""
import logging
from datetime import date
from .base_agent import BaseAgent

logger = logging.getLogger(__name__)


class TechnicalInspectionAgent(BaseAgent):
    name = "TechnicalInspectionAgent"

    def process(self, context: dict) -> dict:
        ocr             = context.get("ocr_results", {}).get("results", {})
        vehicle_profile = context.get("vehicle_profile", {})
        docs_present    = context.get("documents_present", {})

        checks = {}
        issues = []

        checks["ct_present"] = bool(docs_present.get("TECHNICAL_INSPECTION"))
        if not checks["ct_present"]:
            issues.append("Certificat de contrôle technique manquant")
            return {
                "checks": checks,
                "issues": issues,
                "technical_score": 0,
                "technical_valid": False,
            }

        ct_data = ocr.get("TECHNICAL_INSPECTION", {}).get("data", {})

        # --- Validité ---
        val_str = ct_data.get("date_validite", "")
        ct_valid_date = False
        if val_str:
            try:
                from datetime import datetime
                val_date = datetime.strptime(str(val_str), "%Y-%m-%d").date()
                ct_valid_date = val_date >= date.today()
                checks["ct_not_expired"] = ct_valid_date
                if not ct_valid_date:
                    issues.append(f"Contrôle technique expiré le {val_str}")
            except ValueError:
                checks["ct_date_readable"] = False
                issues.append("Date validité contrôle technique illisible")
        else:
            checks["ct_date_present"] = False
            issues.append("Date de validité CT absente dans l'OCR")

        # --- Plaque ---
        ct_plaque   = (ct_data.get("plaque") or "").strip().upper().replace(" ", "")
        prof_plaque = (vehicle_profile.get("plaque") or "").strip().upper().replace(" ", "")
        if ct_plaque and prof_plaque:
            match = ct_plaque == prof_plaque
            checks["plaque_match"] = match
            if not match:
                issues.append(f"Plaque CT '{ct_plaque}' ≠ profil '{prof_plaque}'")

        # --- Résultat (favorable / défavorable) ---
        resultat = (ct_data.get("resultat") or "").upper()
        if resultat:
            favorable = any(kw in resultat for kw in ["FAVORABLE", "SATISFAISANT", "OK", "PASS", "VALIDE"])
            checks["ct_result_favorable"] = favorable
            if not favorable:
                issues.append(f"Résultat CT non favorable: {resultat}")

        total  = max(len(checks), 1)
        passed = sum(1 for v in checks.values() if v)
        score  = round((passed / total) * 100, 1)

        return {
            "checks": checks,
            "issues": issues,
            "technical_score": score,
            "technical_valid": ct_valid_date and checks.get("ct_present", False),
            "ct_expiration": val_str,
        }
