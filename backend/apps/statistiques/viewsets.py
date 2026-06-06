"""
Vues pour les statistiques économiques
"""
from rest_framework import status, permissions, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response
from django.utils import timezone
from datetime import date
from decimal import Decimal

from apps.modeles.models import Utilisateur, StatistiqueEconomie
from apps.statistiques.services import actualiser_statistiques_economie
from .serializers import StatistiqueEconomieSerializer


class StatistiqueEconomieViewSet(viewsets.ReadOnlyModelViewSet):
    """
    API pour récupérer les statistiques économiques.
    """
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = StatistiqueEconomieSerializer
    
    def get_queryset(self):
        """Retourner les statistiques de l'utilisateur connecté"""
        return StatistiqueEconomie.objects.filter(
            utilisateur=self.request.user
        ).order_by('-periode_debut')
    
    @action(detail=False, methods=['get'])
    def actuelle(self, request):
        """
        Récupère la statistique économique du mois actuel
        Recalcule automatiquement si nécessaire
        """
        try:
            # Recalculer les stats pour ce mois
            stats = actualiser_statistiques_economie(request.user)
            
            serializer = self.get_serializer(stats)
            return Response(serializer.data)
            
        except Exception as e:
            return Response(
                {'error': f'Erreur lors du calcul des statistiques: {str(e)}'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
    
    @action(detail=False, methods=['get'])
    def mois(self, request):
        """
        Récupère les stats par mois.
        Query: ?annee=2026&mois=6
        """
        try:
            annee = int(request.query_params.get('annee', timezone.now().year))
            mois = int(request.query_params.get('mois', timezone.now().month))
            
            from calendar import monthrange
            last_day = monthrange(annee, mois)[1]
            
            periode_debut = date(annee, mois, 1)
            periode_fin = date(annee, mois, last_day)
            
            # Recalculer
            stats = actualiser_statistiques_economie(
                request.user, 
                periode_debut, 
                periode_fin
            )
            
            serializer = self.get_serializer(stats)
            return Response(serializer.data)
            
        except Exception as e:
            return Response(
                {'error': f'Erreur: {str(e)}'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
    
    @action(detail=False, methods=['get'])
    def resume_conducteur(self, request):
        """
        Résumé complet des gains du conducteur (mois courant)
        """
        if request.user.role != 'conducteur':
            return Response(
                {'error': 'Vous devez être conducteur'},
                status=status.HTTP_403_FORBIDDEN
            )
        
        try:
            stats = actualiser_statistiques_economie(request.user)
            
            return Response({
                'utilisateur': request.user.username,
                'role': request.user.role,
                'total_revenus': float(stats.total_revenus or 0),
                'total_trajets': stats.total_trajets,
                'total_km': stats.total_km or 0,
                'moyenne_par_trajet': float(stats.moyenne_par_trajet or 0),
                'periode': {
                    'debut': stats.periode_debut,
                    'fin': stats.periode_fin,
                }
            })
            
        except Exception as e:
            return Response(
                {'error': str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
    
    @action(detail=False, methods=['get'])
    def resume_passager(self, request):
        """
        Résumé des économies du passager (mois courant)
        """
        if request.user.role != 'passager':
            return Response(
                {'error': 'Vous devez être passager'},
                status=status.HTTP_403_FORBIDDEN
            )
        
        try:
            stats = actualiser_statistiques_economie(request.user)
            
            return Response({
                'utilisateur': request.user.username,
                'role': request.user.role,
                'total_economies': float(stats.total_economies or 0),
                'total_reservations': stats.total_reservations,
                'moyenne_par_reservation': float(stats.moyenne_par_reservation or 0),
                'economie_carburant': float(stats.economie_carburant or 0),
                'co2_evite_kg': stats.co2_evite or 0,
                'total_km': stats.total_km or 0,
                'periode': {
                    'debut': stats.periode_debut,
                    'fin': stats.periode_fin,
                }
            })
            
        except Exception as e:
            return Response(
                {'error': str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
