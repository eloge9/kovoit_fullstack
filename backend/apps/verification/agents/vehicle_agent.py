"""Agent 3 : Vérification véhicule — cohérence carte grise / photos / profil."""
import logging
from .base_agent import BaseAgent

logger = logging.getLogger(__name__)


class VehicleAgent(BaseAgent):
    name = "VehicleAgent"

    VEHICLE_PHOTO_TYPES = [
        "VEHICLE_FRONT", "VEHICLE_REAR",
        "VEHICLE_LEFT", "VEHICLE_RIGHT",
        "VEHICLE_INTERIOR_FRONT", "VEHICLE_INTERIOR_REAR",
    ]

    def process(self, context: dict) -> dict:
        ocr              = context.get("ocr_results", {}).get("results", {})
        vehicle_profile  = context.get("vehicle_profile", {})
        docs_present     = context.get("documents_present", {})

        checks = {}
        issues = []

        registration_data = ocr.get("VEHICLE_REGISTRATION", {}).get("data", {})

        # --- Plaque ---
        reg_plaque  = (registration_data.get("plaque") or "").strip().upper().replace(" ", "")
        prof_plaque = (vehicle_profile.get("plaque") or "").strip().upper().replace(" ", "")

        if reg_plaque and prof_plaque:
            match = reg_plaque == prof_plaque
            checks["plaque_match"] = match
            if not match:
                issues.append(f"Plaque carte grise '{reg_plaque}' ≠ profil '{prof_plaque}'")
        else:
            checks["plaque_present"] = bool(reg_plaque or prof_plaque)

        # --- Marque ---
        reg_marque  = (registration_data.get("marque") or "").strip().upper()
        prof_marque = (vehicle_profile.get("marque") or "").strip().upper()
        if reg_marque and prof_marque:
            match = reg_marque in prof_marque or prof_marque in reg_marque
            checks["marque_match"] = match
            if not match:
                issues.append(f"Marque carte grise '{reg_marque}' ≠ profil '{prof_marque}'")

        # --- Modèle ---
        reg_modele  = (registration_data.get("modele") or "").strip().upper()
        prof_modele = (vehicle_profile.get("modele") or "").strip().upper()
        if reg_modele and prof_modele:
            match = reg_modele in prof_modele or prof_modele in reg_modele
            checks["modele_match"] = match
            if not match:
                issues.append(f"Modèle carte grise '{reg_modele}' ≠ profil '{prof_modele}'")

        # --- Photos véhicule présentes ---
        for photo_type in self.VEHICLE_PHOTO_TYPES:
            present = bool(docs_present.get(photo_type))
            checks[f"photo_{photo_type.lower()}_present"] = present
            if not present:
                issues.append(f"Photo manquante : {photo_type}")

        # --- Score ---
        total  = max(len(checks), 1)
        passed = sum(1 for v in checks.values() if v)
        score  = round((passed / total) * 100, 1)

        # Valide seulement si toutes les photos sont présentes et plaque correspond
        photos_ok = all(
            checks.get(f"photo_{pt.lower()}_present", False)
            for pt in self.VEHICLE_PHOTO_TYPES
        )
        plaque_ok = checks.get("plaque_match", True)

        return {
            "checks": checks,
            "issues": issues,
            "vehicle_score": score,
            "vehicle_valid": photos_ok and plaque_ok,
            "registration_data": registration_data,
        }
