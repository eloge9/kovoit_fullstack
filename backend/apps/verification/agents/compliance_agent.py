"""Agent 7 : Conformité réglementaire TOGO — formats, dates, pièces obligatoires."""
import logging
from datetime import date, datetime
from .base_agent import BaseAgent

logger = logging.getLogger(__name__)

REQUIRED_DOCS_TOGO = [
    "CNI", "SELFIE_ID", "PORTRAIT",
    "DRIVING_LICENSE",
    "VEHICLE_REGISTRATION",
    "INSURANCE",
    "TECHNICAL_INSPECTION",
    "VEHICLE_FRONT", "VEHICLE_REAR",
    "VEHICLE_LEFT", "VEHICLE_RIGHT",
    "VEHICLE_INTERIOR_FRONT", "VEHICLE_INTERIOR_REAR",
]

# Documents textuels dont l'OCR doit réussir (les photos sont vérifiées différemment)
OCR_VERIFIED_DOCS = {
    "CNI", "DRIVING_LICENSE", "VEHICLE_REGISTRATION", "INSURANCE", "TECHNICAL_INSPECTION",
    "SELFIE_ID", "PORTRAIT",
}

VALID_LICENSE_CATEGORIES_TOGO = ["B", "C", "D", "E", "B+E", "C+E"]


class ComplianceAgent(BaseAgent):
    name = "ComplianceAgent"

    def process(self, context: dict) -> dict:
        ocr          = context.get("ocr_results", {}).get("results", {})
        docs_present = context.get("documents_present", {})

        checks = {}
        issues = []
        invalid_docs  = []   # Documents présents mais invalides (mauvais type/illisibles)
        missing_docs  = []   # Documents absents

        # ── 1. Présence + validité OCR de chaque document obligatoire ─────────
        for doc_type in REQUIRED_DOCS_TOGO:
            present = bool(docs_present.get(doc_type))
            checks[f"doc_{doc_type.lower()}_present"] = present

            if not present:
                missing_docs.append(doc_type)
                issues.append(f"Document obligatoire manquant : {doc_type}")
                continue

            # Pour les documents textuels, vérifier que l'OCR a reconnu le bon type
            if doc_type in OCR_VERIFIED_DOCS:
                doc_ocr       = ocr.get(doc_type, {})
                ocr_success   = doc_ocr.get("success", False)
                doc_valid     = doc_ocr.get("document_valid", True)   # True par défaut = rétrocompat
                invalid_reason = doc_ocr.get("invalid_reason", "")

                readable = ocr_success and doc_valid
                checks[f"doc_{doc_type.lower()}_valid"] = readable
                if not readable:
                    invalid_docs.append(doc_type)
                    reason = invalid_reason or (
                        "Fichier illisible" if not ocr_success else "Document non conforme au type attendu"
                    )
                    issues.append(f"Document invalide ({doc_type}) : {reason}")

        # ── 2. Validité des dates ─────────────────────────────────────────────
        today = date.today()

        def _parse_date(date_str: str) -> date | None:
            try:
                return datetime.strptime(str(date_str), "%Y-%m-%d").date()
            except (ValueError, TypeError):
                return None

        # CNI
        cni_data = ocr.get("CNI", {}).get("data", {})
        cni_exp  = cni_data.get("date_expiration", "")
        if cni_exp:
            exp = _parse_date(cni_exp)
            if exp:
                checks["cni_valid"] = exp >= today
                if exp < today:
                    issues.append(f"CNI expirée le {cni_exp}")
            else:
                checks["cni_date_format"] = False
                issues.append("Format date CNI invalide")

        # Permis de conduire
        lic_data = ocr.get("DRIVING_LICENSE", {}).get("data", {})
        lic_exp  = lic_data.get("date_expiration", "")
        if lic_exp:
            exp = _parse_date(lic_exp)
            if exp:
                checks["license_valid"] = exp >= today
                if exp < today:
                    issues.append(f"Permis de conduire expiré le {lic_exp}")
            else:
                checks["license_date_format"] = False
                issues.append("Format date permis invalide")

        # Catégorie permis
        categories = lic_data.get("categories", [])
        if categories:
            valid_cat = any(
                cat.strip().upper() in VALID_LICENSE_CATEGORIES_TOGO
                for cat in (categories if isinstance(categories, list) else [str(categories)])
            )
            checks["license_category_valid"] = valid_cat
            if not valid_cat:
                issues.append(f"Catégorie permis non valide pour le covoiturage : {categories}")

        # Assurance
        ins_data = ocr.get("INSURANCE", {}).get("data", {})
        ins_exp  = ins_data.get("date_expiration", "")
        if ins_exp:
            exp = _parse_date(ins_exp)
            if exp:
                checks["insurance_valid"] = exp >= today
                if exp < today:
                    issues.append(f"Assurance expirée le {ins_exp}")
            else:
                checks["insurance_date_format"] = False

        # Contrôle technique
        ct_data = ocr.get("TECHNICAL_INSPECTION", {}).get("data", {})
        ct_val  = ct_data.get("date_validite", "")
        if ct_val:
            exp = _parse_date(ct_val)
            if exp:
                checks["ct_valid"] = exp >= today
                if exp < today:
                    issues.append(f"Contrôle technique expiré le {ct_val}")
            else:
                checks["ct_date_format"] = False

        # ── 3. Score ──────────────────────────────────────────────────────────
        total  = max(len(checks), 1)
        passed = sum(1 for v in checks.values() if v)
        score  = round((passed / total) * 100, 1)

        all_docs_present   = len(missing_docs) == 0
        all_docs_valid     = len(invalid_docs) == 0
        missing_docs_count = len(missing_docs)
        invalid_docs_count = len(invalid_docs)

        return {
            "checks":             checks,
            "issues":             issues,
            "compliance_score":   score,
            "all_docs_present":   all_docs_present,
            "all_docs_valid":     all_docs_valid,
            "missing_docs":       missing_docs,
            "invalid_docs":       invalid_docs,
            "missing_docs_count": missing_docs_count,
            "invalid_docs_count": invalid_docs_count,
            "compliance_valid":   score >= 80 and all_docs_present and all_docs_valid,
        }
