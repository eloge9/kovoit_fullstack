from django.apps import AppConfig


class PaiementsConfig(AppConfig):
    name = 'apps.paiements'
    
    def ready(self):
        """Charger les signaux quand l'app est prête"""
        from . import signals  # noqa
