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
    'storages',

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
    'apps.chatbot',

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
    'whitenoise.middleware.WhiteNoiseMiddleware',
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
# Render et Supabase fournissent DATABASE_URL directement
_DATABASE_URL = os.getenv('DATABASE_URL', '')
if _DATABASE_URL:
    import dj_database_url
    DATABASES = {'default': dj_database_url.parse(_DATABASE_URL, conn_max_age=0)}
else:
    DATABASES = {
        'default': {
            'ENGINE': 'django.db.backends.postgresql',
            'NAME':     os.getenv('DB_NAME'),
            'USER':     os.getenv('DB_USER'),
            'PASSWORD': os.getenv('DB_PASSWORD'),
            'HOST':     os.getenv('DB_HOST'),
            'PORT':     os.getenv('DB_PORT'),
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
STATIC_ROOT = os.path.join(BASE_DIR, 'staticfiles')
STATICFILES_STORAGE = 'whitenoise.storage.CompressedManifestStaticFilesStorage'

# ── Stockage fichiers : Cloudflare R2 en production, local en dev ─────────
_R2_ACCOUNT_ID    = os.getenv('CF_R2_ACCOUNT_ID', '')
_R2_ACCESS_KEY    = os.getenv('CF_R2_ACCESS_KEY', '')
_R2_SECRET_KEY    = os.getenv('CF_R2_SECRET_KEY', '')
_R2_BUCKET        = os.getenv('CF_R2_BUCKET', 'kovoit-media')
_R2_PUBLIC_DOMAIN = os.getenv('CF_R2_PUBLIC_DOMAIN', '')  # ex: media.kovoit.com

if not DEBUG and _R2_ACCOUNT_ID:
    DEFAULT_FILE_STORAGE = 'storages.backends.s3boto3.S3Boto3Storage'
    AWS_ACCESS_KEY_ID     = _R2_ACCESS_KEY
    AWS_SECRET_ACCESS_KEY = _R2_SECRET_KEY
    AWS_STORAGE_BUCKET_NAME = _R2_BUCKET
    AWS_S3_ENDPOINT_URL   = f'https://{_R2_ACCOUNT_ID}.r2.cloudflarestorage.com'
    AWS_S3_CUSTOM_DOMAIN  = _R2_PUBLIC_DOMAIN or None
    AWS_DEFAULT_ACL       = None
    AWS_S3_FILE_OVERWRITE = False
    AWS_QUERYSTRING_AUTH  = False
    MEDIA_URL = f'https://{_R2_PUBLIC_DOMAIN}/' if _R2_PUBLIC_DOMAIN else f'{AWS_S3_ENDPOINT_URL}/{_R2_BUCKET}/'
    MEDIA_ROOT = ''
else:
    MEDIA_URL  = '/media/'
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
        'chatbot':     '20/minute',   # Chatbot Kovi (anti-spam)
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

# ── Chatbot Kovi — providers IA (Groq → Gemini → Claude) ─────────────────────
GROQ_API_KEY                  = os.getenv('GROQ_API_KEY', '')
GEMINI_API_KEY_CHATBOT        = os.getenv('GEMINI_API_KEY_CHATBOT', '')
CHATBOT_MAX_HISTORY_MESSAGES  = int(os.getenv('CHATBOT_MAX_HISTORY_MESSAGES', '10'))
CHATBOT_MAX_TOKENS_RESPONSE   = int(os.getenv('CHATBOT_MAX_TOKENS_RESPONSE', '500'))

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

X_FRAME_OPTIONS         = 'DENY'
SECURE_CONTENT_TYPE_NOSNIFF = True

if DEBUG:
    # Développement local : paramètres souples
    SECURE_SSL_REDIRECT            = False
    SESSION_COOKIE_SECURE          = False
    CSRF_COOKIE_SECURE             = False
    SECURE_HSTS_SECONDS            = 0
    SECURE_HSTS_INCLUDE_SUBDOMAINS = False
    SECURE_HSTS_PRELOAD            = False
    SESSION_COOKIE_HTTPONLY        = True
    CSRF_COOKIE_HTTPONLY           = True
else:
    # Production : HTTPS obligatoire, cookies sécurisés
    SECURE_SSL_REDIRECT            = os.getenv('SECURE_SSL_REDIRECT', 'True').lower() == 'true'
    SESSION_COOKIE_SECURE          = True
    CSRF_COOKIE_SECURE             = True
    SECURE_HSTS_SECONDS            = int(os.getenv('SECURE_HSTS_SECONDS', '31536000'))
    SECURE_HSTS_INCLUDE_SUBDOMAINS = True
    SECURE_HSTS_PRELOAD            = True
    SESSION_COOKIE_HTTPONLY        = True
    CSRF_COOKIE_HTTPONLY           = True

# ── Hachage des mots de passe — Argon2 (recommandé OWASP) ────────────────────
# Nécessite : pip install argon2-cffi
PASSWORD_HASHERS = [
    'django.contrib.auth.hashers.Argon2PasswordHasher',
    'django.contrib.auth.hashers.PBKDF2PasswordHasher',   # fallback migration douce
]