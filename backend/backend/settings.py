from pathlib import Path
import os
from dotenv import load_dotenv
from datetime import timedelta

load_dotenv()

# Build paths inside the project like this: BASE_DIR / 'subdir'.
BASE_DIR = Path(__file__).resolve().parent.parent

# SECURITY WARNING: keep the secret key used in production secret!
SECRET_KEY = os.getenv('SECRET_KEY')
if not SECRET_KEY:
    raise ValueError('SECRET_KEY environment variable must be set')

# SECURITY WARNING: don't run with debug turned on in production!
DEBUG = os.getenv('DEBUG', 'False').lower() == 'true'

if DEBUG:
    ALLOWED_HOSTS = ['*']
else:
    ALLOWED_HOSTS = os.getenv('ALLOWED_HOSTS', 'localhost,127.0.0.1').split(',')
    
AUTH_USER_MODEL = 'modeles.Utilisateur'

# Application definition
INSTALLED_APPS = [
    'daphne',                          # doit être en PREMIER (active ASGI)
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'django_extensions',
    'channels',

    # mes application
    'apps.utilisateurs',
    'apps.trajets',
    'apps.reservations',
    'apps.paiements',
    'apps.evaluations',
    'apps.messagerie',
    'apps.statistiques',
    'apps.modeles',
    'apps.verification',

    # DRF et CORS
    'rest_framework',
    'corsheaders',

    # JWT
    "rest_framework_simplejwt",
    'rest_framework_simplejwt.token_blacklist', # Nécessaire pour la rotation des tokens
]

MIDDLEWARE = [
    'corsheaders.middleware.CorsMiddleware',
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'backend.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'backend.wsgi.application'

# Database
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': os.getenv('DB_NAME'),
        'USER': os.getenv('DB_USER'),
        'PASSWORD': os.getenv('DB_PASSWORD'),
        'HOST': os.getenv('DB_HOST'),
        'PORT': os.getenv('DB_PORT'),
    }
}

# Password validation
AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator'},
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},
]

# Internationalization
LANGUAGE_CODE = 'fr-fr'
TIME_ZONE = 'Africa/Abidjan'
USE_I18N = True
USE_TZ = True

# ── Static & Media files ──────────────────────────────────────────────────
STATIC_URL = 'static/'
# CORRECTION AUDIT : Ajout de STATIC_ROOT pour la commande collectstatic en production
STATIC_ROOT = os.path.join(BASE_DIR, 'staticfiles') 

MEDIA_URL = '/media/'
MEDIA_ROOT = os.path.join(BASE_DIR, 'media')

# ── Django REST Framework ─────────────────────────────────────────────────
REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': (
        'rest_framework_simplejwt.authentication.JWTAuthentication',
    ),
    'DEFAULT_PAGINATION_CLASS': 'rest_framework.pagination.PageNumberPagination',
    'PAGE_SIZE': 20,
    # Throttling : protection anti-brute-force sans dépendance externe
    'DEFAULT_THROTTLE_CLASSES': [
        'rest_framework.throttling.AnonRateThrottle',
        'rest_framework.throttling.UserRateThrottle',
    ],
    'DEFAULT_THROTTLE_RATES': {
        'anon':        '30/minute',   # Visiteurs non connectés
        'user':        '200/minute',  # Utilisateurs connectés
        'auth':        '30/minute' if DEBUG else '5/minute',  # Plus souple en dev
        'signalement': '10/hour',     # Signalement d'évaluations abusives
        'sos':         '5/hour',      # Bouton SOS (anti-spam)
    },
}

# ── JWT Configuration ─────────────────────────────────────────────────────
SIMPLE_JWT = {
    'ACCESS_TOKEN_LIFETIME': timedelta(minutes=15), # Réduit de 60 à 15 min pour la sécurité
    'REFRESH_TOKEN_LIFETIME': timedelta(days=7),
    'ROTATE_REFRESH_TOKENS': True,       # CORRECTION AUDIT : Rotation activée
    'BLACKLIST_AFTER_ROTATION': True,    # CORRECTION AUDIT : Blackliste l'ancien token
    'AUTH_HEADER_TYPES': ('Bearer',),
}

# ── Django Channels (WebSockets GPS temps réel) ───────────────────────────
ASGI_APPLICATION = 'backend.asgi.application'

_channel_layer_type = os.getenv('CHANNEL_LAYER_TYPE', 'redis' if not DEBUG else 'inmemory')
if _channel_layer_type == 'inmemory':
    CHANNEL_LAYERS = {
        'default': {
            'BACKEND': 'channels.layers.InMemoryChannelLayer',
        },
    }
else:
    CHANNEL_LAYERS = {
        'default': {
            'BACKEND': 'channels_redis.core.RedisChannelLayer',
            'CONFIG': {
                "hosts": [(os.getenv('REDIS_HOST', '127.0.0.1'), int(os.getenv('REDIS_PORT', 6379)))],
            },
        },
    }

