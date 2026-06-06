"""Validateurs personnalisés pour les modèles"""
from django.core.exceptions import ValidationError
from django.utils.translation import gettext_lazy as _


def validate_positive_number(value):
    """Valide qu'un nombre est strictement positif"""
    if value <= 0:
        raise ValidationError(
            _("Cette valeur doit être positive (> 0)."),
            code='not_positive',
        )


def validate_rating(value):
    """Valide qu'une note est entre 1 et 5"""
    if not (1 <= value <= 5):
        raise ValidationError(
            _("La note doit être entre 1 et 5."),
            code='invalid_rating',
        )


def validate_gps_coordinate(value):
    """Valide une coordonnée GPS"""
    if value is None:
        return
    if not (-180 <= value <= 180):
        raise ValidationError(
            _("Coordonnée GPS invalide (doit être entre -180 et 180)."),
            code='invalid_gps',
        )


def validate_gps_latitude(value):
    """Valide une latitude GPS"""
    if value is None:
        return
    if not (-90 <= value <= 90):
        raise ValidationError(
            _("Latitude invalide (doit être entre -90 et 90)."),
            code='invalid_latitude',
        )
