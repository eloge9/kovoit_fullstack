"""Agent 2 : Vérification d'identité — cohérence CNI / permis / selfie / profil."""
import logging
from .base_agent import BaseAgent

logger = logging.getLogger(__name__)


class IdentityAgent(BaseAgent):
    name = "IdentityAgent"

    def process(self, context: dict) -> dict:
        """
        context = {
            "ocr_results": {...},      # sortie OcrAgent
            "driver_profile": {...},   # données du profil utilisateur
        }
        """
        ocr     = context.get("ocr_results", {}).get("results", {})
        profile = context.get("driver_profile", {})

        checks = {}
        issues = []

        cni_data     = ocr.get("CNI",             {}).get("data", {})
        license_data = ocr.get("DRIVING_LICENSE",  {}).get("data", {})

        # --- Cohérence nom/prénom entre CNI et profil ---
        profile_nom    = (profile.get("last_name") or "").strip().upper()
        profile_prenom = (profile.get("first_name") or "").strip().upper()

        cni_nom    = (cni_data.get("nom") or "").strip().upper()
        cni_prenom = (cni_data.get("prenom") or "").strip().upper()

        if cni_nom and profile_nom:
            match = cni_nom == profile_nom
            checks["nom_cni_profil"] = match
            if not match:
                issues.append(f"Nom CNI '{cni_nom}' ≠ profil '{profile_nom}'")

        if cni_prenom and profile_prenom:
            match = cni_prenom == profile_prenom
            checks["prenom_cni_profil"] = match
            if not match:
                issues.append(f"Prénom CNI '{cni_prenom}' ≠ profil '{profile_prenom}'")

        # --- Cohérence CNI ↔ Permis ---
        lic_nom    = (license_data.get("nom") or "").strip().upper()
        lic_prenom = (license_data.get("prenom") or "").strip().upper()

        if cni_nom and lic_nom:
            match = cni_nom == lic_nom
            checks["nom_cni_permis"] = match
            if not match:
                issues.append(f"Nom CNI '{cni_nom}' ≠ permis '{lic_nom}'")

        if cni_prenom and lic_prenom:
            match = cni_prenom == lic_prenom
            checks["prenom_cni_permis"] = match
            if not match:
                issues.append(f"Prénom CNI '{cni_prenom}' ≠ permis '{lic_prenom}'")

        # --- Date de naissance ---
        cni_dob = cni_data.get("date_naissance", "")
        pro_dob = profile.get("date_naissance", "")
        if cni_dob and pro_dob:
            match = str(cni_dob) == str(pro_dob)
            checks["date_naissance"] = match
            if not match:
                issues.append(f"Date naissance CNI '{cni_dob}' ≠ profil '{pro_dob}'")

        # --- Selfie présent ---
        selfie_present = bool(context.get("documents_present", {}).get("SELFIE_ID"))
        checks["selfie_present"] = selfie_present
        if not selfie_present:
            issues.append("Selfie avec pièce d'identité manquant")

        # --- Score ---
        total = max(len(checks), 1)
        passed = sum(1 for v in checks.values() if v)
        score  = round((passed / total) * 100, 1)

        return {
            "checks": checks,
            "issues": issues,
            "identity_score": score,
            "identity_valid": score >= 70 and not any(
                k in ["nom_cni_profil", "prenom_cni_profil"] and not v
                for k, v in checks.items()
            ),
        }
