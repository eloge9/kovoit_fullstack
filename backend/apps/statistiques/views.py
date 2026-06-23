from rest_framework import status, permissions
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from rest_framework.views import APIView
from django.db.models import Sum, Count, Avg, Q, F, FloatField
from django.db.models.functions import Cast
from django.utils import timezone
from datetime import datetime, date, timedelta
from calendar import monthrange
from decimal import Decimal

from .serializers import (
    StatistiqueEconomieSerializer, RevenuMensuelSerializer, 
    EconomieMensuelleSerializer, StatistiqueConducteurSerializer,
    StatistiquePassagerSerializer, ResumeEconomieSerializer
)
from apps.modeles.models import (
    StatistiqueEconomie, RevenuMensuel, EconomieMensuelle,
    Utilisateur, Trajet, Paiement, Reservation
)


class StatistiqueConducteurView(APIView):
    """API pour les statistiques économiques d'un conducteur"""
    permission_classes = [permissions.IsAuthenticated]
    
    def get(self, request, conducteur_id=None):
        try:
            # Si conducteur_id n'est pas fourni, utiliser l'utilisateur connecté
            if conducteur_id is None:
                conducteur = request.user
            else:
                conducteur = Utilisateur.objects.get(id=conducteur_id, role='conducteur')
            
            # Récupérer les paramètres de période
            periode = request.GET.get('periode', 'mois')  # mois, trimestre, annee
            annee = int(request.GET.get('annee', timezone.now().year))
            
            # Calculer les statistiques
            stats = self.calculer_statistiques_conducteur(conducteur, periode, annee)
            
            serializer = StatistiqueConducteurSerializer(stats)
            return Response(serializer.data)
            
        except Utilisateur.DoesNotExist:
            return Response(
                {'error': 'Conducteur non trouvé'}, 
                status=status.HTTP_404_NOT_FOUND
            )
        except Exception as e:
            return Response(
                {'error': str(e)}, 
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
    
    def calculer_statistiques_conducteur(self, conducteur, periode, annee):
        """Calculer les statistiques complètes du conducteur"""
        now = timezone.now()
        
        # Définir la période de calcul
        if periode == 'mois':
            debut = date(annee, now.month, 1)
            fin = date(annee, now.month, monthrange(annee, now.month)[1])
        elif periode == 'trimestre':
            trimestre = (now.month - 1) // 3 + 1
            mois_debut = (trimestre - 1) * 3 + 1
            mois_fin = trimestre * 3
            debut = date(annee, mois_debut, 1)
            fin = date(annee, mois_fin, monthrange(annee, mois_fin)[1])
        else:  # annee
            debut = date(annee, 1, 1)
            fin = date(annee, 12, 31)
        
        # Calculer les revenus depuis les paiements
        # CONFIRME (espèces) → date_confirmation ; PAYEE (Mobile Money PayPlus) → date_payement
        paiements = Paiement.objects.filter(
            conducteur=conducteur,
            statut__in=[Paiement.Statut.CONFIRME, Paiement.Statut.PAYEE],
        ).filter(
            Q(statut=Paiement.Statut.CONFIRME, date_confirmation__gte=debut, date_confirmation__lte=fin) |
            Q(statut=Paiement.Statut.PAYEE, date_payement__gte=debut, date_payement__lte=fin)
        )

        total_revenus = paiements.aggregate(
            total=Sum('montant')
        )['total'] or Decimal('0')

        # Calculer les trajets
        trajets = Trajet.objects.filter(
            conducteur=conducteur,
            date_heure_depart__gte=debut,
            date_heure_depart__lte=fin,
            statut='termine'
        )

        total_trajets = trajets.count()
        total_km = trajets.aggregate(
            total=Sum('distance_km')
        )['total'] or 0

        revenu_moyen_trajet = total_revenus / total_trajets if total_trajets > 0 else Decimal('0')

        # Évolution mensuelle
        evolution = []
        for mois in range(1, 13):
            debut_mois = date(annee, mois, 1)
            fin_mois = date(annee, mois, monthrange(annee, mois)[1])

            revenus_mois = Paiement.objects.filter(
                conducteur=conducteur,
                statut__in=[Paiement.Statut.CONFIRME, Paiement.Statut.PAYEE],
            ).filter(
                Q(statut=Paiement.Statut.CONFIRME, date_confirmation__gte=debut_mois, date_confirmation__lte=fin_mois) |
                Q(statut=Paiement.Statut.PAYEE, date_payement__gte=debut_mois, date_payement__lte=fin_mois)
            ).aggregate(total=Sum('montant'))['total'] or Decimal('0')
            
            nb_trajets_mois = trajets.filter(
                date_heure_depart__gte=debut_mois,
                date_heure_depart__lte=fin_mois
            ).count()
            
            evolution.append({
                'mois': mois,
                'mois_nom': self.get_nom_mois(mois),
                'revenus': float(revenus_mois),
                'trajets': nb_trajets_mois
            })
        
        # Meilleur mois
        meilleur_mois = max(evolution, key=lambda x: x['revenus']) if evolution else None
        
        # Dernier trajet
        dernier_trajet = trajets.order_by('-date_heure_depart').first()
        dernier_trajet_data = None
        if dernier_trajet:
            dernier_trajet_data = {
                'id': str(dernier_trajet.id),
                'depart': dernier_trajet.depart,
                'destination': dernier_trajet.destination,
                'date': dernier_trajet.date_heure_depart.strftime('%d/%m/%Y'),
                'revenu': float(dernier_trajet.cout_total or 0)
            }
        
        # Note moyenne
        note_moyenne = conducteur.evaluations_recues.aggregate(
            moyenne=Avg('note')
        )['moyenne'] or 0
        
        # Revenu mensuel moyen
        revenu_moyen_mensuel = total_revenus / 12 if periode == 'annee' else total_revenus
        
        return {
            'periode': f"{debut.strftime('%d/%m/%Y')} - {fin.strftime('%d/%m/%Y')}",
            'total_revenus': total_revenus,
            'total_trajets': total_trajets,
            'total_km': total_km,
            'revenu_moyen_trajet': revenu_moyen_trajet,
            'revenu_moyen_mensuel': revenu_moyen_mensuel,
            'meilleur_mois': meilleur_mois,
            'evolution_mensuelle': evolution,
            'dernier_trajet': dernier_trajet_data,
            'note_moyenne': note_moyenne
        }
    
    def get_nom_mois(self, mois):
        noms = ['Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
                'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre']
        return noms[mois - 1]


class StatistiquePassagerView(APIView):
    """API pour les statistiques économiques d'un passager"""
    permission_classes = [permissions.IsAuthenticated]
    
    def get(self, request, passager_id=None):
        try:
            # Si passager_id n'est pas fourni, utiliser l'utilisateur connecté
            if passager_id is None:
                passager = request.user
            else:
                passager = Utilisateur.objects.get(id=passager_id, role='passager')
            
            # Récupérer les paramètres
            periode = request.GET.get('periode', 'mois')
            annee = int(request.GET.get('annee', timezone.now().year))
            
            # Calculer les statistiques
            stats = self.calculer_statistiques_passager(passager, periode, annee)
            
            serializer = StatistiquePassagerSerializer(stats)
            return Response(serializer.data)
            
        except Utilisateur.DoesNotExist:
            return Response(
                {'error': 'Passager non trouvé'}, 
                status=status.HTTP_404_NOT_FOUND
            )
        except Exception as e:
            return Response(
                {'error': str(e)}, 
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
    
    def calculer_statistiques_passager(self, passager, periode, annee):
        """Calculer les statistiques complètes du passager"""
        now = timezone.now()
        
        # Définir la période
        if periode == 'mois':
            debut = date(annee, now.month, 1)
            fin = date(annee, now.month, monthrange(annee, now.month)[1])
        elif periode == 'trimestre':
            trimestre = (now.month - 1) // 3 + 1
            mois_debut = (trimestre - 1) * 3 + 1
            mois_fin = trimestre * 3
            debut = date(annee, mois_debut, 1)
            fin = date(annee, mois_fin, monthrange(annee, mois_fin)[1])
        else:  # annee
            debut = date(annee, 1, 1)
            fin = date(annee, 12, 31)
        
        # Récupérer les réservations confirmées
        reservations = Reservation.objects.filter(
            passager=passager,
            statut='confirmee',
            date_reservation__gte=debut,
            date_reservation__lte=fin
        )
        
        total_reservations = reservations.count()
        
        # Calculer les économies (estimation: 30% d'économie par rapport au taxi)
        cout_covoiturage = reservations.aggregate(
            total=Sum(F('trajet__prix_par_place') * F('places_reservees'))
        )['total'] or Decimal('0')
        
        # Estimer le coût du transport individuel (taxi ~ 2.5x le prix covoiturage)
        cout_transport_individuel = cout_covoiturage * Decimal('2.5')
        total_economies = cout_transport_individuel - cout_covoiturage
        
        economie_moyenne_reservation = total_economies / total_reservations if total_reservations > 0 else Decimal('0')
        
        # Évolution mensuelle
        evolution = []
        for mois in range(1, 13):
            debut_mois = date(annee, mois, 1)
            fin_mois = date(annee, mois, monthrange(annee, mois)[1])
            
            res_mois = reservations.filter(
                date_reservation__gte=debut_mois,
                date_reservation__lte=fin_mois
            )
            
            nb_res_mois = res_mois.count()
            cout_covoit_mois = res_mois.aggregate(
                total=Sum(F('trajet__prix_par_place') * F('places_reservees'))
            )['total'] or Decimal('0')
            
            cout_transit_mois = cout_covoit_mois * Decimal('2.5')
            econ_mois = cout_transit_mois - cout_covoit_mois
            
            evolution.append({
                'mois': mois,
                'mois_nom': self.get_nom_mois(mois),
                'economies': float(econ_mois),
                'reservations': nb_res_mois
            })
        
        # Meilleur mois
        meilleur_mois = max(evolution, key=lambda x: x['economies']) if evolution else None
        
        # Dernière réservation
        derniere_reservation = reservations.order_by('-date_reservation').first()
        derniere_res_data = None
        if derniere_reservation:
            derniere_res_data = {
                'id': str(derniere_reservation.id),
                'trajet': f"{derniere_reservation.trajet.depart} → {derniere_reservation.trajet.destination}",
                'date': derniere_reservation.date_reservation.strftime('%d/%m/%Y'),
                'economie': float((derniere_reservation.trajet.prix_par_place * derniere_reservation.places_reservees) * Decimal('1.5'))  # Économie estimée
            }
        
        # CO2 évité (estimation: 0.12 kg CO2 par km économisé)
        co2_total_evite = total_reservations * 5 * 0.12  # Estimation 5km par réservation
        
        # Économie mensuelle moyenne
        economie_mensuelle_moyenne = total_economies / 12 if periode == 'annee' else total_economies
        
        return {
            'periode': f"{debut.strftime('%d/%m/%Y')} - {fin.strftime('%d/%m/%Y')}",
            'total_economies': total_economies,
            'total_reservations': total_reservations,
            'economie_moyenne_reservation': economie_moyenne_reservation,
            'economie_mensuelle_moyenne': economie_mensuelle_moyenne,
            'meilleur_mois': meilleur_mois,
            'evolution_mensuelle': evolution,
            'derniere_reservation': derniere_res_data,
            'co2_total_evite': co2_total_evite
        }
    
    def get_nom_mois(self, mois):
        noms = ['Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
                'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre']
        return noms[mois - 1]


class ResumeEconomieView(APIView):
    """API pour le résumé économique rapide tableau de bord"""
    permission_classes = [permissions.IsAuthenticated]
    
    def get(self, request):
        try:
            utilisateur = request.user
            now = timezone.now()
            
            # Calculer pour le mois en cours
            debut_mois = date(now.year, now.month, 1)
            fin_mois = date(now.year, now.month, monthrange(now.year, now.month)[1])
            
            # Calculer pour le mois précédent
            if now.month == 1:
                debut_precedent = date(now.year - 1, 12, 1)
                fin_precedent = date(now.year - 1, 12, 31)
            else:
                debut_precedent = date(now.year, now.month - 1, 1)
                fin_precedent = date(now.year, now.month - 1, monthrange(now.year, now.month - 1)[1])
            
            if utilisateur.role == 'conducteur':
                # Statistiques conducteur
                revenus_mois = Paiement.objects.filter(
                    conducteur=utilisateur,
                    statut__in=[Paiement.Statut.CONFIRME, Paiement.Statut.PAYEE],
                ).filter(
                    Q(statut=Paiement.Statut.CONFIRME, date_confirmation__gte=debut_mois, date_confirmation__lte=fin_mois) |
                    Q(statut=Paiement.Statut.PAYEE, date_payement__gte=debut_mois, date_payement__lte=fin_mois)
                ).aggregate(total=Sum('montant'))['total'] or Decimal('0')

                revenus_precedent = Paiement.objects.filter(
                    conducteur=utilisateur,
                    statut__in=[Paiement.Statut.CONFIRME, Paiement.Statut.PAYEE],
                ).filter(
                    Q(statut=Paiement.Statut.CONFIRME, date_confirmation__gte=debut_precedent, date_confirmation__lte=fin_precedent) |
                    Q(statut=Paiement.Statut.PAYEE, date_payement__gte=debut_precedent, date_payement__lte=fin_precedent)
                ).aggregate(total=Sum('montant'))['total'] or Decimal('0')
                
                nb_trajets = Trajet.objects.filter(
                    conducteur=utilisateur,
                    statut='termine',
                    date_heure_depart__gte=debut_mois,
                    date_heure_depart__lte=fin_mois
                ).count()
                
                evolution = ((revenus_mois - revenus_precedent) / revenus_precedent * 100) if revenus_precedent > 0 else 0
                moyenne = revenus_mois / nb_trajets if nb_trajets > 0 else Decimal('0')
                
                data = {
                    'type_utilisateur': 'conducteur',
                    'chiffre_principal': revenus_mois,
                    'libelle_chiffre': 'Revenus ce mois',
                    'evolution_mois_precedent': float(evolution),
                    'nombre_operations': nb_trajets,
                    'moyenne_operation': moyenne
                }
                
            else:  # passager
                # Statistiques passager
                reservations = Reservation.objects.filter(
                    passager=utilisateur,
                    statut='confirmee',
                    date_reservation__gte=debut_mois,
                    date_reservation__lte=fin_mois
                )
                
                cout_covoiturage = reservations.aggregate(
                    total=Sum(F('trajet__prix_par_place') * F('places_reservees'))
                )['total'] or Decimal('0')
                
                reservations_precedent = Reservation.objects.filter(
                    passager=utilisateur,
                    statut='confirmee',
                    date_reservation__gte=debut_precedent,
                    date_reservation__lte=fin_precedent
                )
                
                cout_precedent = reservations_precedent.aggregate(
                    total=Sum(F('trajet__prix_par_place') * F('places_reservees'))
                )['total'] or Decimal('0')
                
                # Calculer les économies
                economies_mois = cout_covoiturage * Decimal('1.5')  # 60% d'économie
                economies_precedent = cout_precedent * Decimal('1.5')
                
                nb_reservations = reservations.count()
                
                evolution = ((economies_mois - economies_precedent) / economies_precedent * 100) if economies_precedent > 0 else 0
                moyenne = economies_mois / nb_reservations if nb_reservations > 0 else Decimal('0')
                
                data = {
                    'type_utilisateur': 'passager',
                    'chiffre_principal': economies_mois,
                    'libelle_chiffre': 'Économies ce mois',
                    'evolution_mois_precedent': float(evolution),
                    'nombre_operations': nb_reservations,
                    'moyenne_operation': moyenne
                }
            
            serializer = ResumeEconomieSerializer(data)
            return Response(serializer.data)
            
        except Exception as e:
            return Response(
                {'error': str(e)}, 
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


@api_view(['GET'])
@permission_classes([permissions.IsAuthenticated])
def statistiques_globales(request):
    """API pour les statistiques globales de la plateforme"""
    try:
        # Statistiques globales
        total_utilisateurs = Utilisateur.objects.count()
        total_conducteurs = Utilisateur.objects.filter(role='conducteur').count()
        total_passagers = Utilisateur.objects.filter(role='passager').count()
        
        total_trajets = Trajet.objects.count()
        trajets_ce_mois = Trajet.objects.filter(
            date_heure_depart__gte=date(timezone.now().year, timezone.now().month, 1)
        ).count()
        
        total_reservations = Reservation.objects.count()
        reservations_ce_mois = Reservation.objects.filter(
            date_reservation__gte=date(timezone.now().year, timezone.now().month, 1)
        ).count()
        
        total_revenus = Paiement.objects.filter(
            statut='CONFIRME'
        ).aggregate(total=Sum('montant'))['total'] or Decimal('0')
        
        revenus_ce_mois = Paiement.objects.filter(
            statut='CONFIRME',
            date_confirmation__gte=date(timezone.now().year, timezone.now().month, 1)
        ).aggregate(total=Sum('montant'))['total'] or Decimal('0')
        
        data = {
            'utilisateurs': {
                'total': total_utilisateurs,
                'conducteurs': total_conducteurs,
                'passagers': total_passagers
            },
            'trajets': {
                'total': total_trajets,
                'ce_mois': trajets_ce_mois
            },
            'reservations': {
                'total': total_reservations,
                'ce_mois': reservations_ce_mois
            },
            'revenus': {
                'total': float(total_revenus),
                'ce_mois': float(revenus_ce_mois)
            }
        }
        
        return Response(data)
        
    except Exception as e:
        return Response(
            {'error': str(e)}, 
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )
