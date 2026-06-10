"""Agent 4 : Vérification assurance — validité, cohérence plaque/assuré."""
import logging
from datetime import date
from .base_agent import BaseAgent

logger = logging.getLogger(__name__)


class InsuranceAgent(BaseAgent):
    name = "InsuranceAgent"

    def process(self, context: dict) -> dict:
        ocr             = context.get("ocr_results", {}).get("results", {})
        vehicle_profile = context.get("vehicle_profile", {})
        driver_profile  = context.get("driver_profile", {})

        checks = {}
        issues = []

        insurance_data = ocr.get("INSURANCE", {}).get("data", {})

        # --- Présence de l'attestation ---
        docs_present = context.get("documents_present", {})
        checks["insurance_present"] = bool(docs_present.get("INSURANCE"))
        if not checks["insurance_present"]:
            issues.append("Attestation d'assurance manquante")
            return {
                "checks": checks,
                "issues": issues,
                "insurance_score": 0,
                "insurance_valid": False,
            }

        # --- Date d'expiration ---
        exp_str = insurance_data.get("date_expiration", "")
        insurance_valid_date = False
        if exp_str:
            try:
                from datetime import datetime
                exp_date = datetime.strptime(str(exp_str), "%Y-%m-%d").date()
                insurance_valid_date = exp_date >= date.today()
                checks["insurance_not_expired"] = insurance_valid_date
                if not insurance_valid_date:
                    issues.append(f"Assurance expirée le {exp_str}")
            except ValueError:
                checks["insurance_date_readable"] = False
                issues.append("Date d'expiration assurance illisible")
        else:
            checks["insurance_date_present"] = False
            issues.append("Date d'expiration assurance absente dans l'OCR")

        # --- Cohérence plaque ---
        ins_plaque  = (insurance_data.get("plaque") or "").strip().upper().replace(" ", "")
        prof_plaque = (vehicle_profile.get("plaque") or "").strip().upper().replace(" ", "")
        if ins_plaque and prof_plaque:
            match = ins_plaque == prof_plaque
            checks["plaque_match"] = match
            if not match:
                issues.append(f"Plaque assurance '{ins_plaque}' ≠ profil '{prof_plaque}'")

        # --- Nom assuré ---
        ins_nom    = (insurance_data.get("nom_assure") or "").strip().upper()
        driver_nom = (driver_profile.get("last_name") or "").strip().upper()
        if ins_nom and driver_nom:
            match = driver_nom in ins_nom or ins_nom in driver_nom
            checks["nom_assure_match"] = match
            if not match:
                issues.append(f"Nom assuré '{ins_nom}' ≠ conducteur '{driver_nom}'")

        total  = max(len(checks), 1)
        passed = sum(1 for v in checks.values() if v)
        score  = round((passed / total) * 100, 1)

        return {
            "checks": checks,
            "issues": issues,
            "insurance_score": score,
            "insurance_valid": insurance_valid_date and checks.get("insurance_present", False),
            "insurance_expiration": exp_str,
        }
