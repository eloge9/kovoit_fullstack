from datetime import timedelta

from django.db import transaction
from django.db.models import Avg, Count, Q
from django.utils import timezone
from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.throttling import UserRateThrottle

from ..modeles.models import (
    BlocagePassager, Evaluation, Reservation, Trajet, Utilisateur,
)

FENETRE_HEURES = 24


class SignalementThrottle(UserRateThrottle):
    scope = 'signalement'


def _verrouiller_expirees():
    """Lock evaluations whose 24 h window has closed."""
    Evaluation.objects.filter(
        statut=Evaluation.PUBLIEE,
        date_limite__lt=timezone.now(),
    ).update(statut=Evaluation.VERROUILLEE)


def _parse_critere(data, key):
    val = data.get(key)
    if val is None or val == '':
        return None
    try:
        v = int(val)
        if not 1 <= v <= 5:
            raise ValueError
        return v
    except (ValueError, TypeError):
        raise ValueError(f"Le critère '{key}' doit être entre 1 et 5.")


def _note_finale(note, criteres_values):
    valeurs = [v for v in criteres_values if v is not None]
    if valeurs:
        return round((note + sum(valeurs)) / (1 + len(valeurs)))
    return note


def _update_note_cible(cible):
    note_moy = Evaluation.objects.filter(cible=cible).aggregate(Avg('note'))['note__avg']
    cible.note = round(note_moy, 2) if note_moy else 0
    cible.save(update_fields=['note'])


def _eval_to_dict(e, *, viewer=None):
    """Serialize an Evaluation for REST responses."""
    d = {
        "id":             e.id,
        "auteur_id":      str(e.auteur_id),
        "auteur":         f"{e.auteur.first_name} {e.auteur.last_name}".strip() or e.auteur.username,
        "auteur_photo":   e.auteur.photo_profil.url if getattr(e.auteur, 'photo_profil', None) and e.auteur.photo_profil else None,
        "cible_id":       str(e.cible_id),
        "cible":          f"{e.cible.first_name} {e.cible.last_name}".strip() or e.cible.username,
        "trajet":         f"{e.trajet.depart} → {e.trajet.destination}",
        "trajet_id":      e.trajet_id,
        "reservation_id": e.reservation_id,
        "note":           e.note,
        "commentaire":    e.commentaire,
        "date":           e.date_evaluation,
        "date_limite":    e.date_limite,
        "statut":         e.statut,
        "signale":        e.signale,
        # critères passager→conducteur
        "ponctualite":    e.ponctualite,
        "courtoisie":     e.courtoisie,
        "conduite":       e.conduite,
        "respect_trajet": e.respect_trajet,
        # critères conducteur→passager
        "respect_conducteur": e.respect_conducteur,
        "respect_vehicule":   e.respect_vehicule,
        "communication":      e.communication,
    }
    if viewer:
        d["modifiable"] = (
            e.auteur_id == viewer.pk
            and e.statut == Evaluation.PUBLIEE
            and e.date_limite is not None
            and e.date_limite > timezone.now()
        )
    return d


