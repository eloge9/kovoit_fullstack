#!/usr/bin/env python
"""Django's command-line utility for administrative tasks."""
import os
import sys


def main():
    """Run administrative tasks."""
    os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'backend.settings')
    try:
        from django.core.management import execute_from_command_line
    except ImportError as exc:
        raise ImportError(
            "Couldn't import Django. Are you sure it's installed and "
            "available on your PYTHONPATH environment variable? Did you "
            "forget to activate a virtual environment?"
        ) from exc
    execute_from_command_line(sys.argv)


if __name__ == '__main__':
    # Démarre mDNS uniquement dans le processus enfant du reloader Django
    # (RUN_MAIN='true') pour éviter un double enregistrement.
    if 'runserver' in sys.argv and os.environ.get('RUN_MAIN') == 'true':
        try:
            from mdns_service import start_mdns
            port = 8000
            for arg in sys.argv:
                if ':' in arg and arg.split(':')[-1].isdigit():
                    port = int(arg.split(':')[-1])
            start_mdns(port=port)
        except Exception as exc:
            print(f"[mDNS] Démarrage ignoré : {exc}")
    main()
