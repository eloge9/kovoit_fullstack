#!/usr/bin/env bash
# Script de build exécuté par Render avant le démarrage

set -o errexit   # Arrêter si une commande échoue

pip install --upgrade pip
pip install -r requirements.txt

python manage.py collectstatic --noinput
python manage.py migrate
python manage.py loaddata users_export.json
