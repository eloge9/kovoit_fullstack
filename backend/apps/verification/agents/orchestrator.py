"""
Orchestrateur du moteur IA de vérification KOVOIT.

Lance les 9 agents dans l'ordre, consolide les résultats
et met à jour le DriverProfile + VerificationReport en base.
"""
import logging
import time
from django.utils import timezone

from .ocr_agent             import OcrAgent
from .identity_agent        import IdentityAgent
from .vehicle_agent         import VehicleAgent
from .insurance_agent       import InsuranceAgent
from .technical_agent       import TechnicalInspectionAgent
from .fraud_agent           import FraudDetectionAgent
from .compliance_agent      import ComplianceAgent
from .decision_agent        import DecisionAgent
from .admin_review_agent    import AdminReviewAgent

logger = logging.getLogger(__name__)


def run_verification(driver_profile_id: str) -> dict:
    """
    Point d'entrée principal appelé par la Celery task.
    Retourne le résultat complet de la vérification.
    """
    from apps.verification.models import (
        DriverProfile, DriverDocument, VerificationReport,
        VerificationHistory, DriverStatus, DocumentStatus,
    )

    profile = DriverProfile.objects.select_related("user").prefetch_related("documents").get(
        id=driver_profile_id
    )
    user = profile.user

    # Construire le contexte commun
    documents    = profile.documents.filter(status=DocumentStatus.PENDING)
    docs_present = {d.document_type: True for d in profile.documents.all()}
    file_paths   = {}

    doc_list_for_ocr = []
    for doc in profile.documents.all():
        if doc.file:
            path = doc.file.path
            file_paths[doc.document_type] = path
            doc_list_for_ocr.append({"type": doc.document_type, "file_path": path})

    # Données profil conducteur
    try:
        vehicle_obj = user.profil_conducteur.vehicules.filter(est_actif=True).first()
    except Exception:
        vehicle_obj = None

    vehicle_profile = {}
    if vehicle_obj:
        vehicle_profile = {
            "plaque":  vehicle_obj.plaque,
            "marque":  vehicle_obj.marque,
            "modele":  vehicle_obj.modele,
            "annee":   getattr(vehicle_obj, "annee", ""),
        }

    driver_profile_data = {
        "first_name":     user.first_name,
        "last_name":      user.last_name,
        "username":       user.username,
        "date_naissance": str(profile.date_naissance) if profile.date_naissance else "",
    }

    # Créer le rapport en base
    # (le statut PENDING_AI_REVIEW est déjà positionné par la vue avant le lancement)
    report = VerificationReport.objects.create(
        driver_profile=profile,
        started_at=timezone.now(),
    )

    start_time = time.time()

    # --- Agent 1 : OCR ---
    logger.info("Running OcrAgent for profile %s", driver_profile_id)
    ocr_result = OcrAgent().run({"documents": doc_list_for_ocr})
    report.ocr_report = ocr_result
    report.save(update_fields=["ocr_report"])

    base_ctx = {
        "ocr_results":     ocr_result,
        "driver_profile":  driver_profile_data,
        "vehicle_profile": vehicle_profile,
        "documents_present": docs_present,
        "file_paths":      file_paths,
    }

    # --- Agent 2 : Identity ---
    identity_result = IdentityAgent().run(base_ctx)
    report.identity_report = identity_result
    report.save(update_fields=["identity_report"])

    # --- Agent 3 : Vehicle ---
    vehicle_result = VehicleAgent().run(base_ctx)
    report.vehicle_report = vehicle_result
    report.save(update_fields=["vehicle_report"])

    # --- Agent 4 : Insurance ---
    insurance_result = InsuranceAgent().run(base_ctx)
    report.insurance_report = insurance_result
    report.save(update_fields=["insurance_report"])

    # --- Agent 5 : Technical ---
    technical_result = TechnicalInspectionAgent().run(base_ctx)
    report.technical_report = technical_result
    report.save(update_fields=["technical_report"])

    # --- Agent 6 : Fraud ---
    fraud_result = FraudDetectionAgent().run(base_ctx)
    report.fraud_report = fraud_result
    report.save(update_fields=["fraud_report"])

    # --- Agent 7 : Compliance ---
    compliance_result = ComplianceAgent().run(base_ctx)
    report.compliance_report = compliance_result
    report.save(update_fields=["compliance_report"])

    # --- Agent 8 : Decision ---
    decision_ctx = {
        "identity_report":   identity_result,
        "vehicle_report":    vehicle_result,
        "insurance_report":  insurance_result,
        "technical_report":  technical_result,
        "fraud_report":      fraud_result,
        "compliance_report": compliance_result,
    }
    decision_result = DecisionAgent().run(decision_ctx)

    # --- Agent 9 : Admin Review Summary ---
    admin_ctx = {
        "driver_profile": driver_profile_data,
        "decision_report": decision_result,
        "all_reports": {
            "ocr_report":        ocr_result,
            "identity_report":   identity_result,
            "vehicle_report":    vehicle_result,
            "insurance_report":  insurance_result,
            "technical_report":  technical_result,
            "fraud_report":      fraud_result,
            "compliance_report": compliance_result,
        },
    }
    admin_summary = AdminReviewAgent().run(admin_ctx)

    elapsed = round(time.time() - start_time, 2)

    # Finaliser le rapport
    report.decision           = decision_result.get("decision")
    report.overall_score      = decision_result.get("overall_score", 0)
    report.fraud_score        = decision_result.get("fraud_score", 0)
    report.confidence_score   = decision_result.get("confidence", 0)
    report.summary            = admin_summary.get("summary", "")
    report.completed_at       = timezone.now()
    report.processing_time_seconds = elapsed
    report.save()

    # ── Tiers d'activation basés sur le score de fraude ─────────────────────
    # L'IA ne rejette JAMAIS un conducteur automatiquement.
    # L'admin a toujours le dernier mot, quelle que soit la décision IA.
    #
    # 0–25  + APPROVED  → ACTIVE directement (auto-activation)
    # 26–50 + APPROVED  → AI_APPROVED (admin normal)
    # 51+   ou non-APPROVED → PENDING_ADMIN_REVIEW (admin strict)
    FRAUD_TIER_AUTO   = 25
    FRAUD_TIER_NORMAL = 50

    decision    = decision_result.get("decision")
    fraud_score = decision_result.get("fraud_score", 0)

    if decision == "APPROVED" and fraud_score <= FRAUD_TIER_AUTO:
        new_status      = DriverStatus.ACTIVE
        activation_tier = "AUTO"
    elif decision == "APPROVED" and fraud_score <= FRAUD_TIER_NORMAL:
        new_status      = DriverStatus.AI_APPROVED
        activation_tier = "NORMAL"
    else:
        # Tout le reste (fraude élevée, docs invalides, incertitude IA…)
        # → toujours examiné par l'admin, jamais rejeté automatiquement
        new_status      = DriverStatus.PENDING_ADMIN_REVIEW
        activation_tier = "STRICT"

    logger.info(
        "Activation tier for %s: decision=%s fraud=%.1f → tier=%s → status=%s",
        driver_profile_id, decision, fraud_score, activation_tier, new_status,
    )

    # Marquer les documents comme traités (vérifiés ou à réviser)
    profile.documents.filter(status=DocumentStatus.PENDING).update(status=DocumentStatus.VERIFIED)

    # Stocker les problèmes détectés pour que l'admin et le conducteur les voient
    critical_rejects = decision_result.get("critical_rejects", [])
    if critical_rejects:
        profile.motif_rejet = " | ".join(critical_rejects[:3])

    if new_status == DriverStatus.ACTIVE:
        profile.verified_at = timezone.now()
        profile.status      = new_status
        profile.save(update_fields=["status", "verified_at", "motif_rejet"] if critical_rejects else ["status", "verified_at"])
    else:
        profile.status = new_status
        profile.save(update_fields=["status", "motif_rejet"] if critical_rejects else ["status"])

    rejects_summary = "; ".join(critical_rejects[:3])
    tier_labels = {
        "AUTO":   "activation automatique (fraude ≤ 25%)",
        "NORMAL": "validation admin recommandée (fraude 26–50%)",
        "STRICT": "vérification admin stricte (fraude > 50% ou dossier incomplet)",
    }
    VerificationHistory.objects.create(
        driver_profile=profile,
        old_status=DriverStatus.PENDING_AI_REVIEW,
        new_status=new_status,
        reason=(
            f"Décision IA: {decision} — "
            f"score {decision_result.get('overall_score', 0):.0f}%, "
            f"fraude {fraud_score:.0f}% — {tier_labels.get(activation_tier, '')}"
            + (f" — {rejects_summary}" if rejects_summary else "")
        ),
        is_automatic=True,
    )

    # ── Notifications au conducteur ───────────────────────────────────────────
    try:
        from apps.modeles.models import Notification

        # 1. Notification principale selon le tier
        msg_principal = {
            "AUTO":   "🎉 Félicitations ! Votre dossier a été validé automatiquement. Votre compte est maintenant actif, vous pouvez proposer des trajets.",
            "NORMAL": "✅ Votre dossier a été approuvé par notre système IA. Un administrateur va le valider prochainement.",
            "STRICT": "⏳ Votre dossier est en cours d'examen approfondi par notre équipe. Vous serez notifié dès qu'une décision est prise.",
        }.get(activation_tier, "Votre vérification est terminée.")

        Notification.objects.create(utilisateur=user, contenu=msg_principal)

        # 2. Notification séparée si des documents sont problématiques
        #    → on demande au conducteur de les corriger / re-uploader
        missing_docs = compliance_result.get("missing_docs", [])
        invalid_docs = compliance_result.get("invalid_docs", [])

        doc_issues = []
        if missing_docs:
            doc_issues.append(f"• Documents manquants : {', '.join(missing_docs)}")
        if invalid_docs:
            doc_issues.append(f"• Documents non conformes ou illisibles : {', '.join(invalid_docs)}")

        if doc_issues and new_status != DriverStatus.ACTIVE:
            msg_docs = (
                "📋 Des problèmes ont été détectés dans votre dossier :\n\n"
                + "\n".join(doc_issues)
                + "\n\nMerci de corriger et re-uploader les documents concernés "
                "afin d'accélérer le traitement de votre demande d'activation."
            )
            Notification.objects.create(utilisateur=user, contenu=msg_docs)
            logger.info(
                "Document issue notification sent to %s: missing=%s invalid=%s",
                user.username, missing_docs, invalid_docs,
            )

    except Exception as e:
        logger.warning("Notification failed: %s", e)

    logger.info(
        "Verification complete for %s: decision=%s score=%.1f fraud=%.1f time=%.2fs",
        driver_profile_id, decision,
        decision_result.get("overall_score", 0),
        decision_result.get("fraud_score", 0),
        elapsed,
    )

    return {
        "report_id":        str(report.id),
        "decision":         decision,
        "overall_score":    decision_result.get("overall_score", 0),
        "fraud_score":      fraud_score,
        "new_status":       new_status,
        "activation_tier":  activation_tier,
        "processing_time":  elapsed,
        "summary":          admin_summary.get("summary", ""),
    }
