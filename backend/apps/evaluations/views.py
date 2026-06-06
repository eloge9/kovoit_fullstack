from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from rest_framework.throttling import UserRateThrottle
from django.db import transaction
from django.db.models import Avg
from django.utils import timezone
from ..modeles.models import Evaluation, Trajet, Reservation, Utilisateur, BlocagePassager


class SignalementThrottle(UserRateThrottle):
    scope = 'signalement'


class EvaluationViewSet(viewsets.GenericViewSet):
    permission_classes = [IsAuthenticated]

    # ── Créer une évaluation ──────────────────────────────────────────────
    @action(detail=False, methods=['post'])
    def evaluer(self, request):
        """
        Passager évalue le conducteur OU conducteur évalue le passager.
        Body: {
            trajet_id, cible_id, note (1-5),
            commentaire,
            ponctualite (1-5), conduite (1-5), proprete (1-5)
        }
        """
        trajet_id    = request.data.get('trajet_id')
        cible_id     = request.data.get('cible_id')
        note         = request.data.get('note')
        commentaire  = request.data.get('commentaire', '')
        ponctualite  = request.data.get('ponctualite')
        conduite     = request.data.get('conduite')
        proprete     = request.data.get('proprete')

        # Validations
        if not trajet_id or not cible_id or not note:
            return Response(
                {"error": "trajet_id, cible_id et note sont requis."},
                status=400
            )

        try:
            note = int(note)
            if not 1 <= note <= 5:
                raise ValueError
        except (ValueError, TypeError):
            return Response({"error": "La note doit être entre 1 et 5."}, status=400)

        # Vérifier le trajet
        try:
            trajet = Trajet.objects.get(pk=trajet_id)
        except Trajet.DoesNotExist:
            return Response({"error": "Trajet introuvable."}, status=404)

        # Le trajet doit être terminé
        if trajet.statut != 'termine':
            return Response(
                {"error": "Vous ne pouvez évaluer qu'après la fin du trajet."},
                status=400
            )

        # Vérifier la cible
        try:
            cible = Utilisateur.objects.get(pk=cible_id)
        except Utilisateur.DoesNotExist:
            return Response({"error": "Utilisateur introuvable."}, status=404)

        # Vérifier que l'auteur a participé au trajet
        auteur = request.user
        if auteur == trajet.conducteur:
            # Conducteur évalue un passager — vérifier que le passager a réservé
            if not Reservation.objects.filter(
                trajet=trajet, passager=cible, statut='confirmee'
            ).exists():
                return Response(
                    {"error": "Ce passager n'a pas participé à ce trajet."},
                    status=400
                )
        else:
            # Passager évalue le conducteur — vérifier qu'il a réservé
            if not Reservation.objects.filter(
                trajet=trajet, passager=auteur, statut='confirmee'
            ).exists():
                return Response(
                    {"error": "Vous n'avez pas participé à ce trajet."},
                    status=400
                )
            # La cible doit être le conducteur
            if cible != trajet.conducteur:
                return Response(
                    {"error": "Vous ne pouvez évaluer que le conducteur de ce trajet."},
                    status=400
                )

        # Vérifier qu'il n'a pas déjà évalué
        if Evaluation.objects.filter(trajet=trajet, auteur=auteur, cible=cible).exists():
            return Response(
                {"error": "Vous avez déjà évalué cet utilisateur pour ce trajet."},
                status=400
            )

        # Valider les critères optionnels (must be 1-5 if provided)
        notes_criteres = []
        for label, val in [('ponctualite', ponctualite), ('conduite', conduite), ('proprete', proprete)]:
            if val is not None and val != '':
                try:
                    v = int(val)
                    if not 1 <= v <= 5:
                        raise ValueError
                    notes_criteres.append(v)
                except (ValueError, TypeError):
                    return Response({"error": f"Le critère '{label}' doit être entre 1 et 5."}, status=400)

        if notes_criteres:
            note_finale = round((note + sum(notes_criteres)) / (1 + len(notes_criteres)))
        else:
            note_finale = note

        # Transaction atomique : création + mise à jour note sans race condition
        with transaction.atomic():
            if Evaluation.objects.filter(trajet=trajet, auteur=auteur, cible=cible).exists():
                return Response(
                    {"error": "Vous avez déjà évalué cet utilisateur pour ce trajet."},
                    status=400
                )

            Evaluation.objects.create(
                trajet=trajet,
                auteur=auteur,
                cible=cible,
                note=note_finale,
                commentaire=commentaire,
            )

            # select_for_update évite la race condition sur la moyenne
            cible_locked = Utilisateur.objects.select_for_update().get(pk=cible.pk)
            note_moyenne  = Evaluation.objects.filter(cible=cible).aggregate(Avg('note'))['note__avg']
            cible_locked.note = round(note_moyenne, 2) if note_moyenne else 0
            cible_locked.save(update_fields=['note'])

        return Response({
            "message":    "Évaluation enregistrée.",
            "note":       note_finale,
            "note_cible": cible_locked.note,
        }, status=201)

    # ── Terminer un trajet (conducteur) ───────────────────────────────────
    @action(detail=False, methods=['post'])
    def terminer_trajet(self, request):
        """
        Le conducteur marque le trajet comme terminé.
        Cela débloque les évaluations pour tous les participants.
        Body: { trajet_id }
        """
        trajet_id = request.data.get('trajet_id')
        if not trajet_id:
            return Response({"error": "trajet_id requis."}, status=400)

        try:
            trajet = Trajet.objects.get(pk=trajet_id, conducteur=request.user)
        except Trajet.DoesNotExist:
            return Response({"error": "Trajet introuvable ou non autorisé."}, status=404)

        if trajet.statut == 'termine':
            return Response({"error": "Ce trajet est déjà terminé."}, status=400)

        trajet.statut = 'termine'
        trajet.save()

        return Response({"message": "Trajet marqué comme terminé. Les évaluations sont maintenant disponibles."})

    # ── Évaluations reçues ────────────────────────────────────────────────
    @action(detail=False, methods=['get'])
    def mes_evaluations(self, request):
        evaluations = Evaluation.objects.filter(
            cible=request.user
        ).select_related('auteur', 'trajet').order_by('-date_evaluation')

        data = [{
            "id":             e.id,
            "auteur":         f"{e.auteur.first_name} {e.auteur.last_name}".strip() or e.auteur.username,
            "trajet":         f"{e.trajet.depart} → {e.trajet.destination}",
            "note":           e.note,
            "commentaire":    e.commentaire,
            "date":           e.date_evaluation,
        } for e in evaluations]

        return Response(data)

    # ── Signaler une évaluation abusive ──────────────────────────────────
    @action(detail=False, methods=['post'], throttle_classes=[SignalementThrottle])
    def signaler(self, request):
        """
        Signale une évaluation reçue comme abusive.
        Body: { evaluation_id, motif }
        """
        evaluation_id = request.data.get('evaluation_id')
        motif         = request.data.get('motif', '').strip()

        if not evaluation_id:
            return Response({"error": "evaluation_id requis."}, status=400)

        try:
            evaluation = Evaluation.objects.get(pk=evaluation_id, cible=request.user)
        except Evaluation.DoesNotExist:
            return Response({"error": "Évaluation introuvable ou non accessible."}, status=404)

        if evaluation.signale:
            return Response({"error": "Cette évaluation est déjà signalée."}, status=400)

        evaluation.signale           = True
        evaluation.motif_signalement = motif
        evaluation.date_signalement  = timezone.now()
        evaluation.save(update_fields=['signale', 'motif_signalement', 'date_signalement'])

        return Response({"message": "Évaluation signalée. Notre équipe va l'examiner."})

    # ── Blocage passager (conducteur) ─────────────────────────────────────
    @action(detail=False, methods=['post'])
    def bloquer(self, request):
        """
        Conducteur bloque un passager.
        Body: { passager_id, motif }
        """
        if request.user.role != Utilisateur.Role.CONDUCTEUR:
            return Response({"error": "Seuls les conducteurs peuvent bloquer des passagers."}, status=403)

        passager_id = request.data.get('passager_id')
        motif       = request.data.get('motif', '').strip()

        if not passager_id:
            return Response({"error": "passager_id requis."}, status=400)

        try:
            passager = Utilisateur.objects.get(pk=passager_id)
        except Utilisateur.DoesNotExist:
            return Response({"error": "Passager introuvable."}, status=404)

        _, created = BlocagePassager.objects.get_or_create(
            conducteur=request.user,
            passager=passager,
            defaults={'motif': motif},
        )
        if not created:
            return Response({"error": "Ce passager est déjà bloqué."}, status=400)

        return Response({"message": f"{passager.username} a été bloqué."}, status=201)

    @action(detail=False, methods=['delete'], url_path='debloquer/(?P<passager_id>[0-9a-f-]+)')
    def debloquer(self, request, passager_id=None):
        """Conducteur débloque un passager."""
        deleted, _ = BlocagePassager.objects.filter(
            conducteur=request.user, passager_id=passager_id
        ).delete()
        if not deleted:
            return Response({"error": "Aucun blocage trouvé."}, status=404)
        return Response({"message": "Passager débloqué."})

    @action(detail=False, methods=['get'])
    def mes_blocages(self, request):
        """Liste les passagers bloqués par ce conducteur."""
        blocages = BlocagePassager.objects.filter(
            conducteur=request.user
        ).select_related('passager')
        data = [{
            "passager_id":  str(b.passager.id),
            "nom":          f"{b.passager.first_name} {b.passager.last_name}".strip() or b.passager.username,
            "motif":        b.motif,
            "bloque_le":    b.created_at,
        } for b in blocages]
        return Response(data)

    # ── Trajets à évaluer (passager) ──────────────────────────────────────
    @action(detail=False, methods=['get'])
    def a_evaluer(self, request):
        """
        Retourne les trajets terminés où le passager n'a pas encore évalué.
        """
        # Trajets terminés où l'utilisateur a participé
        reservations = Reservation.objects.filter(
            passager=request.user,
            statut='confirmee',
            trajet__statut='termine'
        ).select_related('trajet', 'trajet__conducteur')

        # Filtrer ceux non encore évalués
        data = []
        for r in reservations:
            deja_evalue = Evaluation.objects.filter(
                trajet=r.trajet,
                auteur=request.user,
                cible=r.trajet.conducteur
            ).exists()

            if not deja_evalue:
                data.append({
                    "trajet_id":      r.trajet.id,
                    "conducteur_id":  str(r.trajet.conducteur.id),
                    "conducteur_nom": f"{r.trajet.conducteur.first_name} {r.trajet.conducteur.last_name}".strip() or r.trajet.conducteur.username,
                    "depart":         r.trajet.depart,
                    "destination":    r.trajet.destination,
                    "date_trajet":    r.trajet.date_heure_depart,
                })

        return Response(data)


# ============================================================
# apps/evaluations/urls.py
# ============================================================
# from rest_framework.routers import DefaultRouter
# from .views import EvaluationViewSet
#
# router = DefaultRouter()
# router.register(r'', EvaluationViewSet, basename='evaluations')
# urlpatterns = router.urls