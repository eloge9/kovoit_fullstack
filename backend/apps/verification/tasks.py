"""Celery tasks — vérification conducteurs et contrôle des expirations."""
import logging
from datetime import timedelta

from django.utils import timezone

logger = logging.getLogger(__name__)

try:
    from celery import shared_task
    CELERY_AVAILABLE = True
except ImportError:
    CELERY_AVAILABLE = False
    def shared_task(f=None, **kwargs):
        if f:
            return f
        def decorator(func):
            return func
        return decorator


@shared_task(bind=True, max_retries=3, default_retry_delay=60)
def run_driver_verification(self, driver_profile_id: str):
    """Lance l'orchestrateur IA de vérification pour un conducteur."""
    try:
        from .agents.orchestrator import run_verification
        return run_verification(driver_profile_id)
    except Exception as exc:
        logger.exception("Verification task failed for profile %s: %s", driver_profile_id, exc)
        raise self.retry(exc=exc)


@shared_task
def check_document_expirations():
    """
    Vérifie quotidiennement les expirations de documents.
    Envoie des notifications à J-30, J-15, J-7, J-1.
    Suspend automatiquement les conducteurs à J-0.
    """
    from .models import DriverDocument, DriverProfile, DriverStatus, VerificationHistory
    from apps.modeles.models import Notification

    today    = timezone.now().date()
    warnings = [30, 15, 7, 1]

    # Vérifier les expirationsproches
    for days in warnings:
        target_date = today + timedelta(days=days)
        expiring_docs = DriverDocument.objects.filter(
            date_expiration=target_date,
            driver_profile__status=DriverStatus.ACTIVE,
        ).select_related("driver_profile__user")

        for doc in expiring_docs:
            user = doc.driver_profile.user
            type_label = doc.get_document_type_display()
            try:
                Notification.objects.create(
                    utilisateur=user,
                    contenu=(
                        f"⚠️ Votre {type_label} expire dans {days} jour(s) "
                        f"(le {doc.date_expiration.strftime('%d/%m/%Y')}). "
                        "Veuillez le renouveler pour conserver votre statut actif."
                    ),
                )
                logger.info(
                    "Expiration warning sent to %s for %s (in %d days)",
                    user.username, doc.document_type, days
                )
            except Exception as e:
                logger.error("Failed to send expiration notification: %s", e)

    # Suspendre les conducteurs avec documents expirés
    expired_docs = DriverDocument.objects.filter(
        date_expiration__lt=today,
        driver_profile__status=DriverStatus.ACTIVE,
    ).select_related("driver_profile__user")

    suspended_profiles = set()
    for doc in expired_docs:
        profile = doc.driver_profile
        if profile.id in suspended_profiles:
            continue

        doc.status = "EXPIRED"
        doc.save(update_fields=["status"])

        old_status = profile.status
        profile.status           = DriverStatus.SUSPENDED
        profile.motif_suspension = f"Document expiré: {doc.get_document_type_display()} (exp. {doc.date_expiration})"
        profile.suspended_at     = timezone.now()
        profile.save(update_fields=["status", "motif_suspension", "suspended_at"])

        VerificationHistory.objects.create(
            driver_profile=profile,
            old_status=old_status,
            new_status=DriverStatus.SUSPENDED,
            reason=profile.motif_suspension,
            is_automatic=True,
        )

        try:
            Notification.objects.create(
                utilisateur=profile.user,
                contenu=(
                    f"🚫 Votre compte conducteur a été suspendu car votre "
                    f"{doc.get_document_type_display()} a expiré. "
                    "Renouvelez vos documents et contactez le support."
                ),
            )
        except Exception as e:
            logger.error("Failed to send suspension notification: %s", e)

        suspended_profiles.add(profile.id)
        logger.info("Auto-suspended driver %s due to expired %s", profile.user.username, doc.document_type)

    logger.info(
        "check_document_expirations: %d profile(s) suspended",
        len(suspended_profiles)
    )
    return {"suspended": len(suspended_profiles)}


@shared_task
def auto_process_signals():
    """Suspension automatique si trop de signalements non traités."""
    from .models import DriverProfile, DriverStatus, DriverSignal, VerificationHistory
    from django.db.models import Count
    from apps.modeles.models import Notification

    THRESHOLD = 5
    profiles_with_signals = (
        DriverProfile.objects.filter(status=DriverStatus.ACTIVE)
        .annotate(unprocessed_signals=Count("signals", filter=__import__("django.db.models", fromlist=["Q"]).Q(signals__is_processed=False)))
        .filter(unprocessed_signals__gte=THRESHOLD)
    )

    for profile in profiles_with_signals:
        old_status = profile.status
        profile.status           = DriverStatus.SUSPENDED
        profile.motif_suspension = f"Suspension automatique: {profile.unprocessed_signals} signalements non traités."
        profile.suspended_at     = timezone.now()
        profile.save(update_fields=["status", "motif_suspension", "suspended_at"])

        VerificationHistory.objects.create(
            driver_profile=profile,
            old_status=old_status,
            new_status=DriverStatus.SUSPENDED,
            reason=profile.motif_suspension,
            is_automatic=True,
        )

        try:
            Notification.objects.create(
                utilisateur=profile.user,
                contenu="Votre compte a été suspendu suite à plusieurs signalements.",
            )
        except Exception:
            pass

    return {"auto_suspended": profiles_with_signals.count()}
