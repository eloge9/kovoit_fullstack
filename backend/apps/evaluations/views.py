from django.shortcuts import render

# Create your views here.
# ============================================================
# apps/evaluations/views.py
# ============================================================
from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.db.models import Avg
from ..modeles.models import Evaluation, Trajet, Reservation, Utilisateur


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

        # Calculer la note finale (moyenne note générale + critères)
        notes_criteres = []
        if ponctualite: notes_criteres.append(int(ponctualite))
        if conduite:    notes_criteres.append(int(conduite))
        if proprete:    notes_criteres.append(int(proprete))

        if notes_criteres:
            note_finale = round((note + sum(notes_criteres)) / (1 + len(notes_criteres)))
        else:
            note_finale = note

        # Créer l'évaluation
        evaluation = Evaluation.objects.create(
            trajet=trajet,
            auteur=auteur,
            cible=cible,
            note=note_finale,
            commentaire=commentaire,
        )

        # Mettre à jour la note moyenne de la cible
        note_moyenne = Evaluation.objects.filter(
            cible=cible
        ).aggregate(Avg('note'))['note__avg']

        cible.note = round(note_moyenne, 2) if note_moyenne else 0
        cible.save()

        return Response({
            "message":    "Évaluation enregistrée.",
            "note":       note_finale,
            "note_cible": cible.note,
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