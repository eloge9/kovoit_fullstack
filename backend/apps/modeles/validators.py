"""Validateurs personnalisés pour les modèles"""
import io

from django.core.exceptions import ValidationError
from django.utils.translation import gettext_lazy as _
from PIL import Image


# ── Validateurs numériques ────────────────────────────────────────────────────

def validate_positive_number(value):
    if value <= 0:
        raise ValidationError(
            _("Cette valeur doit être positive (> 0)."),
            code='not_positive',
        )


def validate_rating(value):
    if not (1 <= value <= 5):
        raise ValidationError(
            _("La note doit être entre 1 et 5."),
            code='invalid_rating',
        )


def validate_gps_coordinate(value):
    if value is None:
        return
    if not (-180 <= value <= 180):
        raise ValidationError(
            _("Coordonnée GPS invalide (doit être entre -180 et 180)."),
            code='invalid_gps',
        )


def validate_gps_latitude(value):
    if value is None:
        return
    if not (-90 <= value <= 90):
        raise ValidationError(
            _("Latitude invalide (doit être entre -90 et 90)."),
            code='invalid_latitude',
        )


# ── Validateurs fichiers image ────────────────────────────────────────────────

_FORMATS_AUTORISES = {'JPEG', 'PNG', 'WEBP'}
_TAILLE_MAX_PROFIL_OCTETS  = 2 * 1024 * 1024   # 2 Mo
_TAILLE_MAX_DOCUMENT_OCTETS = 5 * 1024 * 1024  # 5 Mo


def _valider_image(fichier, taille_max_octets):
    """
    Logique commune de validation :
      1. Vérifie la taille (contre les attaques par upload massif).
      2. Ouvre le fichier avec Pillow sur le contenu brut (pas sur l'extension)
         pour résister aux fichiers malveillants renommés .jpg.
      3. Restreint les formats à JPEG, PNG et WEBP.
      4. Appelle image.verify() pour détecter les fichiers corrompus / tronqués.
    """
    if fichier.size > taille_max_octets:
        mo = taille_max_octets // (1024 * 1024)
        raise ValidationError(
            _(f"Fichier trop volumineux (max {mo} Mo)."),
            code='taille_excessive',
        )

    try:
        fichier.seek(0)
        contenu = fichier.read()
        fichier.seek(0)

        img = Image.open(io.BytesIO(contenu))
        fmt = img.format  # Lire le format AVANT verify() qui invalide l'objet
        img.verify()      # Détecte les fichiers tronqués ou corrompus

        if fmt not in _FORMATS_AUTORISES:
            raise ValidationError(
                _(f"Format '{fmt}' non autorisé. Formats acceptés : JPEG, PNG, WEBP."),
                code='format_invalide',
            )

    except ValidationError:
        raise
    except Exception:
        raise ValidationError(
            _("Le fichier n'est pas une image valide ou est corrompu."),
            code='fichier_invalide',
        )


def valider_image_profil(fichier):
    """Validateur pour les photos de profil (max 2 Mo, JPEG/PNG/WEBP)."""
    _valider_image(fichier, _TAILLE_MAX_PROFIL_OCTETS)


def valider_image_document(fichier):
    """Validateur pour les documents officiels (max 5 Mo, JPEG/PNG/WEBP)."""
    _valider_image(fichier, _TAILLE_MAX_DOCUMENT_OCTETS)
