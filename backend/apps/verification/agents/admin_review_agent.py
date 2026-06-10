"""Agent 9 : Préparation du résumé lisible pour l'admin."""
import logging
from .base_agent import BaseAgent

logger = logging.getLogger(__name__)

STATUS_ICON = {True: "✅", False: "❌", None: "⚠️"}


class AdminReviewAgent(BaseAgent):
    name = "AdminReviewAgent"

    def process(self, context: dict) -> dict:
        driver   = context.get("driver_profile", {})
        decision = context.get("decision_report", {})
        reports  = context.get("all_reports", {})

        driver_name = f"{driver.get('first_name', '')} {driver.get('last_name', '')}".strip()
        driver_name = driver_name or driver.get("username", "Conducteur inconnu")

        identity  = reports.get("identity_report",   {})
        vehicle   = reports.get("vehicle_report",    {})
        insurance = reports.get("insurance_report",  {})
        technical = reports.get("technical_report",  {})
        fraud     = reports.get("fraud_report",      {})

        def icon(val):
            return STATUS_ICON.get(val, "⚠️")

        lines = [
            f"=== RAPPORT DE VÉRIFICATION — {driver_name.upper()} ===",
            "",
            f"📋 OCR                : {icon(bool(reports.get('ocr_report', {}).get('documents_succeeded', 0)))}",
            f"🪪 Identité           : {icon(identity.get('identity_valid'))} (score: {identity.get('identity_score', 'N/A')}%)",
            f"🚗 Véhicule           : {icon(vehicle.get('vehicle_valid'))} (score: {vehicle.get('vehicle_score', 'N/A')}%)",
            f"📋 Assurance          : {icon(insurance.get('insurance_valid'))} (exp: {insurance.get('insurance_expiration', 'N/A')})",
            f"🔧 Contrôle technique : {icon(technical.get('technical_valid'))} (exp: {technical.get('ct_expiration', 'N/A')})",
            "",
            f"🚨 Score fraude       : {fraud.get('fraud_score', 'N/A')}% ({fraud.get('fraud_level', 'N/A')})",
            f"📊 Score global       : {decision.get('overall_score', 'N/A')}%",
            "",
            f"🤖 Décision IA        : {decision.get('decision', 'N/A')} (confiance: {decision.get('confidence', 'N/A')}%)",
        ]

        hard_rejects = decision.get("hard_rejects", [])
        if hard_rejects:
            lines.append("")
            lines.append("❗ BLOCAGES DÉTECTÉS:")
            for r in hard_rejects:
                lines.append(f"   • {r}")

        all_issues = decision.get("all_issues", [])
        if all_issues:
            lines.append("")
            lines.append("⚠️ PROBLÈMES IDENTIFIÉS:")
            for issue in all_issues[:10]:
                lines.append(f"   • {issue}")
            if len(all_issues) > 10:
                lines.append(f"   ... et {len(all_issues) - 10} autres")

        summary = "\n".join(lines)

        # Recommandation admin
        d = decision.get("decision")
        if d == "APPROVED":
            recommendation = "Dossier conforme. Activation recommandée."
        elif d == "REJECTED":
            recommendation = "Dossier non conforme. Rejet recommandé. Voir les blocages ci-dessus."
        else:
            recommendation = "Dossier incomplet ou suspects. Révision manuelle nécessaire."

        return {
            "summary":        summary,
            "recommendation": recommendation,
            "driver_name":    driver_name,
            "decision":       d,
            "overall_score":  decision.get("overall_score", 0),
            "fraud_score":    fraud.get("fraud_score", 0),
        }