class EvaluationViewSet(viewsets.GenericViewSet):
    permission_classes = [IsAuthenticated]

    # ── Créer une évaluation ──────────────────────────────────────────────
    @action(detail=False, methods=['post'])
    def evaluer(self, request):
        trajet_id   = request.data.get('trajet_id')
        cible_id    = request.data.get('cible_id')
        note        = request.data.get('note')
        commentaire = request.data.get('commentaire', '')

        if not trajet_id or not cible_id or not note:
            return Response({"error": "trajet_id, cible_id et note sont requis."}, status=400)

        try:
            note = int(note)
            if not 1 <= note <= 5:
                raise ValueError
        except (ValueError, TypeError):
            return Response({"error": "La note doit être entre 1 et 5."}, status=400)

        try:
            trajet = Trajet.objects.get(pk=trajet_id)
        except Trajet.DoesNotExist:
            return Response({"error": "Trajet introuvable."}, status=404)

        if trajet.statut != 'termine':
            return Response({"error": "Vous ne pouvez évaluer qu'après la fin du trajet."}, status=400)

        try:
            cible = Utilisateur.objects.get(pk=cible_id)
        except Utilisateur.DoesNotExist:
            return Response({"error": "Utilisateur introuvable."}, status=404)

        auteur = request.user
        reservation = None

        if auteur == trajet.conducteur:
            # Conducteur évalue un passager
            try:
                reservation = Reservation.objects.get(
                    trajet=trajet, passager=cible, statut__in=['confirmee', 'terminee']
                )
            except Reservation.DoesNotExist:
                return Response({"error": "Ce passager n'a pas participé à ce trajet."}, status=400)
            # Critères conducteur→passager
            try:
                ponctualite        = _parse_critere(request.data, 'ponctualite')
                respect_conducteur = _parse_critere(request.data, 'respect_conducteur')
                respect_vehicule   = _parse_critere(request.data, 'respect_vehicule')
                communication      = _parse_critere(request.data, 'communication')
            except ValueError as exc:
                return Response({"error": str(exc)}, status=400)
            note_calc = _note_finale(note, [ponctualite, respect_conducteur, respect_vehicule, communication])
            extra = dict(
                ponctualite=ponctualite,
                respect_conducteur=respect_conducteur,
                respect_vehicule=respect_vehicule,
                communication=communication,
            )
        else:
            # Passager évalue le conducteur
            try:
                reservation = Reservation.objects.get(
                    trajet=trajet, passager=auteur, statut__in=['confirmee', 'terminee']
                )
            except Reservation.DoesNotExist:
                return Response({"error": "Vous n'avez pas participé à ce trajet."}, status=400)
            if cible != trajet.conducteur:
                return Response({"error": "Vous ne pouvez évaluer que le conducteur de ce trajet."}, status=400)
            # Critères passager→conducteur
            try:
                ponctualite    = _parse_critere(request.data, 'ponctualite')
                courtoisie     = _parse_critere(request.data, 'courtoisie')
                conduite       = _parse_critere(request.data, 'conduite')
                respect_trajet = _parse_critere(request.data, 'respect_trajet')
            except ValueError as exc:
                return Response({"error": str(exc)}, status=400)
            note_calc = _note_finale(note, [ponctualite, courtoisie, conduite, respect_trajet])
            extra = dict(
                ponctualite=ponctualite,
                courtoisie=courtoisie,
                conduite=conduite,
                respect_trajet=respect_trajet,
            )

        with transaction.atomic():
            if Evaluation.objects.filter(trajet=trajet, auteur=auteur, cible=cible).exists():
                return Response({"error": "Vous avez déjà évalué cet utilisateur pour ce trajet."}, status=400)

            date_limite = timezone.now() + timedelta(hours=FENETRE_HEURES)
            evaluation = Evaluation.objects.create(
                trajet=trajet,
                reservation=reservation,
                auteur=auteur,
                cible=cible,
                note=note_calc,
                commentaire=commentaire,
                date_limite=date_limite,
                statut=Evaluation.PUBLIEE,
                **extra,
            )

            cible_locked = Utilisateur.objects.select_for_update().get(pk=cible.pk)
            _update_note_cible(cible_locked)

        # Push notification via Django Channels
        try:
            from channels.layers import get_channel_layer
            from asgiref.sync import async_to_sync
            channel_layer = get_channel_layer()
            if channel_layer:
                async_to_sync(channel_layer.group_send)(
                    f"notif_{cible.pk}",
                    {
                        "type": "chat.notification",
                        "data": {
                            "type":    "nouvelle_evaluation",
                            "message": f"{auteur.username} vous a évalué {note_calc}/5",
                            "eval_id": evaluation.id,
                        },
                    },
                )
        except Exception:
            pass

        # Charger les relations en mémoire pour la sérialisation
        evaluation.auteur = auteur
        evaluation.cible  = cible_locked
        evaluation.trajet = trajet

        return Response(_eval_to_dict(evaluation, viewer=auteur), status=201)

    # ── Modifier une évaluation (dans la fenêtre de 24 h) ────────────────
    @action(detail=False, methods=['put'], url_path='modifier/(?P<eval_id>[0-9]+)')
    def modifier_evaluation(self, request, eval_id=None):
        _verrouiller_expirees()
        try:
            evaluation = Evaluation.objects.select_related('cible').get(
                pk=eval_id, auteur=request.user
            )
        except Evaluation.DoesNotExist:
            return Response({"error": "Évaluation introuvable."}, status=404)

        if evaluation.statut == Evaluation.VERROUILLEE:
            return Response({"error": "La fenêtre de modification de 24 h est expirée."}, status=403)

        note = request.data.get('note')
        if note is not None:
            try:
                note = int(note)
                if not 1 <= note <= 5:
                    raise ValueError
            except (ValueError, TypeError):
                return Response({"error": "La note doit être entre 1 et 5."}, status=400)

        commentaire = request.data.get('commentaire', evaluation.commentaire)

        # Déterminer le type d'évaluation et parser les critères correspondants
        if evaluation.auteur == evaluation.trajet.conducteur:
            # conducteur→passager
            try:
                ponctualite        = _parse_critere(request.data, 'ponctualite') if 'ponctualite' in request.data else evaluation.ponctualite
                respect_conducteur = _parse_critere(request.data, 'respect_conducteur') if 'respect_conducteur' in request.data else evaluation.respect_conducteur
                respect_vehicule   = _parse_critere(request.data, 'respect_vehicule') if 'respect_vehicule' in request.data else evaluation.respect_vehicule
                communication      = _parse_critere(request.data, 'communication') if 'communication' in request.data else evaluation.communication
            except ValueError as exc:
                return Response({"error": str(exc)}, status=400)
            if note is not None:
                note = _note_finale(note, [ponctualite, respect_conducteur, respect_vehicule, communication])
            evaluation.ponctualite        = ponctualite
            evaluation.respect_conducteur = respect_conducteur
            evaluation.respect_vehicule   = respect_vehicule
            evaluation.communication      = communication
        else:
            # passager→conducteur
            try:
                ponctualite    = _parse_critere(request.data, 'ponctualite') if 'ponctualite' in request.data else evaluation.ponctualite
                courtoisie     = _parse_critere(request.data, 'courtoisie') if 'courtoisie' in request.data else evaluation.courtoisie
                conduite       = _parse_critere(request.data, 'conduite') if 'conduite' in request.data else evaluation.conduite
                respect_trajet = _parse_critere(request.data, 'respect_trajet') if 'respect_trajet' in request.data else evaluation.respect_trajet
            except ValueError as exc:
                return Response({"error": str(exc)}, status=400)
            if note is not None:
                note = _note_finale(note, [ponctualite, courtoisie, conduite, respect_trajet])
            evaluation.ponctualite    = ponctualite
            evaluation.courtoisie     = courtoisie
            evaluation.conduite       = conduite
            evaluation.respect_trajet = respect_trajet

        if note is not None:
            evaluation.note = note
        evaluation.commentaire = commentaire
        update_fields = ['note', 'commentaire', 'ponctualite', 'courtoisie', 'conduite',
                         'respect_trajet', 'respect_conducteur', 'respect_vehicule', 'communication']
        evaluation.save(update_fields=update_fields)

        with transaction.atomic():
            cible_locked = Utilisateur.objects.select_for_update().get(pk=evaluation.cible_id)
            _update_note_cible(cible_locked)

        return Response({"message": "Évaluation mise à jour.", "note_cible": cible_locked.note})

    # ── Terminer un trajet (conducteur) ───────────────────────────────────
    @action(detail=False, methods=['post'])
    def terminer_trajet(self, request):
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

        return Response({"message": "Trajet terminé. Les évaluations sont maintenant disponibles."})

    # ── Évaluations reçues ────────────────────────────────────────────────
    @action(detail=False, methods=['get'])
    def mes_evaluations(self, request):
        _verrouiller_expirees()
        evaluations = (
            Evaluation.objects
            .filter(cible=request.user)
            .select_related('auteur', 'trajet')
            .order_by('-date_evaluation')
        )
        return Response([_eval_to_dict(e, viewer=request.user) for e in evaluations])

    # ── Évaluations données ───────────────────────────────────────────────
    @action(detail=False, methods=['get'])
    def mes_evaluations_donnees(self, request):
        _verrouiller_expirees()
        evaluations = (
            Evaluation.objects
            .filter(auteur=request.user)
            .select_related('cible', 'auteur', 'trajet')
            .order_by('-date_evaluation')
        )
        return Response([_eval_to_dict(e, viewer=request.user) for e in evaluations])

    # ── Trajets à évaluer — passager évalue le conducteur ────────────────
    @action(detail=False, methods=['get'])
    def a_evaluer(self, request):
        reservations = Reservation.objects.filter(
            passager=request.user,
            statut__in=['confirmee', 'terminee'],
            trajet__statut='termine',
        ).select_related('trajet', 'trajet__conducteur').order_by('-trajet__date_heure_depart')

        data = []
        for r in reservations:
            if Evaluation.objects.filter(
                trajet=r.trajet, auteur=request.user, cible=r.trajet.conducteur
            ).exists():
                continue
            data.append({
                "trajet_id":      r.trajet.id,
                "conducteur_id":  str(r.trajet.conducteur.id),
                "conducteur_nom": f"{r.trajet.conducteur.first_name} {r.trajet.conducteur.last_name}".strip() or r.trajet.conducteur.username,
                "depart":         r.trajet.depart,
                "destination":    r.trajet.destination,
                "date_trajet":    r.trajet.date_heure_depart,
            })
        return Response(data)

    # ── Passagers à évaluer — conducteur évalue ses passagers ────────────
    @action(detail=False, methods=['get'])
    def passagers_a_evaluer(self, request):
        if request.user.role != Utilisateur.Role.CONDUCTEUR:
            return Response({"error": "Réservé aux conducteurs."}, status=403)

        trajets_termines = Trajet.objects.filter(
            conducteur=request.user, statut='termine'
        ).prefetch_related(
            'reservations__passager'
        ).order_by('-date_heure_depart')

        data = []
        for trajet in trajets_termines:
            passagers_restants = []
            for r in trajet.reservations.filter(statut__in=['confirmee', 'terminee']).select_related('passager'):
                if Evaluation.objects.filter(
                    trajet=trajet, auteur=request.user, cible=r.passager
                ).exists():
                    continue
                passagers_restants.append({
                    "passager_id":  str(r.passager.id),
                    "passager_nom": f"{r.passager.first_name} {r.passager.last_name}".strip() or r.passager.username,
                    "reservation_id": r.id,
                })
            if passagers_restants:
                data.append({
                    "trajet_id":   trajet.id,
                    "depart":      trajet.depart,
                    "destination": trajet.destination,
                    "date_trajet": trajet.date_heure_depart,
                    "passagers":   passagers_restants,
                })
        return Response(data)

    # ── Signaler une évaluation abusive ──────────────────────────────────
    @action(detail=False, methods=['post'], throttle_classes=[SignalementThrottle])
    def signaler(self, request):
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
            conducteur=request.user, passager=passager, defaults={'motif': motif},
        )
        if not created:
            return Response({"error": "Ce passager est déjà bloqué."}, status=400)
        return Response({"message": f"{passager.username} a été bloqué."}, status=201)

    @action(detail=False, methods=['delete'], url_path='debloquer/(?P<passager_id>[0-9a-f-]+)')
    def debloquer(self, request, passager_id=None):
        deleted, _ = BlocagePassager.objects.filter(
            conducteur=request.user, passager_id=passager_id
        ).delete()
        if not deleted:
            return Response({"error": "Aucun blocage trouvé."}, status=404)
        return Response({"message": "Passager débloqué."})

    @action(detail=False, methods=['get'])
    def mes_blocages(self, request):
        blocages = BlocagePassager.objects.filter(
            conducteur=request.user
        ).select_related('passager')
        return Response([{
            "passager_id": str(b.passager.id),
            "nom":         f"{b.passager.first_name} {b.passager.last_name}".strip() or b.passager.username,
            "motif":       b.motif,
            "bloque_le":   b.created_at,
        } for b in blocages])

    # ── Admin : statistiques globales ─────────────────────────────────────
    @action(detail=False, methods=['get'])
    def admin_stats(self, request):
        if not (request.user.is_staff or request.user.is_superuser):
            return Response({"error": "Accès refusé."}, status=403)

        _verrouiller_expirees()

        qs = Evaluation.objects.select_related('auteur', 'cible', 'trajet')
        signalees = request.query_params.get('signalees')
        statut_filtre = request.query_params.get('statut')
        if signalees == '1':
            qs = qs.filter(signale=True)
        if statut_filtre in (Evaluation.PUBLIEE, Evaluation.VERROUILLEE):
            qs = qs.filter(statut=statut_filtre)

        total = qs.count()
        note_moy = qs.aggregate(Avg('note'))['note__avg'] or 0

        top_notes = (
            Evaluation.objects.values('cible__id', 'cible__username', 'cible__first_name', 'cible__last_name')
            .annotate(moy=Avg('note'), nb=Count('id'))
            .filter(nb__gte=3)
            .order_by('-moy')[:5]
        )
        pires_notes = (
            Evaluation.objects.values('cible__id', 'cible__username', 'cible__first_name', 'cible__last_name')
            .annotate(moy=Avg('note'), nb=Count('id'))
            .filter(nb__gte=3)
            .order_by('moy')[:5]
        )

        evals_page = qs.order_by('-date_evaluation')[:50]
        return Response({
            "stats": {
                "total":        total,
                "note_moyenne": round(note_moy, 2),
                "nb_signalees": Evaluation.objects.filter(signale=True).count(),
                "nb_verrouillee": Evaluation.objects.filter(statut=Evaluation.VERROUILLEE).count(),
                "top_utilisateurs": list(top_notes),
                "pires_utilisateurs": list(pires_notes),
            },
            "evaluations": [_eval_to_dict(e) for e in evals_page],
        })
