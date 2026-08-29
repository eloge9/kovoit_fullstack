"""
Source unique de vérité pour le taux de commission KoVoit.

Avant ce module, le taux (10%) était codé en dur séparément dans
apps.paiements.views, apps.trajets.tarification, apps.trajets.matching,
apps.statistiques.services et apps.utilisateurs.admin_views — alors que
SysConfig['commission_kovoit'] existe déjà et est modifiable depuis
l'admin (/utilisateurs/admin/config/commission_kovoit/update). Ce réglage
n'avait jusqu'ici aucun effet réel sur les calculs.
"""
from decimal import Decimal, InvalidOperation

from .models import SysConfig

_DEFAUT = Decimal('0.10')


def taux_commission() -> Decimal:
    """Taux de commission KoVoit sous forme décimale (ex: Decimal('0.10') pour 10%)."""
    valeur = SysConfig.get('commission_kovoit', '10')
    try:
        return Decimal(str(valeur)) / Decimal('100')
    except (InvalidOperation, TypeError):
        return _DEFAUT
