"""Views DRF — système de vérification conducteurs KOVOIT."""
import logging

from django.db import transaction
from django.utils import timezone
from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from .models import (
    DriverProfile, DriverDocument, VerificationReport,
    AdminReview, VerificationHistory, DriverSignal,
    DriverStatus, DocumentStatus, REQUIRED_DOCUMENTS,
)
from .permissions import IsAdmin, IsAdminOrDriverOwner
from apps.modeles.notifs import envoyer_notification
from .serializers import (
    DriverProfileSerializer, DriverProfileUpdateSerializer,
    DriverProfileAdminListSerializer, DocumentUploadSerializer,
    DriverDocumentSerializer, VerificationReportSerializer,
    AdminReviewSerializer, AdminActionSerializer,
    VerificationHistorySerializer, DriverSignalSerializer,
    VerificationStatusSerializer,
)

logger = logging.getLogger(__name__)

# Seuil de signalements avant suspension automatique
AUTO_SUSPEND_SIGNAL_THRESHOLD = 5


# ─────────────────────────────────────────────────────────────────────────────
# CONDUCTEUR — vue propre
# ─────────────────────────────────────────────────────────────────────────────

class DriverVerificationViewSet(viewsets.GenericViewSet):
    """
    API pour le conducteur : gestion de son propre dossier de vérification.

    GET    /driver/verification/status/          → statut et progression
    GET    /driver/verification/profile/         → profil complet
    PATCH  /driver/verification/profile/update/  → mise à jour profil
    GET    /driver/verification/report/          → dernier rapport IA
    POST   /driver/verification/start/           → démarrer la vérification IA
    POST   /driver/documents/upload/             → uploader un document
    DELETE /driver/documents/{id}/delete/        → supprimer un document
    """
    permission_classes = [IsAuthenticated]
    parser_classes     = [MultiPartParser, FormParser, JSONParser]

    def _get_or_create_profile(self, user):
        profile, created = DriverProfile.objects.get_or_create(user=user)
        if created:
            VerificationHistory.objects.create(
                driver_profile=profile,
                old_status="",
                new_status=DriverStatus.DOCUMENTS_MISSING,
                reason="Création du profil conducteur",
                is_automatic=True,
            )
        return profile

    # ── GET /driver/verification/status/ ────────────────────────────────────
    @action(detail=False, methods=["get"], url_path="status")
    def verification_status(self, request):
        profile = self._get_or_create_profile(request.user)

        uploaded = list(
            profile.documents.values_list("document_type", flat=True)
        )
        missing = [d for d in REQUIRED_DOCUMENTS if d not in uploaded]

        latest_report = profile.verification_reports.first()

        data = {
            "status":                profile.status,
            "is_verified":           profile.is_verified,
            "completion_percentage": profile.completion_percentage,
            "can_publish_trip":      profile.can_publish_trip,
            "required_documents":    REQUIRED_DOCUMENTS,
            "uploaded_documents":    uploaded,
            "missing_documents":     missing,
            "latest_report":         VerificationReport.objects.filter(
                driver_profile=profile
            ).values(
                "id", "decision", "overall_score", "fraud_score",
                "confidence_score", "completed_at", "created_at"
            ).first(),
            "motif_rejet":      profile.motif_rejet,
            "motif_suspension": profile.motif_suspension,
        }
        return Response(data)

    # ── GET /driver/verification/profile/ ───────────────────────────────────
    @action(detail=False, methods=["get"], url_path="profile")
    def get_profile(self, request):
        profile = self._get_or_create_profile(request.user)
        serializer = DriverProfileSerializer(profile, context={"request": request})
        return Response(serializer.data)

    # ── PATCH /driver/verification/profile/update/ ──────────────────────────
    @action(detail=False, methods=["patch", "put"], url_path="profile/update")
    def update_profile(self, request):
        profile = self._get_or_create_profile(request.user)
        serializer = DriverProfileUpdateSerializer(
            profile, data=request.data, partial=request.method == "PATCH"
        )
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    # ── GET /driver/verification/report/ ────────────────────────────────────
    @action(detail=False, methods=["get"], url_path="report")
    def get_report(self, request):
        profile = self._get_or_create_profile(request.user)
        report  = profile.verification_reports.first()
        if not report:
            return Response({"message": "Aucun rapport disponible."}, status=status.HTTP_404_NOT_FOUND)
        return Response(VerificationReportSerializer(report).data)

    # ── POST /driver/verification/start/ ────────────────────────────────────
    @action(detail=False, methods=["post"], url_path="start")
    def start_verification(self, request):
        profile = self._get_or_create_profile(request.user)

        if profile.status in [DriverStatus.PENDING_AI_REVIEW, DriverStatus.PENDING_ADMIN_REVIEW]:
            return Response(
                {"message": "Une vérification est déjà en cours."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if profile.status == DriverStatus.ACTIVE:
            return Response({"message": "Votre compte est déjà actif."}, status=status.HTTP_400_BAD_REQUEST)

        # Vérifier que tous les docs obligatoires sont uploadés
        uploaded = set(profile.documents.values_list("document_type", flat=True))
        missing  = [d for d in REQUIRED_DOCUMENTS if d not in uploaded]
        if missing:
            return Response({
                "message": f"Documents manquants avant lancement: {', '.join(missing)}",
                "missing_documents": missing,
            }, status=status.HTTP_400_BAD_REQUEST)

        # Marquer immédiatement PENDING_AI_REVIEW pour que le frontend voit le changement
        profile.status = DriverStatus.PENDING_AI_REVIEW
        profile.save(update_fields=["status"])

        # Notification immédiate (DB + push WS temps réel) — le conducteur n'a
        # rien d'autre à faire, l'analyse démarre automatiquement.
        try:
            from apps.modeles.models import Notification
            Notification.objects.create(
                utilisateur=request.user,
                contenu="🔎 Analyse de vos documents en cours… Vous serez notifié du résultat.",
            )
        except Exception as e:
            logger.warning("Notification (start) failed: %s", e)
        envoyer_notification(request.user, "verification_started", {
            "status": DriverStatus.PENDING_AI_REVIEW,
        })

        # 1. Essai Celery (production)
        celery_launched = False
        try:
            from .tasks import run_driver_verification
            run_driver_verification.delay(str(profile.id))
            celery_launched = True
            logger.info("Verification task queued via Celery for profile %s", profile.id)
        except Exception as e:
            logger.warning("Celery unavailable (%s) — falling back to background thread", e)

        # 2. Fallback thread (dev sans Celery)
        if not celery_launched:
            import threading

            def _run_in_thread(profile_id: str):
                try:
                    from django.db import close_old_connections
                    close_old_connections()
                    from .agents.orchestrator import run_verification
                    run_verification(profile_id)
                except Exception as ex:
                    logger.error("Background thread verification failed for %s: %s", profile_id, ex)
                    # Remettre le statut en erreur pour que l'UI ne reste pas bloquée
                    try:
                        from .models import DriverProfile, DriverStatus
                        DriverProfile.objects.filter(id=profile_id).update(
                            status=DriverStatus.DOCUMENTS_MISSING
                        )
                    except Exception:
                        pass

            t = threading.Thread(
                target=_run_in_thread,
                args=(str(profile.id),),
                daemon=True,
                name=f"verification-{profile.id}",
            )
            t.start()
            logger.info("Verification started in background thread for profile %s", profile.id)

        return Response(
            {
                "message": "Vérification IA lancée. Vous serez notifié du résultat.",
                "status":  DriverStatus.PENDING_AI_REVIEW,
            },
            status=status.HTTP_202_ACCEPTED,
        )

    # ── POST /driver/documents/upload/ ──────────────────────────────────────
    @action(detail=False, methods=["post"], url_path="documents/upload")
    def upload_document(self, request):
        profile = self._get_or_create_profile(request.user)

        if profile.status in [DriverStatus.BLOCKED, DriverStatus.SUSPENDED]:
            return Response(
                {"error": "Votre compte est suspendu ou bloqué."},
                status=status.HTTP_403_FORBIDDEN,
            )

        serializer = DocumentUploadSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        doc_type = serializer.validated_data["document_type"]
        file     = serializer.validated_data["file"]

        with transaction.atomic():
            doc, created = DriverDocument.objects.update_or_create(
                driver_profile=profile,
                document_type=doc_type,
                defaults={
                    "file":      file,
                    "file_name": file.name,
                    "file_size": file.size,
                    "file_type": getattr(file, "content_type", "application/octet-stream"),
                    "status":    DocumentStatus.PENDING,
                    "rejection_reason": "",
                    "ocr_data":  {},
                },
            )

            # Recalculer le statut global
            if profile.status in [DriverStatus.AI_REJECTED, DriverStatus.REJECTED]:
                profile.status = DriverStatus.DOCUMENTS_MISSING
                profile.save(update_fields=["status"])

        return Response(
            DriverDocumentSerializer(doc, context={"request": request}).data,
            status=status.HTTP_201_CREATED if created else status.HTTP_200_OK,
        )

    # ── DELETE /driver/documents/{id}/delete/ ───────────────────────────────
    @action(detail=True, methods=["delete"], url_path="delete")
    def delete_document(self, request, pk=None):
        profile = self._get_or_create_profile(request.user)
        try:
            doc = profile.documents.get(id=pk)
        except DriverDocument.DoesNotExist:
            return Response({"error": "Document introuvable."}, status=status.HTTP_404_NOT_FOUND)

        if profile.status in [DriverStatus.ACTIVE, DriverStatus.PENDING_AI_REVIEW, DriverStatus.PENDING_ADMIN_REVIEW]:
            return Response(
                {"error": "Suppression non autorisée pendant la vérification ou quand le compte est actif."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        doc.file.delete(save=False)
        doc.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


# ─────────────────────────────────────────────────────────────────────────────
# ADMIN — gestion des conducteurs
# ─────────────────────────────────────────────────────────────────────────────

class AdminDriverViewSet(viewsets.GenericViewSet):
    """
    GET    /admin/drivers/                   → liste tous les conducteurs
    GET    /admin/drivers/{id}/              → fiche détaillée
    POST   /admin/drivers/{id}/approve/      → approuver
    POST   /admin/drivers/{id}/reject/       → rejeter
    POST   /admin/drivers/{id}/suspend/      → suspendre
    POST   /admin/drivers/{id}/block/        → bloquer
    POST   /admin/drivers/{id}/reactivate/   → réactiver
    GET    /admin/drivers/{id}/history/      → historique
    GET    /admin/drivers/{id}/reports/      → rapports IA
    GET    /admin/drivers/{id}/signals/      → signalements
    POST   /admin/drivers/{id}/signals/{sid}/process/  → traiter signal
    """
    permission_classes = [IsAdmin]
    queryset = DriverProfile.objects.select_related("user").prefetch_related(
        "documents", "verification_reports", "signals", "admin_reviews"
    ).all()

    def _get_profile(self, pk):
        """Récupère un DriverProfile par son id ou par l'id de l'utilisateur."""
        from apps.modeles.models import Utilisateur
        try:
            return self.queryset.get(id=pk)
        except DriverProfile.DoesNotExist:
            pass
        try:
            user = Utilisateur.objects.get(id=pk, role="conducteur")
            profile, _ = DriverProfile.objects.get_or_create(
                user=user,
                defaults={"status": DriverStatus.DOCUMENTS_MISSING},
            )
            return self.queryset.get(id=profile.id)
        except Utilisateur.DoesNotExist:
            return None

    def _change_status(self, profile, new_status, admin, motif="", notes="", action_name=""):
        old_status = profile.status

        if new_status == DriverStatus.ACTIVE:
            profile.is_verified  = True
            profile.verified_at  = timezone.now()
            profile.motif_rejet  = ""
            profile.motif_suspension = ""
            # Synchroniser avec l'ancien modèle
            profile.user.statut_validation = "valide"
            profile.user.peut_conduire     = True
            profile.user.save(update_fields=["statut_validation", "peut_conduire"])
        elif new_status == DriverStatus.REJECTED:
            profile.motif_rejet = motif
            profile.user.statut_validation = "rejete"
            profile.user.save(update_fields=["statut_validation"])
        elif new_status == DriverStatus.SUSPENDED:
            profile.motif_suspension = motif
            profile.suspended_at     = timezone.now()
        elif new_status == DriverStatus.BLOCKED:
            profile.motif_suspension = motif
            profile.user.statut_validation = "rejete"
            profile.user.save(update_fields=["statut_validation"])

        profile.status = new_status
        profile.save()

        AdminReview.objects.create(
            driver_profile=profile,
            admin=admin,
            action=action_name,
            motif=motif,
            notes=notes,
        )

        VerificationHistory.objects.create(
            driver_profile=profile,
            changed_by=admin,
            old_status=old_status,
            new_status=new_status,
            reason=motif or action_name,
        )

        # Notification
        try:
            from apps.modeles.models import Notification
            msgs = {
                DriverStatus.ACTIVE:    "Votre compte conducteur a été activé. Vous pouvez maintenant publier des trajets.",
                DriverStatus.REJECTED:  f"Votre compte conducteur a été rejeté. Motif: {motif}",
                DriverStatus.SUSPENDED: f"Votre compte conducteur a été suspendu. Motif: {motif}",
                DriverStatus.BLOCKED:   "Votre compte conducteur a été bloqué. Contactez le support.",
            }
            msg = msgs.get(new_status)
            if msg:
                Notification.objects.create(utilisateur=profile.user, contenu=msg)
        except Exception as e:
            logger.warning("Notification failed: %s", e)

    # ── GET /admin/drivers/ ──────────────────────────────────────────────────
    def list(self, request):
        from apps.modeles.models import Utilisateur

        # S'assurer que TOUS les utilisateurs conducteurs ont un DriverProfile.
        # Ceux qui viennent de s'inscrire sans passer par le flow de vérification
        # apparaîtront avec le statut DOCUMENTS_MISSING.
        conducteur_users = Utilisateur.objects.filter(role="conducteur")
        existing_ids = set(DriverProfile.objects.values_list("user_id", flat=True))
        new_profiles = [
            DriverProfile(user=u, status=DriverStatus.DOCUMENTS_MISSING)
            for u in conducteur_users
            if u.id not in existing_ids
        ]
        if new_profiles:
            DriverProfile.objects.bulk_create(new_profiles, ignore_conflicts=True)

        status_filter = request.query_params.get("status")
        qs = self.queryset

        if status_filter:
            qs = qs.filter(status=status_filter)

        search = request.query_params.get("search")
        if search:
            qs = qs.filter(
                user__username__icontains=search
            ) | qs.filter(
                user__first_name__icontains=search
            ) | qs.filter(
                user__last_name__icontains=search
            ) | qs.filter(
                user__email__icontains=search
            )

        qs = qs.filter(user__role="conducteur").order_by("-created_at")

        # Pagination manuelle simple
        page  = max(int(request.query_params.get("page", 1)), 1)
        limit = min(int(request.query_params.get("limit", 20)), 100)
        offset = (page - 1) * limit

        total = qs.count()
        profiles = qs[offset:offset + limit]

        return Response({
            "count":   total,
            "page":    page,
            "pages":   (total + limit - 1) // limit,
            "results": DriverProfileAdminListSerializer(profiles, many=True, context={"request": request}).data,
        })

    # ── GET /admin/drivers/{id}/ ─────────────────────────────────────────────
    def retrieve(self, request, pk=None):
        profile = self._get_profile(pk)
        if profile is None:
            return Response({"error": "Conducteur introuvable."}, status=status.HTTP_404_NOT_FOUND)
        return Response(DriverProfileSerializer(profile, context={"request": request}).data)

    # ── POST /admin/drivers/{id}/approve/ ───────────────────────────────────
    @action(detail=True, methods=["post"])
    def approve(self, request, pk=None):
        profile = self._get_profile(pk)
        if profile is None:
            return Response({"error": "Conducteur introuvable."}, status=404)
        if profile.status == DriverStatus.ACTIVE:
            return Response({"message": "Ce conducteur est déjà actif."}, status=400)
        if profile.status == DriverStatus.PENDING_AI_REVIEW:
            logger.info("Admin %s overrides AI verification for profile %s", request.user, pk)
        s = AdminActionSerializer(data={"action": "APPROVE", **request.data})
        if not s.is_valid():
            return Response(s.errors, status=400)
        self._change_status(
            profile, DriverStatus.ACTIVE, request.user,
            motif=s.validated_data.get("motif", ""),
            notes=s.validated_data.get("notes", ""),
            action_name="APPROVE",
        )
        return Response({"message": f"Conducteur {profile.user.username} activé avec succès."})

    # ── POST /admin/drivers/{id}/reject/ ────────────────────────────────────
    @action(detail=True, methods=["post"])
    def reject(self, request, pk=None):
        profile = self._get_profile(pk)
        if profile is None:
            return Response({"error": "Conducteur introuvable."}, status=404)
        s = AdminActionSerializer(data={"action": "REJECT", **request.data})
        if not s.is_valid():
            return Response(s.errors, status=400)
        self._change_status(
            profile, DriverStatus.REJECTED, request.user,
            motif=s.validated_data["motif"],
            notes=s.validated_data.get("notes", ""),
            action_name="REJECT",
        )
        return Response({"message": f"Conducteur {profile.user.username} rejeté."})

    # ── POST /admin/drivers/{id}/suspend/ ───────────────────────────────────
    @action(detail=True, methods=["post"])
    def suspend(self, request, pk=None):
        profile = self._get_profile(pk)
        if profile is None:
            return Response({"error": "Conducteur introuvable."}, status=404)
        s = AdminActionSerializer(data={"action": "SUSPEND", **request.data})
        if not s.is_valid():
            return Response(s.errors, status=400)
        self._change_status(
            profile, DriverStatus.SUSPENDED, request.user,
            motif=s.validated_data["motif"],
            notes=s.validated_data.get("notes", ""),
            action_name="SUSPEND",
        )
        return Response({"message": f"Conducteur {profile.user.username} suspendu."})

    # ── POST /admin/drivers/{id}/block/ ─────────────────────────────────────
    @action(detail=True, methods=["post"])
    def block(self, request, pk=None):
        profile = self._get_profile(pk)
        if profile is None:
            return Response({"error": "Conducteur introuvable."}, status=404)
        s = AdminActionSerializer(data={"action": "BLOCK", **request.data})
        if not s.is_valid():
            return Response(s.errors, status=400)
        self._change_status(
            profile, DriverStatus.BLOCKED, request.user,
            motif=s.validated_data["motif"],
            notes=s.validated_data.get("notes", ""),
            action_name="BLOCK",
        )
        return Response({"message": f"Conducteur {profile.user.username} bloqué."})

    # ── POST /admin/drivers/{id}/reactivate/ ────────────────────────────────
    @action(detail=True, methods=["post"])
    def reactivate(self, request, pk=None):
        profile = self._get_profile(pk)
        if profile is None:
            return Response({"error": "Conducteur introuvable."}, status=404)
        if profile.status == DriverStatus.ACTIVE:
            return Response({"message": "Ce conducteur est déjà actif."}, status=400)
        self._change_status(
            profile, DriverStatus.ACTIVE, request.user,
            motif=request.data.get("motif", "Réactivation admin"),
            notes=request.data.get("notes", ""),
            action_name="REACTIVATE",
        )
        return Response({"message": f"Conducteur {profile.user.username} réactivé."})

    # ── GET /admin/drivers/{id}/history/ ────────────────────────────────────
    @action(detail=True, methods=["get"])
    def history(self, request, pk=None):
        profile = self._get_profile(pk)
        if profile is None:
            return Response({"error": "Conducteur introuvable."}, status=404)
        history = profile.history.select_related("changed_by").all()
        return Response(VerificationHistorySerializer(history, many=True).data)

    # ── GET /admin/drivers/{id}/reports/ ────────────────────────────────────
    @action(detail=True, methods=["get"])
    def reports(self, request, pk=None):
        profile = self._get_profile(pk)
        if profile is None:
            return Response({"error": "Conducteur introuvable."}, status=404)
        reports = profile.verification_reports.all()
        return Response(VerificationReportSerializer(reports, many=True).data)

    # ── GET /admin/drivers/{id}/signals/ ────────────────────────────────────
    @action(detail=True, methods=["get"])
    def signals(self, request, pk=None):
        profile = self._get_profile(pk)
        if profile is None:
            return Response({"error": "Conducteur introuvable."}, status=404)
        sigs = profile.signals.select_related("reporter").all()
        return Response(DriverSignalSerializer(sigs, many=True).data)

    # ── Statistiques globales ────────────────────────────────────────────────
    @action(detail=False, methods=["get"], url_path="stats")
    def stats(self, request):
        from django.db.models import Count
        qs = DriverProfile.objects.all()
        counts = qs.values("status").annotate(count=Count("id"))
        result = {item["status"]: item["count"] for item in counts}
        result["total"] = sum(result.values())
        return Response(result)


# ─────────────────────────────────────────────────────────────────────────────
# SIGNALEMENT — passager → conducteur
# ─────────────────────────────────────────────────────────────────────────────

class DriverSignalViewSet(viewsets.GenericViewSet):
    """
    POST /driver/{driver_profile_id}/signal/   → signaler un conducteur
    """
    permission_classes = [IsAuthenticated]

    @action(detail=True, methods=["post"], url_path="signal")
    def signal_driver(self, request, pk=None):
        try:
            profile = DriverProfile.objects.get(id=pk)
        except DriverProfile.DoesNotExist:
            return Response({"error": "Conducteur introuvable."}, status=404)

        if profile.user == request.user:
            return Response({"error": "Vous ne pouvez pas vous signaler vous-même."}, status=400)

        serializer = DriverSignalSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=400)

        signal = DriverSignal.objects.create(
            driver_profile=profile,
            reporter=request.user,
            signal_type=serializer.validated_data["signal_type"],
            description=serializer.validated_data["description"],
            trajet=serializer.validated_data.get("trajet"),
        )

        # Vérifier le seuil de suspension automatique
        unprocessed_count = profile.signals.filter(is_processed=False).count()
        if unprocessed_count >= AUTO_SUSPEND_SIGNAL_THRESHOLD and profile.status == DriverStatus.ACTIVE:
            profile.status           = DriverStatus.SUSPENDED
            profile.motif_suspension = f"Suspension automatique après {unprocessed_count} signalements non traités."
            profile.suspended_at     = timezone.now()
            profile.save(update_fields=["status", "motif_suspension", "suspended_at"])

            VerificationHistory.objects.create(
                driver_profile=profile,
                old_status=DriverStatus.ACTIVE,
                new_status=DriverStatus.SUSPENDED,
                reason=profile.motif_suspension,
                is_automatic=True,
            )

            try:
                from apps.modeles.models import Notification
                Notification.objects.create(
                    utilisateur=profile.user,
                    contenu="Votre compte a été suspendu automatiquement suite à plusieurs signalements.",
                )
            except Exception:
                pass

        return Response(
            DriverSignalSerializer(signal).data,
            status=status.HTTP_201_CREATED,
        )
