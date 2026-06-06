"""
Views d'administration pour KoVoit
"""
from rest_framework import viewsets, status, permissions
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, IsAdminUser
from django.db.models import Count, Sum, Avg, Q, F
from django.utils import timezone
from datetime import timedelta

from ..modeles.models import (
    Utilisateur, Conducteur, Vehicule, Trajet, Reservation, Paiement,
    Evaluation, Plainte
)
from ..modeles.serializers import (
    UtilisateurDetailAdminSerializer, TrajetDetailAdminSerializer,
    PaiementDetailAdminSerializer, PlainteSerializer,
    StatistiquesGlobalesSerializer
)


class IsAdmin(permissions.BasePermission):
    """Permission personnalisée pour l'admin"""
    def has_permission(self, request, view):
        return request.user and request.user.is_authenticated and request.user.role == 'admin'


class AdminViewSet(viewsets.GenericViewSet):
    """
    ViewSet d'administration avec les endpoints suivants:
    - GET  /api/administration/utilisateurs/              → Lister tous les utilisateurs
    - GET  /api/administration/utilisateurs/{id}/         → Détails d'un utilisateur
    - POST /api/administration/utilisateurs/{id}/valider-conducteur/ → Valider un conducteur
    - POST /api/administration/utilisateurs/{id}/suspendre/ → Suspendre un utilisateur
    - POST /api/administration/utilisateurs/{id}/activer/ → Réactiver un utilisateur
    - GET  /api/administration/trajets/                   → Lister tous les trajets
    - GET  /api/administration/paiements/                 → Lister tous les paiements
    - GET  /api/administration/plaintes/                  → Lister les plaintes
    - POST /api/administration/plaintes/{id}/assigner/    → Assigner une plainte
    - POST /api/administration/plaintes/{id}/resoudre/    → Marquer comme résolue
    - GET  /api/administration/statistiques/              → Statistiques globales
    """
    permission_classes = [IsAdmin]
    
    # ========== UTILISATEURS ==========
    
    @action(detail=False, methods=['get'], url_path='utilisateurs')
    def lister_utilisateurs(self, request):
        """Lister tous les utilisateurs avec filtrage par rôle"""
        role = request.query_params.get('role')
        actif = request.query_params.get('actif')
        
        queryset = Utilisateur.objects.all()
        
        if role:
            queryset = queryset.filter(role=role)
        
        if actif is not None:
            queryset = queryset.filter(is_active=(actif.lower() == 'true'))
        
        serializer = UtilisateurDetailAdminSerializer(queryset, many=True)
        return Response(serializer.data)
    
    @action(detail=False, methods=['get'], url_path=r'utilisateurs/(?P<user_id>[\w-]+)')
    def detail_utilisateur(self, request, user_id=None):
        """Voir les détails d'un utilisateur spécifique"""
        try:
            utilisateur = Utilisateur.objects.get(pk=user_id)
            serializer = UtilisateurDetailAdminSerializer(utilisateur)
            return Response(serializer.data)
        except Utilisateur.DoesNotExist:
            return Response(
                {'error': 'Utilisateur non trouvé'},
                status=status.HTTP_404_NOT_FOUND
            )
    
    @action(detail=False, methods=['post'], url_path=r'utilisateurs/(?P<user_id>[\w-]+)/valider-conducteur')
    def valider_conducteur(self, request, user_id=None):
        """Valider et activer un conducteur (vérifier ses documents)"""
        try:
            utilisateur = Utilisateur.objects.get(pk=user_id, role='conducteur')
            
            # Vérifications
            if not hasattr(utilisateur, 'profil_conducteur'):
                return Response(
                    {'error': 'Cet utilisateur n\'est pas enregistré comme conducteur'},
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            conducteur = utilisateur.profil_conducteur
            
            # Vérifier les véhicules
            if not conducteur.vehicules.exists():
                return Response(
                    {'error': 'Le conducteur n\'a pas de véhicule enregistré'},
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            # Activer le conducteur
            utilisateur.is_active = True
            utilisateur.save()
            
            return Response({
                'message': 'Conducteur validé et activé',
                'utilisateur': UtilisateurDetailAdminSerializer(utilisateur).data
            }, status=status.HTTP_200_OK)
            
        except Utilisateur.DoesNotExist:
            return Response(
                {'error': 'Conducteur non trouvé'},
                status=status.HTTP_404_NOT_FOUND
            )
    
    @action(detail=False, methods=['post'], url_path=r'utilisateurs/(?P<user_id>[\w-]+)/suspendre')
    def suspendre_utilisateur(self, request, user_id=None):
        """Suspendre un utilisateur (le désactiver)"""
        try:
            utilisateur = Utilisateur.objects.get(pk=user_id)
            utilisateur.is_active = False
            utilisateur.save()
            
            return Response({
                'message': f'Utilisateur {utilisateur.username} suspendu',
                'utilisateur': UtilisateurDetailAdminSerializer(utilisateur).data
            }, status=status.HTTP_200_OK)
            
        except Utilisateur.DoesNotExist:
            return Response(
                {'error': 'Utilisateur non trouvé'},
                status=status.HTTP_404_NOT_FOUND
            )
    
    @action(detail=False, methods=['post'], url_path=r'utilisateurs/(?P<user_id>[\w-]+)/activer')
    def activer_utilisateur(self, request, user_id=None):
        """Réactiver un utilisateur suspendu"""
        try:
            utilisateur = Utilisateur.objects.get(pk=user_id)
            utilisateur.is_active = True
            utilisateur.save()
            
            return Response({
                'message': f'Utilisateur {utilisateur.username} réactivé',
                'utilisateur': UtilisateurDetailAdminSerializer(utilisateur).data
            }, status=status.HTTP_200_OK)
            
        except Utilisateur.DoesNotExist:
            return Response(
                {'error': 'Utilisateur non trouvé'},
                status=status.HTTP_404_NOT_FOUND
            )
    
    @action(detail=False, methods=['post'], url_path=r'utilisateurs/(?P<user_id>[\w-]+)/valider-documents')
    def valider_documents(self, request, user_id=None):
        """Valider les documents CNI/Permis d'un utilisateur et l'activer."""
        try:
            utilisateur = Utilisateur.objects.get(pk=user_id)

            if utilisateur.statut_validation not in ('en_attente', 'rejete'):
                return Response(
                    {'error': 'Aucun document en attente de validation pour cet utilisateur.'},
                    status=status.HTTP_400_BAD_REQUEST
                )

            utilisateur.statut_validation = 'valide'
            utilisateur.is_active    = True
            utilisateur.peut_conduire = True   # autorise le double rôle
            utilisateur.save()

            # Créer le profil Passager s'il n'existe pas (pour permettre le basculement)
            from ..modeles.models import Passager as ProfilPassager
            ProfilPassager.objects.get_or_create(utilisateur=utilisateur)

            return Response({
                'message': f'Documents de {utilisateur.username} validés. Double rôle activé.',
                'utilisateur': UtilisateurDetailAdminSerializer(utilisateur).data
            }, status=status.HTTP_200_OK)

        except Utilisateur.DoesNotExist:
            return Response({'error': 'Utilisateur non trouvé'}, status=status.HTTP_404_NOT_FOUND)

    @action(detail=False, methods=['post'], url_path=r'utilisateurs/(?P<user_id>[\w-]+)/rejeter-documents')
    def rejeter_documents(self, request, user_id=None):
        """Rejeter les documents d'un utilisateur avec un motif optionnel."""
        try:
            utilisateur = Utilisateur.objects.get(pk=user_id)
            utilisateur.statut_validation = 'rejete'
            utilisateur.peut_conduire     = False
            utilisateur.save()

            return Response({
                'message': f'Documents de {utilisateur.username} rejetés.',
                'utilisateur': UtilisateurDetailAdminSerializer(utilisateur).data
            }, status=status.HTTP_200_OK)

        except Utilisateur.DoesNotExist:
            return Response({'error': 'Utilisateur non trouvé'}, status=status.HTTP_404_NOT_FOUND)

    @action(detail=False, methods=['post'], url_path=r'utilisateurs/(?P<user_id>[\w-]+)/supprimer')
    def supprimer_utilisateur(self, request, user_id=None):
        """Supprimer définitivement un utilisateur (à utiliser avec prudence)"""
        try:
            utilisateur = Utilisateur.objects.get(pk=user_id)
            username = utilisateur.username
            utilisateur.delete()
            
            return Response({
                'message': f'Utilisateur {username} supprimé définitivement'
            }, status=status.HTTP_200_OK)
            
        except Utilisateur.DoesNotExist:
            return Response(
                {'error': 'Utilisateur non trouvé'},
                status=status.HTTP_404_NOT_FOUND
            )
    
    # ========== TRAJETS ==========
    
    @action(detail=False, methods=['get'], url_path='trajets')
    def lister_trajets(self, request):
        """Lister tous les trajets avec filtrage par statut"""
        statut = request.query_params.get('statut')
        conducteur_id = request.query_params.get('conducteur_id')
        date_depuis = request.query_params.get('date_depuis')
        
        queryset = Trajet.objects.all().select_related('conducteur', 'vehicule')
        
        if statut:
            queryset = queryset.filter(statut=statut)
        
        if conducteur_id:
            queryset = queryset.filter(conducteur_id=conducteur_id)
        
        if date_depuis:
            try:
                date_depuis = timezone.datetime.fromisoformat(date_depuis)
                queryset = queryset.filter(date_heure_depart__gte=date_depuis)
            except ValueError:
                pass
        
        serializer = TrajetDetailAdminSerializer(queryset, many=True)
        return Response(serializer.data)
    
    # ========== PAIEMENTS ==========
    
    @action(detail=False, methods=['get'], url_path='paiements')
    def lister_paiements(self, request):
        """Lister tous les paiements avec filtrage par statut"""
        statut = request.query_params.get('statut')
        moyen = request.query_params.get('moyen')
        date_depuis = request.query_params.get('date_depuis')
        
        queryset = Paiement.objects.all().select_related(
            'reservation', 'passager', 'conducteur'
        )
        
        if statut:
            queryset = queryset.filter(statut=statut)
        
        if moyen:
            queryset = queryset.filter(moyen_paiement=moyen)
        
        if date_depuis:
            try:
                date_depuis = timezone.datetime.fromisoformat(date_depuis)
                queryset = queryset.filter(date_creation__gte=date_depuis)
            except ValueError:
                pass
        
        serializer = PaiementDetailAdminSerializer(queryset, many=True)
        return Response(serializer.data)
    
    @action(detail=False, methods=['get'], url_path='paiements/statistiques')
    def statistiques_paiements(self, request):
        """Statistiques des paiements (revenus, commissions, etc)"""
        date_depuis = request.query_params.get('date_depuis')
        
        queryset = Paiement.objects.filter(statut__in=['CONFIRME', 'PAYEE'])
        
        if date_depuis:
            try:
                date_depuis = timezone.datetime.fromisoformat(date_depuis)
                queryset = queryset.filter(date_creation__gte=date_depuis)
            except ValueError:
                pass
        
        total_revenus = queryset.aggregate(Sum('montant'))['montant__sum'] or 0
        commission_kovoit = float(total_revenus) * 0.10
        montant_conducteurs = float(total_revenus) - commission_kovoit
        
        nombre_transactions = queryset.count()
        montant_moyen = float(total_revenus) / nombre_transactions if nombre_transactions > 0 else 0
        
        return Response({
            'periode_depuis': date_depuis,
            'total_revenus': float(total_revenus),
            'commission_kovoit_10percent': float(commission_kovoit),
            'montant_aux_conducteurs': float(montant_conducteurs),
            'nombre_transactions': nombre_transactions,
            'montant_moyen_transaction': montant_moyen,
            'repartition_par_moyen': self._repartition_paiements(queryset)
        })
    
    def _repartition_paiements(self, queryset):
        """Répartition des paiements par moyen"""
        return list(queryset.values('moyen_paiement').annotate(
            count=Count('id'),
            total=Sum('montant')
        ))
    
    # ========== PLAINTES ==========
    
    @action(detail=False, methods=['get'], url_path='plaintes')
    def lister_plaintes(self, request):
        """Lister les plaintes avec filtrage par statut"""
        statut = request.query_params.get('statut')
        type_plainte = request.query_params.get('type')
        
        queryset = Plainte.objects.all().select_related(
            'signalataire', 'utilisateur_signale', 'admin_assigne'
        ).order_by('-date_creation')
        
        if statut:
            queryset = queryset.filter(statut=statut)
        
        if type_plainte:
            queryset = queryset.filter(type_plainte=type_plainte)
        
        serializer = PlainteSerializer(queryset, many=True)
        return Response(serializer.data)
    
    @action(detail=False, methods=['post'], url_path=r'plaintes/(?P<plainte_id>[\w-]+)/assigner')
    def assigner_plainte(self, request, plainte_id=None):
        """Assigner une plainte à un admin"""
        try:
            plainte = Plainte.objects.get(pk=plainte_id)
            
            plainte.admin_assigne = request.user
            plainte.statut = 'en_cours'
            plainte.save()
            
            return Response({
                'message': 'Plainte assignée à cet administrateur',
                'plainte': PlainteSerializer(plainte).data
            }, status=status.HTTP_200_OK)
            
        except Plainte.DoesNotExist:
            return Response(
                {'error': 'Plainte non trouvée'},
                status=status.HTTP_404_NOT_FOUND
            )
    
    @action(detail=False, methods=['post'], url_path=r'plaintes/(?P<plainte_id>[\w-]+)/resoudre')
    def resoudre_plainte(self, request, plainte_id=None):
        """Marquer une plainte comme résolue"""
        try:
            plainte = Plainte.objects.get(pk=plainte_id)
            
            note_admin = request.data.get('note_admin', '')
            
            plainte.statut = 'resolue'
            plainte.note_admin = note_admin
            plainte.date_resolution = timezone.now()
            plainte.save()
            
            return Response({
                'message': 'Plainte marquée comme résolue',
                'plainte': PlainteSerializer(plainte).data
            }, status=status.HTTP_200_OK)
            
        except Plainte.DoesNotExist:
            return Response(
                {'error': 'Plainte non trouvée'},
                status=status.HTTP_404_NOT_FOUND
            )
    
    # ========== STATISTIQUES ==========
    
    @action(detail=False, methods=['get'], url_path='statistiques')
    def statistiques_globales(self, request):
        """Statistiques globales de la plateforme"""
        
        # Utilisateurs
        nombre_utilisateurs_total = Utilisateur.objects.count()
        nombre_conducteurs = Utilisateur.objects.filter(role='conducteur').count()
        nombre_passagers = Utilisateur.objects.filter(role='passager').count()
        nombre_admins = Utilisateur.objects.filter(role='admin').count()
        
        # Trajets
        nombre_trajets_total = Trajet.objects.count()
        nombre_trajets_ouverts = Trajet.objects.filter(statut='ouvert').count()
        nombre_trajets_termines = Trajet.objects.filter(statut='termine').count()
        nombre_trajets_annules = Trajet.objects.filter(statut='annule').count()
        
        # Réservations
        nombre_reservations_total = Reservation.objects.count()
        nombre_reservations_confirmees = Reservation.objects.filter(statut='confirmee').count()
        nombre_reservations_terminees = Reservation.objects.filter(statut='terminee').count()
        
        # Paiements
        nombre_paiements_total = Paiement.objects.count()
        nombre_paiements_confirmes = Paiement.objects.filter(
            statut__in=['CONFIRME', 'PAYEE']
        ).count()
        
        # Revenus
        revenu_total_paiements = Paiement.objects.filter(
            statut__in=['CONFIRME', 'PAYEE']
        ).aggregate(Sum('montant'))['montant__sum'] or 0
        
        revenu_total_kovoit = float(revenu_total_paiements) * 0.10
        revenu_total_conducteurs = float(revenu_total_paiements) * 0.90
        
        # Évaluations
        nombre_evaluations = Evaluation.objects.count()
        
        # Notes moyennes
        note_moyenne_conducteurs = Utilisateur.objects.filter(
            role='conducteur'
        ).aggregate(Avg('note'))['note__avg'] or 0
        
        note_moyenne_passagers = Utilisateur.objects.filter(
            role='passager'
        ).aggregate(Avg('note'))['note__avg'] or 0
        
        # Plaintes
        nombre_plaintes = Plainte.objects.count()
        nombre_plaintes_en_attente = Plainte.objects.filter(statut='en_attente').count()
        nombre_plaintes_resolues = Plainte.objects.filter(statut='resolue').count()
        
        data = {
            'nombre_utilisateurs_total': nombre_utilisateurs_total,
            'nombre_conducteurs': nombre_conducteurs,
            'nombre_passagers': nombre_passagers,
            'nombre_admins': nombre_admins,
            
            'nombre_trajets_total': nombre_trajets_total,
            'nombre_trajets_ouverts': nombre_trajets_ouverts,
            'nombre_trajets_termines': nombre_trajets_termines,
            'nombre_trajets_annules': nombre_trajets_annules,
            
            'nombre_reservations_total': nombre_reservations_total,
            'nombre_reservations_confirmees': nombre_reservations_confirmees,
            'nombre_reservations_terminees': nombre_reservations_terminees,
            
            'nombre_paiements_total': nombre_paiements_total,
            'nombre_paiements_confirmes': nombre_paiements_confirmes,
            
            'revenu_total_kovoit': float(revenu_total_kovoit),
            'revenu_total_conducteurs': float(revenu_total_conducteurs),
            
            'nombre_evaluations': nombre_evaluations,
            'note_moyenne_conducteurs': float(note_moyenne_conducteurs),
            'note_moyenne_passagers': float(note_moyenne_passagers),
            
            'nombre_plaintes': nombre_plaintes,
            'nombre_plaintes_en_attente': nombre_plaintes_en_attente,
            'nombre_plaintes_resolues': nombre_plaintes_resolues,
        }
        
        serializer = StatistiquesGlobalesSerializer(data)
        return Response(serializer.data)
