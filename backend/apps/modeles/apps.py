from django.apps import AppConfig


class ModelesConfig(AppConfig):
    name = 'apps.modeles'

    def ready(self):
        import apps.modeles.signals  # noqa: F401 — enregistre les signals
