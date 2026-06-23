"""
Migration PayPlus Africa : renomme le code opérateur TMONEY → YAS
dans la colonne moyen_paiement de la table Paiement.

Aucun changement de schéma n'est nécessaire (CharField sans contrainte DB).
Uniquement une migration de données.
"""
from django.db import migrations


def tmoney_to_yas(apps, schema_editor):
    Paiement = apps.get_model('modeles', 'Paiement')
    updated = Paiement.objects.filter(moyen_paiement='TMONEY').update(moyen_paiement='YAS')
    if updated:
        print(f'  PayPlus migration: {updated} paiement(s) TMONEY → YAS')


def yas_to_tmoney(apps, schema_editor):
    """Rollback : YAS → TMONEY"""
    Paiement = apps.get_model('modeles', 'Paiement')
    Paiement.objects.filter(moyen_paiement='YAS').update(moyen_paiement='TMONEY')


class Migration(migrations.Migration):

    dependencies = [
        ('modeles', '0027_passwordresetcode'),
    ]

    operations = [
        migrations.RunPython(tmoney_to_yas, reverse_code=yas_to_tmoney),
    ]
