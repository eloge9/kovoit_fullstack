from rest_framework import serializers
from django.db.models import Sum, Count, Avg, Q
from datetime import datetime, date
from calendar import monthrange
from apps.modeles.models import (
    StatistiqueEconomie, RevenuMensuel, EconomieMensuelle,
    Utilisateur, Trajet, Paiement, Reservation
)


class StatistiqueEconomieSerializer(serializers.ModelSerializer):
    """Serializer pour les statistiques économiques générales"""
    
    class Meta:
        model = StatistiqueEconomie
        fields = [
            'id', 'utilisateur', 'periode_debut', 'periode_fin',
            'total_revenus', 'total_trajets', 'total_km', 'moyenne_par_trajet',
            'total_economies', 'total_reservations', 'moyenne_par_reservation',
            'economie_carburant', 'co2_evite', 'created_at', 'updated_at'
        ]


class RevenuMensuelSerializer(serializers.ModelSerializer):
    """Serializer pour les revenus mensuels des conducteurs"""
    mois_nom = serializers.SerializerMethodField()
    
    class Meta:
        model = RevenuMensuel
        fields = [
            'id', 'conducteur', 'annee', 'mois', 'mois_nom',
            'revenu_total', 'nombre_trajets', 'km_parcourus', 
            'revenu_moyen_trajet', 'created_at', 'updated_at'
        ]
    
    def get_mois_nom(self, obj):
        noms_mois = [
            'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
            'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
        ]
        return noms_mois[obj.mois - 1]


class EconomieMensuelleSerializer(serializers.ModelSerializer):
    """Serializer pour les économies mensuelles des passagers"""
    mois_nom = serializers.SerializerMethodField()
    pourcentage_economie = serializers.SerializerMethodField()
    
    class Meta:
        model = EconomieMensuelle
        fields = [
            'id', 'passager', 'annee', 'mois', 'mois_nom',
            'economie_totale', 'nombre_reservations', 'economie_moyenne_reservation',
            'cout_transport_individuel', 'cout_covoiturage', 'pourcentage_economie',
            'created_at', 'updated_at'
        ]
    
    def get_mois_nom(self, obj):
        noms_mois = [
            'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
            'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
        ]
        return noms_mois[obj.mois - 1]
    
    def get_pourcentage_economie(self, obj):
        if obj.cout_transport_individuel > 0:
            return round((obj.economie_totale / obj.cout_transport_individuel) * 100, 2)
        return 0


class StatistiqueConducteurSerializer(serializers.Serializer):
    """Serializer pour les statistiques complètes d'un conducteur"""
    periode = serializers.CharField()
    total_revenus = serializers.DecimalField(max_digits=12, decimal_places=2)
    total_trajets = serializers.IntegerField()
    total_km = serializers.FloatField()
    revenu_moyen_trajet = serializers.DecimalField(max_digits=10, decimal_places=2)
    revenu_moyen_mensuel = serializers.DecimalField(max_digits=10, decimal_places=2)
    meilleur_mois = serializers.DictField(allow_null=True)
    evolution_mensuelle = serializers.ListField()
    dernier_trajet = serializers.DictField(allow_null=True)
    note_moyenne = serializers.FloatField()


class StatistiquePassagerSerializer(serializers.Serializer):
    """Serializer pour les statistiques complètes d'un passager"""
    periode = serializers.CharField()
    total_economies = serializers.DecimalField(max_digits=12, decimal_places=2)
    total_reservations = serializers.IntegerField()
    economie_moyenne_reservation = serializers.DecimalField(max_digits=10, decimal_places=2)
    economie_mensuelle_moyenne = serializers.DecimalField(max_digits=10, decimal_places=2)
    meilleur_mois = serializers.DictField(allow_null=True)
    evolution_mensuelle = serializers.ListField()
    derniere_reservation = serializers.DictField(allow_null=True)
    co2_total_evite = serializers.FloatField()


class ResumeEconomieSerializer(serializers.Serializer):
    """Serializer pour le résumé économique rapide"""
    type_utilisateur = serializers.CharField()
    chiffre_principal = serializers.DecimalField(max_digits=12, decimal_places=2)
    libelle_chiffre = serializers.CharField()
    evolution_mois_precedent = serializers.FloatField()
    nombre_operations = serializers.IntegerField()
    moyenne_operation = serializers.DecimalField(max_digits=10, decimal_places=2)
