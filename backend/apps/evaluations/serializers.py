from rest_framework import serializers
from ..modeles.models import Evaluation, Trajet, Utilisateur

class EvaluationSerializer(serializers.ModelSerializer):
    auteur_nom = serializers.SerializerMethodField()
    cible_nom = serializers.SerializerMethodField()
    trajet_info = serializers.SerializerMethodField()
    
    class Meta:
        model = Evaluation
        fields = ['id', 'trajet', 'auteur', 'cible', 'note', 'commentaire', 
                 'date_evaluation', 'auteur_nom', 'cible_nom', 'trajet_info']
        read_only_fields = ['date_evaluation']
    
    def get_auteur_nom(self, obj):
        return f"{obj.auteur.first_name} {obj.auteur.last_name}".strip() or obj.auteur.username
    
    def get_cible_nom(self, obj):
        return f"{obj.cible.first_name} {obj.cible.last_name}".strip() or obj.cible.username
    
    def get_trajet_info(self, obj):
        return f"{obj.trajet.depart} → {obj.trajet.destination}"

class EvaluationCreateSerializer(serializers.Serializer):
    trajet_id = serializers.UUIDField()
    cible_id = serializers.UUIDField()
    note = serializers.IntegerField(min_value=1, max_value=5)
    commentaire = serializers.CharField(required=False, allow_blank=True)
    ponctualite = serializers.IntegerField(min_value=1, max_value=5, required=False)
    conduite = serializers.IntegerField(min_value=1, max_value=5, required=False)
    proprete = serializers.IntegerField(min_value=1, max_value=5, required=False)

class TrajetTermineSerializer(serializers.Serializer):
    trajet_id = serializers.UUIDField()

class TrajetAEvaluerSerializer(serializers.ModelSerializer):
    conducteur_nom = serializers.SerializerMethodField()
    
    class Meta:
        model = Trajet
        fields = ['id', 'conducteur', 'depart', 'destination', 'date_heure_depart', 'conducteur_nom']
    
    def get_conducteur_nom(self, obj):
        return f"{obj.conducteur.first_name} {obj.conducteur.last_name}".strip() or obj.conducteur.username
