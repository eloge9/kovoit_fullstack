"""
Views d'administration complètes pour KoVoit
"""
import csv
import json
import io
from datetime import timedelta, date
from calendar import monthrange
from decimal import Decimal

from django.db.models import Count, Sum, Avg, Q, F
from django.db.models.functions import TruncDate, TruncMonth
from django.utils import timezone
from django.http import HttpResponse
from django.contrib.auth.hashers import make_password

from rest_framework import viewsets, status, permissions
from rest_framework.decorators import action
from rest_framework.response import Response

from ..modeles.models import (
    Utilisateur, Conducteur, Passager, Vehicule, Trajet, Reservation,
    Paiement, Evaluation, Plainte, Notification, AuditLog, SysConfig,
)

# ── Permission ────────────────────────────────────────────────────────────────

class IsAdmin(permissions.BasePermission):
    def has_permission(self, request, view):
        return (
            request.user and
            request.user.is_authenticated and
            request.user.role == Utilisateur.Role.ADMIN
        )

# ── Helper audit ─────────────────────────────────────────────────────────────

def _log(request, action: str, description: str, cible_type: str = '', cible_id: str = ''):
    ip = (
        request.META.get('HTTP_X_FORWARDED_FOR', '').split(',')[0].strip()
        or request.META.get('REMOTE_ADDR', '')
    )
    AuditLog.objects.create(
        admin=request.user,
        action=action,
        cible_type=cible_type,
        cible_id=str(cible_id),
        description=description,
        ip_adresse=ip or None,
        user_agent=request.META.get('HTTP_USER_AGENT', '')[:255],
    )

# ── Serialiseurs inline légers ────────────────────────────────────────────────

def _user_mini(u):
    return {
        'id': str(u.id), 'username': u.username,
        'email': u.email, 'role': u.role,
        'first_name': u.first_name, 'last_name': u.last_name,
        'photo_profil': u.photo_profil.url if u.photo_profil else None,
        'note': u.note, 'is_active': u.is_active,
        'date_joined': u.date_joined.isoformat() if u.date_joined else None,
        'last_login': u.last_login.isoformat() if u.last_login else None,
        'statut_validation': u.statut_validation,
        'numero_telephone': u.numero_telephone,
        'driver_status': u.driver_status,
    }

def _user_detail(u):
    d = _user_mini(u)
    d['nb_trajets']      = u.trajets.count() if hasattr(u, 'trajets') else 0
    d['nb_reservations'] = u.reservations.count() if hasattr(u, 'reservations') else 0
    d['nb_evaluations']  = u.evaluations_recues.count() if hasattr(u, 'evaluations_recues') else 0
    d['nb_plaintes']     = u.plaintes_recues.count() if hasattr(u, 'plaintes_recues') else 0
    return d