# ── CORS & Security ───────────────────────────────────────────────────────
CORS_ALLOWED_ORIGINS = os.getenv('CORS_ALLOWED_ORIGINS', 'http://localhost:3000').split(',')
ADMIN_FRONTEND_URL = os.getenv("ADMIN_FRONTEND_URL", "http://localhost:3000/admin/dashboard")

CORS_ALLOW_HEADERS = [
    "accept", "authorization", "content-type", "x-csrftoken",
]
CORS_ALLOW_CREDENTIALS = True
CORS_EXPOSE_HEADERS = ['Content-Type', 'X-Total-Count']
CORS_ALLOW_METHODS = ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"]

# ── PayPlus Africa ────────────────────────────────────────────────────────────
PAYPLUS_API_KEY        = os.getenv('PAYPLUS_API_KEY', '')   # clé courte VKWEY...
PAYPLUS_TOKEN          = os.getenv('PAYPLUS_TOKEN', '')     # JWT eyJ... pour Authorization
PAYPLUS_MERCHANT       = os.getenv('PAYPLUS_MERCHANT', '')
PAYPLUS_WEBHOOK_SECRET = os.getenv('PAYPLUS_WEBHOOK_SECRET', '')
PAYPLUS_BASE_URL       = os.getenv('PAYPLUS_BASE_URL', 'https://app.payplus.africa')
PAYPLUS_ENV            = os.getenv('PAYPLUS_ENV', 'prod')
PAYPLUS_NOTIFY_URL     = os.getenv('PAYPLUS_NOTIFY_URL', '')

# ── Africa's Talking (SMS SOS) ────────────────────────────────────────────
AFRICASTALKING_API_KEY  = os.getenv('AFRICASTALKING_API_KEY', '')
AFRICASTALKING_USERNAME = os.getenv('AFRICASTALKING_USERNAME', 'sandbox')

# ── IA / Anthropic ────────────────────────────────────────────────────────────
ANTHROPIC_API_KEY = os.getenv('ANTHROPIC_API_KEY', '')

# ── Celery ────────────────────────────────────────────────────────────────────
CELERY_BROKER_URL         = os.getenv('CELERY_BROKER_URL', 'redis://localhost:6379/1')
CELERY_RESULT_BACKEND     = os.getenv('CELERY_RESULT_BACKEND', 'redis://localhost:6379/2')
CELERY_ACCEPT_CONTENT     = ['json']
CELERY_TASK_SERIALIZER    = 'json'
CELERY_RESULT_SERIALIZER  = 'json'
CELERY_TIMEZONE           = TIME_ZONE

# Tâche cron quotidienne pour vérifier les expirations
CELERY_BEAT_SCHEDULE = {
    'check-document-expirations': {
        'task':     'apps.verification.tasks.check_document_expirations',
        'schedule': 86400,  # Toutes les 24h
    },
    'auto-process-signals': {
        'task':     'apps.verification.tasks.auto_process_signals',
        'schedule': 3600,  # Toutes les heures
    },
}

# ── Email ─────────────────────────────────────────────────────────────────────
EMAIL_BACKEND      = os.getenv('EMAIL_BACKEND', 'django.core.mail.backends.smtp.EmailBackend')
EMAIL_HOST         = os.getenv('EMAIL_HOST', 'smtp.gmail.com')
EMAIL_PORT         = int(os.getenv('EMAIL_PORT', '587'))
EMAIL_USE_TLS      = os.getenv('EMAIL_USE_TLS', 'True').lower() == 'true'
EMAIL_HOST_USER    = os.getenv('EMAIL_HOST_USER', '')
EMAIL_HOST_PASSWORD = os.getenv('EMAIL_HOST_PASSWORD', '')
DEFAULT_FROM_EMAIL = os.getenv('DEFAULT_FROM_EMAIL', 'KoVoit <noreply@kovoit.ci>')

# ── Sécurité fichiers ────────────────────────────────────────────────────────
VERIFICATION_MAX_FILE_SIZE_MB = 10
VERIFICATION_ALLOWED_TYPES    = ['image/jpeg', 'image/png', 'image/webp', 'application/pdf']

SECURE_SSL_REDIRECT = os.getenv('SECURE_SSL_REDIRECT', 'False').lower() == 'true'
SESSION_COOKIE_SECURE = os.getenv('SESSION_COOKIE_SECURE', 'False').lower() == 'true'
CSRF_COOKIE_SECURE = os.getenv('CSRF_COOKIE_SECURE', 'False').lower() == 'true'
SECURE_HSTS_SECONDS = int(os.getenv('SECURE_HSTS_SECONDS', '0'))
SECURE_HSTS_INCLUDE_SUBDOMAINS = SECURE_HSTS_SECONDS > 0
SECURE_HSTS_PRELOAD = SECURE_HSTS_SECONDS > 0
X_FRAME_OPTIONS = 'DENY'

# Note : SECURE_CONTENT_SECURITY_POLICY n'est pas un setting Django natif. 
# Si tu utilises django-csp, utilise plutôt CSP_DEFAULT_SRC, CSP_SCRIPT_SRC, etc.