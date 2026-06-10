"""Agent 8 : Décision finale — agrège tous les rapports et produit APPROVED / REJECTED / MANUAL_REVIEW."""
import logging
from .base_agent import BaseAgent

logger = logging.getLogger(__name__)

# Seuils
# L'IA ne rejette JAMAIS sur la base du score de fraude seul.
# L'orchestrateur applique les tiers (0–25 auto / 26–50 normal / 51+ strict).
FRAUD_SCORE_MANUAL    = 26   # Score fraude >= 26 → flag révision manuelle
OVERALL_SCORE_APPROVE = 80   # Score global >= 80 requis pour approbation


class DecisionAgent(BaseAgent):
    name = "DecisionAgent"

    def process(self, context: dict) -> dict:
        identity   = context.get("identity_report",   {})
        vehicle    = context.get("vehicle_report",    {})
        insurance  = context.get("insurance_report",  {})
        technical  = context.get("technical_report",  {})
        fraud      = context.get("fraud_report",      {})
        compliance = context.get("compliance_report", {})

        # ── Scores ────────────────────────────────────────────────────────────
        scores = {
            "identity":   identity.get("identity_score",    0),
            "vehicle":    vehicle.get("vehicle_score",       0),
            "insurance":  insurance.get("insurance_score",   0),
            "technical":  technical.get("technical_score",   0),
            "compliance": compliance.get("compliance_score", 0),
        }
        fraud_score = fraud.get("fraud_score", 0)

        weights = {
            "identity":   0.25,
            "vehicle":    0.20,
            "insurance":  0.20,
            "technical":  0.15,
            "compliance": 0.20,
        }
        overall_score = round(sum(scores[k] * weights[k] for k in weights), 1)

        # ── Facteurs bloquants CRITIQUES (1 seul suffit pour REJECTED) ────────
        critical_rejects = []

        # Documents manquants
        missing_count = compliance.get("missing_docs_count", 0)
        if missing_count > 0:
            missing_list = compliance.get("missing_docs", [])
            critical_rejects.append(
                f"{missing_count} document(s) obligatoire(s) manquant(s) : "
                + ", ".join(missing_list[:5])
            )

        # Documents invalides / mauvais type
        invalid_count = compliance.get("invalid_docs_count", 0)
        if invalid_count > 0:
            invalid_list = compliance.get("invalid_docs", [])
            critical_rejects.append(
                f"{invalid_count} document(s) non conforme(s) : "
                + ", ".join(invalid_list[:5])
            )

        # Assurance absente ou expirée
        if not insurance.get("insurance_valid"):
            critical_rejects.append("Assurance invalide ou expirée")

        # Contrôle technique absent ou expiré
        if not technical.get("technical_valid"):
            critical_rejects.append("Contrôle technique invalide ou expiré")

        # ── Facteurs de révision manuelle (ne bloquent pas seuls) ─────────────
        manual_flags = []

        # Fraude suspectée → flag révision manuelle (jamais rejet automatique)
        if fraud.get("fraud_detected") or fraud_score >= FRAUD_SCORE_MANUAL:
            manual_flags.append(f"Suspicion de fraude (score: {fraud_score}%) — examen admin requis")

        if overall_score < OVERALL_SCORE_APPROVE and not critical_rejects:
            manual_flags.append(f"Score global insuffisant ({overall_score}%)")

        # Vérifications identité échouées
        id_issues = identity.get("issues", [])
        if id_issues:
            manual_flags.extend(id_issues[:3])

        # ── Décision ──────────────────────────────────────────────────────────
        if critical_rejects:
            # Documents manquants / invalides / assurance / CT → REJET IA informatif
            # (l'orchestrateur redirige quand même vers l'admin)
            decision   = "REJECTED"
            confidence = 90
        elif manual_flags or overall_score < OVERALL_SCORE_APPROVE:
            # Doutes → révision manuelle
            decision   = "MANUAL_REVIEW"
            confidence = 70
        else:
            # Tous les critères OK
            decision   = "APPROVED"
            confidence = min(100, round(overall_score + (100 - fraud_score) * 0.1, 1))

        # ── Résumé de tous les problèmes ──────────────────────────────────────
        all_issues = []
        for report_name, report in [
            ("Identité",   identity),
            ("Véhicule",   vehicle),
            ("Assurance",  insurance),
            ("CT",         technical),
            ("Conformité", compliance),
        ]:
            for issue in report.get("issues", []):
                all_issues.append(f"[{report_name}] {issue}")

        return {
            "decision":         decision,
            "overall_score":    overall_score,
            "fraud_score":      fraud_score,
            "confidence":       confidence,
            "scores_detail":    scores,
            "critical_rejects": critical_rejects,
            "manual_flags":     manual_flags,
            "all_issues":       all_issues,
        }