# ═══════════════════════════════════════════════════════════════════════════════
class AdminViewSet(viewsets.GenericViewSet):
    permission_classes = [IsAdmin]

    # ══════════════════════════ DASHBOARD ════════════════════════════════════

    @action(detail=False, methods=['get'], url_path='dashboard')
    def dashboard(self, request):
        now   = timezone.now()
        today = now.date()
        debut_mois  = date(today.year, today.month, 1)
        debut_semaine = today - timedelta(days=today.weekday())

        # Paiements confirmés
        pays_qs = Paiement.objects.filter(statut__in=['CONFIRME', 'PAYEE'])

        ca_total   = float(pays_qs.aggregate(s=Sum('montant'))['s'] or 0)
        ca_mois    = float(pays_qs.filter(
            Q(date_confirmation__date__gte=debut_mois) |
            Q(date_payement__date__gte=debut_mois)
        ).aggregate(s=Sum('montant'))['s'] or 0)
        ca_semaine = float(pays_qs.filter(
            Q(date_confirmation__date__gte=debut_semaine) |
            Q(date_payement__date__gte=debut_semaine)
        ).aggregate(s=Sum('montant'))['s'] or 0)
        ca_jour    = float(pays_qs.filter(
            Q(date_confirmation__date=today) |
            Q(date_payement__date=today)
        ).aggregate(s=Sum('montant'))['s'] or 0)

        # Messagerie
        try:
            from ..messagerie.models import MessageConv
            nb_messages = MessageConv.objects.count()
        except Exception:
            nb_messages = 0

        return Response({
            # Utilisateurs
            'nb_utilisateurs':   Utilisateur.objects.count(),
            'nb_conducteurs':    Utilisateur.objects.filter(role='conducteur').count(),
            'nb_passagers':      Utilisateur.objects.filter(role='passager').count(),
            'nb_inactifs':       Utilisateur.objects.filter(is_active=False).count(),

            # Trajets
            'nb_trajets':        Trajet.objects.count(),
            'nb_trajets_ouverts':  Trajet.objects.filter(statut='ouvert').count(),
            'nb_trajets_cours':    Trajet.objects.filter(statut='en_cours').count(),
            'nb_trajets_termines': Trajet.objects.filter(statut='termine').count(),
            'nb_trajets_annules':  Trajet.objects.filter(statut='annule').count(),
            'nb_trajets_jour':   Trajet.objects.filter(created_at__date=today).count(),

            # Réservations
            'nb_reservations':       Reservation.objects.count(),
            'nb_reservations_jour':  Reservation.objects.filter(date_reservation__date=today).count(),
            'nb_reservations_conf':  Reservation.objects.filter(statut='confirmee').count(),
            'nb_reservations_att':   Reservation.objects.filter(statut='en_attente').count(),

            # Paiements
            'nb_paiements_confirmes': pays_qs.count(),
            'nb_paiements_attente':   Paiement.objects.filter(statut='EN_ATTENTE_CONFIRMATION').count(),

            # Finance
            'ca_jour':     ca_jour,
            'ca_semaine':  ca_semaine,
            'ca_mois':     ca_mois,
            'ca_total':    ca_total,
            'commission_kovoit': round(ca_total * 0.10),
            'net_conducteurs':   round(ca_total * 0.90),

            # Qualité
            'nb_evaluations':       Evaluation.objects.count(),
            'nb_evaluations_signal': Evaluation.objects.filter(signale=True).count(),
            'nb_plaintes':          Plainte.objects.count(),
            'nb_plaintes_attente':  Plainte.objects.filter(statut='en_attente').count(),
            'nb_messages':          nb_messages,
            'nb_notifications':     Notification.objects.count(),
        })

    # ══════════════════════════ SÉRIES TEMPORELLES ════════════════════════════

    @action(detail=False, methods=['get'], url_path='stats/series')
    def stats_series(self, request):
        """Séries temporelles pour les graphiques (30 derniers jours)."""
        nb_jours = int(request.query_params.get('jours', 30))
        debut    = timezone.now().date() - timedelta(days=nb_jours - 1)

        # Inscriptions par jour
        inscriptions = (
            Utilisateur.objects
            .filter(date_joined__date__gte=debut)
            .annotate(jour=TruncDate('date_joined'))
            .values('jour')
            .annotate(nb=Count('id'))
            .order_by('jour')
        )

        # Trajets par jour
        trajets_j = (
            Trajet.objects
            .filter(created_at__date__gte=debut)
            .annotate(jour=TruncDate('created_at'))
            .values('jour')
            .annotate(nb=Count('id'))
            .order_by('jour')
        )

        # Réservations par jour
        resas_j = (
            Reservation.objects
            .filter(date_reservation__date__gte=debut)
            .annotate(jour=TruncDate('date_reservation'))
            .values('jour')
            .annotate(nb=Count('id'))
            .order_by('jour')
        )

        # Revenus par jour
        revenus_j = (
            Paiement.objects
            .filter(statut__in=['CONFIRME', 'PAYEE'])
            .filter(
                Q(date_confirmation__date__gte=debut) |
                Q(date_payement__date__gte=debut)
            )
            .annotate(jour=TruncDate('date_confirmation'))
            .values('jour')
            .annotate(total=Sum('montant'))
            .order_by('jour')
        )

        # Inscriptions par mois (12 mois)
        debut_mois = timezone.now().date().replace(day=1) - timedelta(days=365)
        inscriptions_mois = (
            Utilisateur.objects
            .filter(date_joined__date__gte=debut_mois)
            .annotate(mois=TruncMonth('date_joined'))
            .values('mois')
            .annotate(nb=Count('id'))
            .order_by('mois')
        )

        def fmt(qs, key='nb'):
            return [{'date': str(r['jour']), 'valeur': float(r.get(key, r.get('nb', 0)) or 0)} for r in qs]

        return Response({
            'inscriptions':       fmt(inscriptions),
            'trajets':            fmt(trajets_j),
            'reservations':       fmt(resas_j),
            'revenus':            [{'date': str(r['jour']), 'valeur': float(r['total'] or 0)} for r in revenus_j],
            'inscriptions_mois':  [{'date': r['mois'].strftime('%Y-%m'), 'valeur': r['nb']} for r in inscriptions_mois],
        })

    # ══════════════════════════ ACTIVITÉ RÉCENTE ══════════════════════════════

    @action(detail=False, methods=['get'], url_path='recent')
    def recent(self, request):
        limit = int(request.query_params.get('limit', 5))

        def u(obj): return _user_mini(obj)

        derniers_users = [
            u(x) for x in Utilisateur.objects.order_by('-date_joined')[:limit]
        ]
        derniers_trajets = [
            {
                'id': t.id, 'depart': t.depart, 'destination': t.destination,
                'statut': t.statut,
                'conducteur': t.conducteur.username,
                'date': t.created_at.isoformat(),
            }
            for t in Trajet.objects.select_related('conducteur').order_by('-created_at')[:limit]
        ]
        dernieres_resas = [
            {
                'id': r.id, 'statut': r.statut,
                'passager': r.passager.username,
                'trajet': f"{r.trajet.depart} → {r.trajet.destination}",
                'date': r.date_reservation.isoformat(),
            }
            for r in Reservation.objects.select_related('passager', 'trajet').order_by('-date_reservation')[:limit]
        ]
        derniers_paiements = [
            {
                'id': p.id, 'montant': float(p.montant),
                'commission': round(float(p.montant) * 0.10),
                'net': round(float(p.montant) * 0.90),
                'statut': p.statut,
                'passager': p.passager.username if p.passager else '—',
                'date': (p.date_payement or p.date_confirmation or p.date_creation).isoformat() if (p.date_payement or p.date_confirmation or p.date_creation) else None,
            }
            for p in Paiement.objects.select_related('passager').filter(statut__in=['CONFIRME','PAYEE']).order_by('-date_creation')[:limit]
        ]
        dernieres_plaintes = [
            {
                'id': str(pl.id), 'titre': pl.titre,
                'type': pl.type_plainte, 'statut': pl.statut,
                'signalataire': pl.signalataire.username if pl.signalataire else '—',
                'date': pl.date_creation.isoformat(),
            }
            for pl in Plainte.objects.select_related('signalataire').order_by('-date_creation')[:limit]
        ]
        dernieres_evals = [
            {
                'id': e.id, 'note': e.note,
                'auteur': e.auteur.username, 'cible': e.cible.username,
                'statut': e.statut, 'signale': e.signale,
                'date': e.date_evaluation.isoformat(),
            }
            for e in Evaluation.objects.select_related('auteur', 'cible').order_by('-date_evaluation')[:limit]
        ]

        return Response({
            'utilisateurs': derniers_users,
            'trajets':      derniers_trajets,
            'reservations': dernieres_resas,
            'paiements':    derniers_paiements,
            'plaintes':     dernieres_plaintes,
            'evaluations':  dernieres_evals,
        })

    # ══════════════════════════ RECHERCHE GLOBALE ════════════════════════════

    @action(detail=False, methods=['get'], url_path='search')
    def search(self, request):
        q = request.query_params.get('q', '').strip()
        if len(q) < 2:
            return Response({'error': 'Requête trop courte (min 2 caractères).'}, status=400)

        users = Utilisateur.objects.filter(
            Q(username__icontains=q) | Q(email__icontains=q) |
            Q(first_name__icontains=q) | Q(last_name__icontains=q) |
            Q(numero_telephone__icontains=q)
        )[:10]

        trajets = Trajet.objects.filter(
            Q(depart__icontains=q) | Q(destination__icontains=q) |
            Q(conducteur__username__icontains=q)
        ).select_related('conducteur')[:10]

        resas = Reservation.objects.filter(
            Q(passager__username__icontains=q) |
            Q(trajet__depart__icontains=q) |
            Q(code_embarquement__icontains=q)
        ).select_related('passager', 'trajet')[:10]

        vehicules = Vehicule.objects.filter(
            Q(marque__icontains=q) | Q(modele__icontains=q) |
            Q(plaque__icontains=q)
        ).select_related('conducteur__utilisateur')[:10]

        return Response({
            'utilisateurs': [_user_mini(u) for u in users],
            'trajets': [
                {
                    'id': t.id, 'depart': t.depart, 'destination': t.destination,
                    'statut': t.statut, 'conducteur': t.conducteur.username,
                    'date': t.date_heure_depart.isoformat(),
                }
                for t in trajets
            ],
            'reservations': [
                {
                    'id': r.id, 'statut': r.statut,
                    'passager': r.passager.username,
                    'trajet': f"{r.trajet.depart} → {r.trajet.destination}",
                    'code': r.code_embarquement,
                }
                for r in resas
            ],
            'vehicules': [
                {
                    'id': v.id, 'type': v.type_vehicule,
                    'marque': v.marque, 'modele': v.modele, 'plaque': v.plaque,
                    'conducteur': v.conducteur.utilisateur.username,
                }
                for v in vehicules
            ],
        })

    # ══════════════════════════ UTILISATEURS ═════════════════════════════════

    @action(detail=False, methods=['get'], url_path='utilisateurs')
    def lister_utilisateurs(self, request):
        qs = Utilisateur.objects.all().order_by('-date_joined')

        role = request.query_params.get('role')
        actif = request.query_params.get('actif')
        q    = request.query_params.get('q', '').strip()

        if role:
            qs = qs.filter(role=role)
        if actif is not None and actif != '':
            qs = qs.filter(is_active=(actif.lower() == 'true'))
        if q:
            qs = qs.filter(
                Q(username__icontains=q) | Q(email__icontains=q) |
                Q(first_name__icontains=q) | Q(last_name__icontains=q) |
                Q(numero_telephone__icontains=q)
            )

        # Pagination simple
        page  = int(request.query_params.get('page', 1))
        limit = int(request.query_params.get('limit', 50))
        total = qs.count()
        qs    = qs[(page - 1) * limit : page * limit]

        return Response({
            'total': total, 'page': page, 'limit': limit,
            'resultats': [_user_detail(u) for u in qs],
        })

    @action(detail=False, methods=['get'], url_path=r'utilisateurs/(?P<user_id>[\w-]+)$')
    def detail_utilisateur(self, request, user_id=None):
        try:
            u = Utilisateur.objects.get(pk=user_id)
            d = _user_detail(u)
            # Dernières réservations
            d['dernieres_reservations'] = list(
                u.reservations.order_by('-date_reservation').values(
                    'id', 'statut', 'date_reservation',
                    depart=F('trajet__depart'), destination=F('trajet__destination')
                )[:5]
            )
            # Derniers paiements (passager)
            d['derniers_paiements'] = [
                {'id': p.id, 'montant': float(p.montant), 'statut': p.statut,
                 'date': (p.date_payement or p.date_creation).isoformat() if (p.date_payement or p.date_creation) else None}
                for p in Paiement.objects.filter(passager=u).order_by('-date_creation')[:5]
            ]
            # Évaluations reçues
            d['nb_evals_recues']  = u.evaluations_recues.count()
            d['note_evaluations'] = u.evaluations_recues.aggregate(avg=Avg('note'))['avg'] or 0
            return Response(d)
        except Utilisateur.DoesNotExist:
            return Response({'error': 'Utilisateur non trouvé'}, status=404)

    @action(detail=False, methods=['post'], url_path=r'utilisateurs/(?P<user_id>[\w-]+)/suspendre')
    def suspendre_utilisateur(self, request, user_id=None):
        try:
            u = Utilisateur.objects.get(pk=user_id)
            u.is_active = False
            u.save()
            _log(request, 'user_suspend', f"Suspension de {u.username}", 'utilisateur', user_id)
            return Response({'message': f'{u.username} suspendu', 'is_active': False})
        except Utilisateur.DoesNotExist:
            return Response({'error': 'Utilisateur non trouvé'}, status=404)

    @action(detail=False, methods=['post'], url_path=r'utilisateurs/(?P<user_id>[\w-]+)/activer')
    def activer_utilisateur(self, request, user_id=None):
        try:
            u = Utilisateur.objects.get(pk=user_id)
            u.is_active = True
            u.save()
            _log(request, 'user_activate', f"Activation de {u.username}", 'utilisateur', user_id)
            return Response({'message': f'{u.username} réactivé', 'is_active': True})
        except Utilisateur.DoesNotExist:
            return Response({'error': 'Utilisateur non trouvé'}, status=404)

    @action(detail=False, methods=['post'], url_path=r'utilisateurs/(?P<user_id>[\w-]+)/bannir')
    def bannir_utilisateur(self, request, user_id=None):
        try:
            u = Utilisateur.objects.get(pk=user_id)
            if u.role == 'admin':
                return Response({'error': 'Impossible de bannir un administrateur.'}, status=400)
            u.is_active = False
            u.save()
            _log(request, 'user_ban',
                 f"Bannissement de {u.username} — motif: {request.data.get('motif', '')}",
                 'utilisateur', user_id)
            return Response({'message': f'{u.username} banni définitivement'})
        except Utilisateur.DoesNotExist:
            return Response({'error': 'Utilisateur non trouvé'}, status=404)

    @action(detail=False, methods=['post'], url_path=r'utilisateurs/(?P<user_id>[\w-]+)/reset-password')
    def reset_password(self, request, user_id=None):
        try:
            u = Utilisateur.objects.get(pk=user_id)
            nouveau = request.data.get('nouveau_mot_de_passe', '')
            if len(nouveau) < 6:
                return Response({'error': 'Mot de passe trop court (min 6 caractères).'}, status=400)
            u.password = make_password(nouveau)
            u.save()
            _log(request, 'user_suspend', f"Reset mot de passe de {u.username}", 'utilisateur', user_id)
            return Response({'message': f'Mot de passe de {u.username} réinitialisé.'})
        except Utilisateur.DoesNotExist:
            return Response({'error': 'Utilisateur non trouvé'}, status=404)

    @action(detail=False, methods=['post'], url_path=r'utilisateurs/(?P<user_id>[\w-]+)/valider-documents')
    def valider_documents(self, request, user_id=None):
        try:
            u = Utilisateur.objects.get(pk=user_id)
            u.statut_validation = 'valide'
            u.is_active = True
            u.peut_conduire = True
            u.save()
            from ..modeles.models import Passager as ProfilPassager
            ProfilPassager.objects.get_or_create(utilisateur=u)
            _log(request, 'doc_validate', f"Documents validés pour {u.username}", 'utilisateur', user_id)
            return Response({'message': f'Documents de {u.username} validés.'})
        except Utilisateur.DoesNotExist:
            return Response({'error': 'Utilisateur non trouvé'}, status=404)

    @action(detail=False, methods=['post'], url_path=r'utilisateurs/(?P<user_id>[\w-]+)/rejeter-documents')
    def rejeter_documents(self, request, user_id=None):
        try:
            u = Utilisateur.objects.get(pk=user_id)
            u.statut_validation = 'rejete'
            u.peut_conduire = False
            u.save()
            _log(request, 'doc_reject',
                 f"Documents rejetés pour {u.username} — motif: {request.data.get('motif', '')}",
                 'utilisateur', user_id)
            return Response({'message': f'Documents de {u.username} rejetés.'})
        except Utilisateur.DoesNotExist:
            return Response({'error': 'Utilisateur non trouvé'}, status=404)

    @action(detail=False, methods=['post'], url_path=r'utilisateurs/(?P<user_id>[\w-]+)/supprimer')
    def supprimer_utilisateur(self, request, user_id=None):
        try:
            u = Utilisateur.objects.get(pk=user_id)
            if u.role == 'admin':
                return Response({'error': 'Impossible de supprimer un administrateur.'}, status=400)
            username = u.username
            _log(request, 'user_delete', f"Suppression de {username}", 'utilisateur', user_id)
            u.delete()
            return Response({'message': f'Utilisateur {username} supprimé définitivement.'})
        except Utilisateur.DoesNotExist:
            return Response({'error': 'Utilisateur non trouvé'}, status=404)

    @action(detail=False, methods=['get'], url_path='utilisateurs/export/csv')
    def export_utilisateurs_csv(self, request):
        role = request.query_params.get('role', '')
        qs   = Utilisateur.objects.all().order_by('-date_joined')
        if role:
            qs = qs.filter(role=role)

        buf = io.StringIO()
        writer = csv.writer(buf)
        writer.writerow(['ID', 'Username', 'Email', 'Prénom', 'Nom', 'Rôle',
                         'Téléphone', 'Actif', 'Note', 'Date inscription'])
        for u in qs:
            writer.writerow([
                str(u.id), u.username, u.email, u.first_name, u.last_name,
                u.role, u.numero_telephone or '', u.is_active, u.note,
                u.date_joined.strftime('%d/%m/%Y %H:%M'),
            ])
        _log(request, 'user_role', f"Export CSV utilisateurs (role={role or 'tous'})")
        resp = HttpResponse(buf.getvalue(), content_type='text/csv; charset=utf-8')
        resp['Content-Disposition'] = 'attachment; filename="utilisateurs.csv"'
        return resp

    # ══════════════════════════ TRAJETS ══════════════════════════════════════

    @action(detail=False, methods=['get'], url_path='trajets')
    def lister_trajets(self, request):
        qs = Trajet.objects.select_related('conducteur', 'vehicule').order_by('-created_at')

        statut  = request.query_params.get('statut')
        q       = request.query_params.get('q', '').strip()
        page    = int(request.query_params.get('page', 1))
        limit   = int(request.query_params.get('limit', 50))

        if statut:
            qs = qs.filter(statut=statut)
        if q:
            qs = qs.filter(
                Q(depart__icontains=q) | Q(destination__icontains=q) |
                Q(conducteur__username__icontains=q)
            )
        total = qs.count()
        qs    = qs[(page-1)*limit : page*limit]

        return Response({
            'total': total, 'page': page,
            'resultats': [
                {
                    'id': t.id, 'depart': t.depart, 'destination': t.destination,
                    'statut': t.statut, 'prix_par_place': float(t.prix_par_place),
                    'places_disponibles': t.places_disponibles,
                    'distance_km': t.distance_km,
                    'date_depart': t.date_heure_depart.isoformat(),
                    'conducteur_id': str(t.conducteur.id),
                    'conducteur': t.conducteur.username,
                    'vehicule': f"{t.vehicule.marque} {t.vehicule.modele}" if t.vehicule else None,
                    'nb_reservations': t.reservations.count(),
                    'created_at': t.created_at.isoformat(),
                }
                for t in qs
            ],
        })

    @action(detail=False, methods=['post'], url_path=r'trajets/(?P<trajet_id>[0-9]+)/annuler')
    def annuler_trajet(self, request, trajet_id=None):
        try:
            t = Trajet.objects.get(pk=trajet_id)
            if t.statut == 'annule':
                return Response({'error': 'Trajet déjà annulé.'}, status=400)
            t.statut = 'annule'
            t.save()
            _log(request, 'trip_cancel',
                 f"Annulation trajet #{trajet_id} ({t.depart}→{t.destination}) — {request.data.get('motif', '')}",
                 'trajet', trajet_id)
            return Response({'message': 'Trajet annulé.'})
        except Trajet.DoesNotExist:
            return Response({'error': 'Trajet non trouvé.'}, status=404)

    @action(detail=False, methods=['post'], url_path=r'trajets/(?P<trajet_id>[0-9]+)/supprimer')
    def supprimer_trajet(self, request, trajet_id=None):
        try:
            t = Trajet.objects.get(pk=trajet_id)
            desc = f"{t.depart}→{t.destination}"
            _log(request, 'trip_delete', f"Suppression trajet #{trajet_id} ({desc})", 'trajet', trajet_id)
            t.delete()
            return Response({'message': 'Trajet supprimé.'})
        except Trajet.DoesNotExist:
            return Response({'error': 'Trajet non trouvé.'}, status=404)

    @action(detail=False, methods=['get'], url_path='trajets/export/csv')
    def export_trajets_csv(self, request):
        qs = Trajet.objects.select_related('conducteur').order_by('-created_at')
        statut = request.query_params.get('statut')
        if statut:
            qs = qs.filter(statut=statut)
        buf = io.StringIO()
        w   = csv.writer(buf)
        w.writerow(['ID','Conducteur','Départ','Destination','Date','Prix/place','Places','Statut','Distance'])
        for t in qs:
            w.writerow([t.id, t.conducteur.username, t.depart, t.destination,
                        t.date_heure_depart.strftime('%d/%m/%Y %H:%M'),
                        float(t.prix_par_place), t.places_disponibles, t.statut, t.distance_km or ''])
        resp = HttpResponse(buf.getvalue(), content_type='text/csv; charset=utf-8')
        resp['Content-Disposition'] = 'attachment; filename="trajets.csv"'
        return resp

    # ══════════════════════════ RÉSERVATIONS ═════════════════════════════════

    @action(detail=False, methods=['get'], url_path='reservations')
    def lister_reservations(self, request):
        qs = Reservation.objects.select_related('passager', 'trajet', 'trajet__conducteur').order_by('-date_reservation')

        statut = request.query_params.get('statut')
        q      = request.query_params.get('q', '').strip()
        page   = int(request.query_params.get('page', 1))
        limit  = int(request.query_params.get('limit', 50))

        if statut:
            qs = qs.filter(statut=statut)
        if q:
            qs = qs.filter(
                Q(passager__username__icontains=q) |
                Q(trajet__depart__icontains=q) |
                Q(trajet__destination__icontains=q) |
                Q(code_embarquement__icontains=q)
            )
        total = qs.count()
        qs    = qs[(page-1)*limit : page*limit]

        return Response({
            'total': total, 'page': page,
            'resultats': [
                {
                    'id': r.id, 'statut': r.statut,
                    'passager_id': str(r.passager.id),
                    'passager': r.passager.username,
                    'conducteur': r.trajet.conducteur.username,
                    'depart': r.trajet.depart,
                    'destination': r.trajet.destination,
                    'date_trajet': r.trajet.date_heure_depart.isoformat(),
                    'date_reservation': r.date_reservation.isoformat(),
                    'places': r.places_reservees,
                    'prix': float(r.prix_passager or r.trajet.prix_par_place),
                    'code': r.code_embarquement,
                }
                for r in qs
            ],
        })

    @action(detail=False, methods=['post'], url_path=r'reservations/(?P<resa_id>[0-9]+)/annuler')
    def annuler_reservation(self, request, resa_id=None):
        try:
            r = Reservation.objects.get(pk=resa_id)
            r.statut = 'declinee'
            r.save()
            _log(request, 'resa_cancel',
                 f"Annulation réservation #{resa_id} par admin — {request.data.get('motif', '')}",
                 'reservation', resa_id)
            return Response({'message': 'Réservation annulée.'})
        except Reservation.DoesNotExist:
            return Response({'error': 'Réservation non trouvée.'}, status=404)

    # ══════════════════════════ PAIEMENTS ════════════════════════════════════

    @action(detail=False, methods=['get'], url_path='paiements')
    def lister_paiements(self, request):
        qs = Paiement.objects.select_related('reservation', 'passager', 'conducteur',
                                             'reservation__trajet').order_by('-date_creation')
        statut = request.query_params.get('statut')
        moyen  = request.query_params.get('moyen')
        q      = request.query_params.get('q', '').strip()
        page   = int(request.query_params.get('page', 1))
        limit  = int(request.query_params.get('limit', 50))

        if statut:
            qs = qs.filter(statut=statut)
        if moyen:
            qs = qs.filter(moyen_paiement=moyen)
        if q:
            qs = qs.filter(
                Q(passager__username__icontains=q) |
                Q(conducteur__username__icontains=q)
            )
        total = qs.count()
        qs    = qs[(page-1)*limit : page*limit]

        def _p(p):
            m = float(p.montant)
            return {
                'id': p.id,
                'reservation_id': p.reservation_id,
                'passager': p.passager.username if p.passager else '—',
                'conducteur': p.conducteur.username if p.conducteur else '—',
                'trajet': f"{p.reservation.trajet.depart}→{p.reservation.trajet.destination}" if p.reservation else '—',
                'montant': m,
                'commission': round(m * 0.10),
                'net': round(m * 0.90),
                'moyen': p.moyen_paiement,
                'statut': p.statut,
                'date': (p.date_payement or p.date_confirmation or p.date_creation).isoformat() if (p.date_payement or p.date_confirmation or p.date_creation) else None,
            }

        pays_conf = Paiement.objects.filter(statut__in=['CONFIRME', 'PAYEE'])
        ca = float(pays_conf.aggregate(s=Sum('montant'))['s'] or 0)

        return Response({
            'total': total, 'page': page,
            'ca_total': ca, 'commission_total': round(ca * 0.10), 'net_total': round(ca * 0.90),
            'resultats': [_p(p) for p in qs],
        })

    @action(detail=False, methods=['get'], url_path='paiements/statistiques')
    def statistiques_paiements(self, request):
        pays = Paiement.objects.filter(statut__in=['CONFIRME', 'PAYEE'])
        ca   = float(pays.aggregate(s=Sum('montant'))['s'] or 0)
        return Response({
            'ca_total':        ca,
            'commission':      round(ca * 0.10),
            'net_conducteurs': round(ca * 0.90),
            'nb_transactions': pays.count(),
            'moyen_transaction': round(ca / pays.count(), 2) if pays.count() > 0 else 0,
            'par_moyen': list(pays.values('moyen_paiement').annotate(nb=Count('id'), total=Sum('montant'))),
        })

    @action(detail=False, methods=['get'], url_path='paiements/export/csv')
    def export_paiements_csv(self, request):
        qs = Paiement.objects.select_related('passager', 'conducteur', 'reservation__trajet').order_by('-date_creation')
        buf = io.StringIO()
        w   = csv.writer(buf)
        w.writerow(['ID','Passager','Conducteur','Trajet','Montant','Commission','Net','Moyen','Statut','Date'])
        for p in qs:
            m = float(p.montant)
            trajet = f"{p.reservation.trajet.depart}→{p.reservation.trajet.destination}" if p.reservation else ''
            w.writerow([
                p.id, p.passager.username if p.passager else '', p.conducteur.username if p.conducteur else '',
                trajet, m, round(m*0.10), round(m*0.90), p.moyen_paiement, p.statut,
                (p.date_payement or p.date_creation).strftime('%d/%m/%Y %H:%M') if (p.date_payement or p.date_creation) else '',
            ])
        resp = HttpResponse(buf.getvalue(), content_type='text/csv; charset=utf-8')
        resp['Content-Disposition'] = 'attachment; filename="paiements.csv"'
        return resp

    # ══════════════════════════ VÉHICULES ════════════════════════════════════

    @action(detail=False, methods=['get'], url_path='vehicules')
    def lister_vehicules(self, request):
        qs = Vehicule.objects.select_related('conducteur__utilisateur').order_by('-created_at')

        type_veh = request.query_params.get('type')
        actif    = request.query_params.get('actif')
        q        = request.query_params.get('q', '').strip()
        page     = int(request.query_params.get('page', 1))
        limit    = int(request.query_params.get('limit', 50))

        if type_veh:
            qs = qs.filter(type_vehicule=type_veh)
        if actif is not None and actif != '':
            qs = qs.filter(est_actif=(actif.lower() == 'true'))
        if q:
            qs = qs.filter(
                Q(marque__icontains=q) | Q(modele__icontains=q) |
                Q(plaque__icontains=q) |
                Q(conducteur__utilisateur__username__icontains=q)
            )
        total = qs.count()
        qs    = qs[(page-1)*limit : page*limit]

        return Response({
            'total': total, 'page': page,
            'resultats': [
                {
                    'id': v.id, 'type': v.type_vehicule,
                    'marque': v.marque, 'modele': v.modele,
                    'couleur': v.couleur, 'plaque': v.plaque,
                    'places_max': v.places_max, 'est_actif': v.est_actif,
                    'conducteur_id': str(v.conducteur.utilisateur.id),
                    'conducteur': v.conducteur.utilisateur.username,
                    'photo': v.photo_carte_grise.url if v.photo_carte_grise else None,
                    'created_at': v.created_at.isoformat(),
                }
                for v in qs
            ],
        })

    @action(detail=False, methods=['post'], url_path=r'vehicules/(?P<veh_id>[0-9]+)/suspendre')
    def suspendre_vehicule(self, request, veh_id=None):
        try:
            v = Vehicule.objects.get(pk=veh_id)
            v.est_actif = False
            v.save()
            _log(request, 'trip_modify', f"Suspension véhicule #{veh_id} ({v.plaque})", 'vehicule', veh_id)
            return Response({'message': f'Véhicule {v.plaque} suspendu.'})
        except Vehicule.DoesNotExist:
            return Response({'error': 'Véhicule non trouvé.'}, status=404)

    @action(detail=False, methods=['post'], url_path=r'vehicules/(?P<veh_id>[0-9]+)/activer')
    def activer_vehicule(self, request, veh_id=None):
        try:
            v = Vehicule.objects.get(pk=veh_id)
            v.est_actif = True
            v.save()
            _log(request, 'trip_modify', f"Activation véhicule #{veh_id} ({v.plaque})", 'vehicule', veh_id)
            return Response({'message': f'Véhicule {v.plaque} activé.'})
        except Vehicule.DoesNotExist:
            return Response({'error': 'Véhicule non trouvé.'}, status=404)

    # ══════════════════════════ ÉVALUATIONS ══════════════════════════════════

    @action(detail=False, methods=['get'], url_path='evaluations')
    def lister_evaluations(self, request):
        qs = Evaluation.objects.select_related('auteur', 'cible', 'trajet').order_by('-date_evaluation')

        signale = request.query_params.get('signale')
        statut  = request.query_params.get('statut')
        q       = request.query_params.get('q', '').strip()
        page    = int(request.query_params.get('page', 1))
        limit   = int(request.query_params.get('limit', 50))

        if signale == 'true':
            qs = qs.filter(signale=True)
        if statut:
            qs = qs.filter(statut=statut)
        if q:
            qs = qs.filter(
                Q(auteur__username__icontains=q) | Q(cible__username__icontains=q) |
                Q(commentaire__icontains=q)
            )
        total = qs.count()
        qs    = qs[(page-1)*limit : page*limit]

        return Response({
            'total': total, 'page': page,
            'resultats': [
                {
                    'id': e.id, 'note': e.note, 'commentaire': e.commentaire,
                    'statut': e.statut, 'signale': e.signale,
                    'motif_signalement': e.motif_signalement,
                    'auteur_id': str(e.auteur.id), 'auteur': e.auteur.username,
                    'cible_id': str(e.cible.id), 'cible': e.cible.username,
                    'trajet': f"{e.trajet.depart}→{e.trajet.destination}" if e.trajet else '—',
                    'date': e.date_evaluation.isoformat(),
                    'date_limite': e.date_limite.isoformat() if e.date_limite else None,
                }
                for e in qs
            ],
        })

    @action(detail=False, methods=['post'], url_path=r'evaluations/(?P<eval_id>[0-9]+)/masquer')
    def masquer_evaluation(self, request, eval_id=None):
        try:
            e = Evaluation.objects.get(pk=eval_id)
            e.statut = 'verrouillee'
            e.save()
            _log(request, 'eval_hide', f"Masquage évaluation #{eval_id}", 'evaluation', eval_id)
            return Response({'message': 'Évaluation masquée.'})
        except Evaluation.DoesNotExist:
            return Response({'error': 'Évaluation non trouvée.'}, status=404)

    @action(detail=False, methods=['post'], url_path=r'evaluations/(?P<eval_id>[0-9]+)/restaurer')
    def restaurer_evaluation(self, request, eval_id=None):
        try:
            e = Evaluation.objects.get(pk=eval_id)
            e.statut = 'publiee'
            e.save()
            _log(request, 'eval_restore', f"Restauration évaluation #{eval_id}", 'evaluation', eval_id)
            return Response({'message': 'Évaluation restaurée.'})
        except Evaluation.DoesNotExist:
            return Response({'error': 'Évaluation non trouvée.'}, status=404)

    # ══════════════════════════ PLAINTES ═════════════════════════════════════

    @action(detail=False, methods=['get'], url_path='plaintes')
    def lister_plaintes(self, request):
        qs = Plainte.objects.select_related('signalataire', 'utilisateur_signale', 'admin_assigne').order_by('-date_creation')

        statut = request.query_params.get('statut')
        type_p = request.query_params.get('type')
        page   = int(request.query_params.get('page', 1))
        limit  = int(request.query_params.get('limit', 50))

        if statut:
            qs = qs.filter(statut=statut)
        if type_p:
            qs = qs.filter(type_plainte=type_p)
        total = qs.count()
        qs    = qs[(page-1)*limit : page*limit]

        return Response({
            'total': total, 'page': page,
            'resultats': [
                {
                    'id': str(p.id), 'titre': p.titre,
                    'description': p.description,
                    'type': p.type_plainte, 'statut': p.statut,
                    'signalataire': p.signalataire.username if p.signalataire else '—',
                    'signale': p.utilisateur_signale.username,
                    'admin': p.admin_assigne.username if p.admin_assigne else None,
                    'note_admin': p.note_admin,
                    'date_creation': p.date_creation.isoformat(),
                    'date_resolution': p.date_resolution.isoformat() if p.date_resolution else None,
                }
                for p in qs
            ],
        })

    @action(detail=False, methods=['post'], url_path=r'plaintes/(?P<pid>[\w-]+)/assigner')
    def assigner_plainte(self, request, pid=None):
        try:
            p = Plainte.objects.get(pk=pid)
            p.admin_assigne = request.user
            p.statut = 'en_cours'
            p.save()
            _log(request, 'complaint_assign', f"Assignation plainte #{pid}", 'plainte', pid)
            return Response({'message': 'Plainte assignée.'})
        except Plainte.DoesNotExist:
            return Response({'error': 'Plainte non trouvée.'}, status=404)

    @action(detail=False, methods=['post'], url_path=r'plaintes/(?P<pid>[\w-]+)/resoudre')
    def resoudre_plainte(self, request, pid=None):
        try:
            p = Plainte.objects.get(pk=pid)
            p.statut = 'resolue'
            p.note_admin = request.data.get('note_admin', '')
            p.date_resolution = timezone.now()
            p.save()
            _log(request, 'complaint_close', f"Résolution plainte #{pid}", 'plainte', pid)
            return Response({'message': 'Plainte résolue.'})
        except Plainte.DoesNotExist:
            return Response({'error': 'Plainte non trouvée.'}, status=404)

    @action(detail=False, methods=['post'], url_path=r'plaintes/(?P<pid>[\w-]+)/rejeter')
    def rejeter_plainte(self, request, pid=None):
        try:
            p = Plainte.objects.get(pk=pid)
            p.statut = 'rejetee'
            p.note_admin = request.data.get('note_admin', '')
            p.date_resolution = timezone.now()
            p.save()
            _log(request, 'complaint_reject', f"Rejet plainte #{pid}", 'plainte', pid)
            return Response({'message': 'Plainte rejetée.'})
        except Plainte.DoesNotExist:
            return Response({'error': 'Plainte non trouvée.'}, status=404)

    # ══════════════════════════ MESSAGERIE ═══════════════════════════════════

    @action(detail=False, methods=['get'], url_path='messagerie/conversations')
    def messagerie_conversations(self, request):
        try:
            from ..messagerie.models import Conversation, Participant
            qs = Conversation.objects.prefetch_related('participants__utilisateur').order_by('-updated_at')
            q  = request.query_params.get('q', '').strip()
            page  = int(request.query_params.get('page', 1))
            limit = int(request.query_params.get('limit', 50))
            if q:
                qs = qs.filter(participants__utilisateur__username__icontains=q).distinct()
            total = qs.count()
            qs    = qs[(page-1)*limit : page*limit]

            _log(request, 'msg_read', f"Consultation liste conversations (q={q or '—'})")

            return Response({
                'total': total, 'page': page,
                'resultats': [
                    {
                        'id': c.id,
                        'statut': c.statut,
                        'participants': [
                            {'id': str(p.utilisateur.id), 'username': p.utilisateur.username}
                            for p in c.participants.all()
                        ],
                        'nb_messages': c.messages.count() if hasattr(c, 'messages') else 0,
                        'updated_at': c.updated_at.isoformat() if c.updated_at else None,
                    }
                    for c in qs
                ],
            })
        except Exception as e:
            return Response({'error': str(e)}, status=500)

    @action(detail=False, methods=['get'], url_path=r'messagerie/conversations/(?P<conv_id>[0-9]+)/messages')
    def messagerie_messages(self, request, conv_id=None):
        try:
            from ..messagerie.models import Conversation, MessageConv
            conv = Conversation.objects.get(pk=conv_id)
            msgs = MessageConv.objects.filter(conversation=conv).select_related('auteur').order_by('created_at')

            _log(request, 'msg_read', f"Lecture messages conversation #{conv_id}", 'conversation', conv_id)

            return Response([
                {
                    'id': m.id, 'contenu': m.contenu,
                    'auteur_id': str(m.auteur.id), 'auteur': m.auteur.username,
                    'timestamp': m.created_at.isoformat(),
                }
                for m in msgs
            ])
        except Exception as e:
            return Response({'error': str(e)}, status=500)

    # ══════════════════════════ NOTIFICATIONS ════════════════════════════════

    @action(detail=False, methods=['get'], url_path='notifications')
    def lister_notifications(self, request):
        qs    = Notification.objects.select_related('utilisateur').order_by('-date_notification')
        page  = int(request.query_params.get('page', 1))
        limit = int(request.query_params.get('limit', 50))
        total = qs.count()
        qs    = qs[(page-1)*limit : page*limit]
        return Response({
            'total': total, 'page': page,
            'resultats': [
                {
                    'id': n.id, 'contenu': n.contenu,
                    'lu': n.lu,
                    'destinataire': n.utilisateur.username,
                    'date': n.date_notification.isoformat(),
                }
                for n in qs
            ],
        })

    @action(detail=False, methods=['post'], url_path='notifications/envoyer')
    def envoyer_notification(self, request):
        contenu       = request.data.get('contenu', '').strip()
        cible_role    = request.data.get('role', '')       # '' = tous
        utilisateur_id = request.data.get('utilisateur_id') # cible spécifique

        if not contenu:
            return Response({'error': 'Contenu requis.'}, status=400)

        if utilisateur_id:
            try:
                dest = [Utilisateur.objects.get(pk=utilisateur_id)]
            except Utilisateur.DoesNotExist:
                return Response({'error': 'Utilisateur non trouvé.'}, status=404)
        elif cible_role:
            dest = list(Utilisateur.objects.filter(role=cible_role, is_active=True))
        else:
            dest = list(Utilisateur.objects.filter(is_active=True))

        notifs = [Notification(utilisateur=u, contenu=contenu) for u in dest]
        Notification.objects.bulk_create(notifs)

        _log(request, 'notif_send',
             f"Envoi notification à {len(dest)} destinataire(s) (role={cible_role or 'tous'}): {contenu[:80]}")

        return Response({'message': f'Notification envoyée à {len(dest)} utilisateur(s).'})

    # ══════════════════════════ CONFIGURATION ════════════════════════════════

    CONFIG_DEFAUTS = {
        'tarif_moto':              ('30',    'Tarif FCFA/km pour moto'),
        'tarif_voiture':           ('65',    'Tarif FCFA/km pour voiture'),
        'tarif_minibus':           ('120',   'Tarif FCFA/km pour minibus'),
        'tarif_camion':            ('200',   'Tarif FCFA/km pour camion'),
        'commission_kovoit':       ('10',    'Commission plateforme (%)'),
        'rayon_recherche_km':      ('5',     'Rayon de recherche par défaut (km)'),
        'rayons_disponibles':      ('0.5,1,2,3,5', 'Rayons disponibles (virgule séparés)'),
        'duree_modif_evaluation':  ('24',   'Durée modification évaluation (heures)'),
        'delai_annulation_min':    ('30',   'Délai annulation réservation (minutes)'),
        'places_max_reservation':  ('5',    'Nombre max de places par réservation'),
    }

    @action(detail=False, methods=['get'], url_path='config')
    def lister_config(self, request):
        # S'assurer que toutes les clés par défaut existent
        for cle, (val, desc) in self.CONFIG_DEFAUTS.items():
            SysConfig.objects.get_or_create(cle=cle, defaults={'valeur': val, 'description': desc})

        configs = SysConfig.objects.all()
        return Response([
            {
                'id': c.id, 'cle': c.cle, 'valeur': c.valeur,
                'description': c.description,
                'modifie_par': c.modifie_par.username if c.modifie_par else None,
                'date_modification': c.date_modification.isoformat(),
            }
            for c in configs
        ])

    @action(detail=False, methods=['post'], url_path=r'config/(?P<cle>[\w_]+)/update')
    def modifier_config(self, request, cle=None):
        valeur = str(request.data.get('valeur', '')).strip()
        if not valeur:
            return Response({'error': 'Valeur requise.'}, status=400)

        try:
            # Validation numérique pour les clés numériques
            if cle in ('tarif_moto', 'tarif_voiture', 'tarif_minibus', 'tarif_camion',
                       'commission_kovoit', 'rayon_recherche_km',
                       'duree_modif_evaluation', 'delai_annulation_min', 'places_max_reservation'):
                float(valeur)  # lance ValueError si non numérique

            c, created = SysConfig.objects.get_or_create(
                cle=cle,
                defaults={'valeur': valeur, 'modifie_par': request.user}
            )
            if not created:
                ancienne = c.valeur
                c.valeur = valeur
                c.modifie_par = request.user
                c.save()
            else:
                ancienne = None

            _log(request, 'config_update',
                 f"Config '{cle}' modifiée: {ancienne} → {valeur}", 'config', cle)

            return Response({
                'message': f"Configuration '{cle}' mise à jour.",
                'cle': cle, 'valeur': valeur,
            })
        except ValueError:
            return Response({'error': 'Valeur numérique requise pour cette configuration.'}, status=400)

    # ══════════════════════════ AUDIT LOG ════════════════════════════════════

    @action(detail=False, methods=['get'], url_path='audit')
    def audit_logs(self, request):
        qs = AuditLog.objects.select_related('admin').order_by('-date_action')

        action_f = request.query_params.get('action')
        admin_id = request.query_params.get('admin_id')
        page     = int(request.query_params.get('page', 1))
        limit    = int(request.query_params.get('limit', 50))

        if action_f:
            qs = qs.filter(action=action_f)
        if admin_id:
            qs = qs.filter(admin_id=admin_id)
        total = qs.count()
        qs    = qs[(page-1)*limit : page*limit]

        return Response({
            'total': total, 'page': page,
            'resultats': [
                {
                    'id': a.id,
                    'admin': a.admin.username if a.admin else '—',
                    'action': a.action,
                    'action_label': dict(AuditLog.ACTION_CHOICES).get(a.action, a.action),
                    'cible_type': a.cible_type, 'cible_id': a.cible_id,
                    'description': a.description,
                    'ip': a.ip_adresse,
                    'date': a.date_action.isoformat(),
                }
                for a in qs
            ],
        })

    # ══════════════════════════ STATISTIQUES GLOBALES ════════════════════════

    @action(detail=False, methods=['get'], url_path='statistiques')
    def statistiques_globales(self, request):
        pays = Paiement.objects.filter(statut__in=['CONFIRME', 'PAYEE'])
        ca   = float(pays.aggregate(s=Sum('montant'))['s'] or 0)
        return Response({
            'nb_utilisateurs':    Utilisateur.objects.count(),
            'nb_conducteurs':     Utilisateur.objects.filter(role='conducteur').count(),
            'nb_passagers':       Utilisateur.objects.filter(role='passager').count(),
            'nb_admins':          Utilisateur.objects.filter(role='admin').count(),
            'nb_inactifs':        Utilisateur.objects.filter(is_active=False).count(),
            'nb_trajets':         Trajet.objects.count(),
            'nb_trajets_termines': Trajet.objects.filter(statut='termine').count(),
            'nb_reservations':    Reservation.objects.count(),
            'nb_paiements':       pays.count(),
            'ca_total':           ca,
            'commission':         round(ca * 0.10),
            'net_conducteurs':    round(ca * 0.90),
            'nb_evaluations':     Evaluation.objects.count(),
            'nb_plaintes':        Plainte.objects.count(),
            'nb_plaintes_att':    Plainte.objects.filter(statut='en_attente').count(),
        })
