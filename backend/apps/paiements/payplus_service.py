"""
Client PayPlus Africa — wrapping des API Collection et Status.

Documentation officielle : https://developers.payplus.africa/
"""
import hashlib
import hmac
import logging
import uuid
import requests
from django.conf import settings

logger = logging.getLogger(__name__)

# ── Configuration PayPlus Africa ──────────────────────────────────────────────
PAYPLUS_BASE_URL  = getattr(settings, 'PAYPLUS_BASE_URL',  'https://app.payplus.africa')
PAYPLUS_MERCHANT  = getattr(settings, 'PAYPLUS_MERCHANT',  '')
PAYPLUS_API_KEY   = getattr(settings, 'PAYPLUS_API_KEY',   '')   # clé courte → champ apikey
PAYPLUS_TOKEN     = getattr(settings, 'PAYPLUS_TOKEN',     '')   # JWT → header Authorization
PAYPLUS_ENV       = getattr(settings, 'PAYPLUS_ENV',       'prod')  # 'prod' | 'test'
PAYPLUS_WEBHOOK_SECRET = getattr(settings, 'PAYPLUS_WEBHOOK_SECRET', '')

# Mapping interne → code opérateur PayPlus Africa
# FLOOZ = Moov Flooz (Moov Togo)
# YAS   = Mixx by Yas (Yas Togo, anciennement T-Money)
OPERATOR_MAP = {
    'FLOOZ': 'FLOOZ',
    'YAS':   'TMONEY',   # PayPlus utilise encore TMONEY comme code interne
}

TIMEOUT = 30  # secondes


class PayPlusError(Exception):
    """Erreur retournée par l'API PayPlus Africa."""
    def __init__(self, message: str, code: str = 'UNKNOWN'):
        super().__init__(message)
        self.code = code


def _headers() -> dict:
    return {
        'Content-Type': 'application/json',
        'Authorization': f'Token {PAYPLUS_TOKEN}',  # JWT pour les endpoints GET
    }


def generer_reference(reservation_id) -> str:
    """Génère un identifiant de transaction unique au format KOVOIT-{id}-{hash}."""
    suffix = uuid.uuid4().hex[:8].upper()
    return f"KOVOIT-{reservation_id}-{suffix}"


def initier_paiement(
    *,
    phone: str,
    amount: int,
    operator: str,           # 'FLOOZ' | 'YAS'
    transref: str,
    description: str,
    notify_url: str,
) -> dict:
    """
    Initie un paiement Mobile Money via PayPlus Africa.

    Retourne le dict complet de la réponse PayPlus (token, message, etc.)
    Lève PayPlusError en cas d'erreur.
    """
    payplus_operator = OPERATOR_MAP.get(operator)
    if not payplus_operator:
        raise PayPlusError(f"Opérateur inconnu : {operator}", code='INVALID_OPERATOR')

    payload = {
        'merchant':    PAYPLUS_MERCHANT,
        'apikey':      PAYPLUS_API_KEY,   # clé courte VKWEY...
        'amount':      amount,
        'phone':       phone,
        'currency':    'XOF',
        'env':         PAYPLUS_ENV,
        'otp':         'false',
        'description': description,
        'notify_url':  notify_url,
        'transref':    transref,
        'operator':    payplus_operator,
    }

    try:
        resp = requests.post(
            f'{PAYPLUS_BASE_URL}/v1/transaction/collect',
            json=payload,
            timeout=TIMEOUT,
        )
        logger.debug('[PayPlus] collect status=%s', resp.status_code)
        data = resp.json()
        logger.debug('[PayPlus] collect response=%s', data)
    except requests.exceptions.Timeout:
        raise PayPlusError('Timeout PayPlus Africa. Réessayez.', code='TIMEOUT')
    except Exception as exc:
        raise PayPlusError(f'Erreur réseau PayPlus : {exc}', code='NETWORK_ERROR')

    # PayPlus retourne {"success": true/false, "message": "...", "token": "..."}
    if not data.get('success'):
        msg = data.get('message') or 'Erreur PayPlus inconnue'
        code = data.get('code') or 'PAYPLUS_ERROR'
        logger.error('[PayPlus] collect failed: %s (%s)', msg, code)
        raise PayPlusError(msg, code=str(code))

    return data


def verifier_statut(token: str) -> dict:
    """
    Vérifie le statut d'une transaction PayPlus Africa.

    Retourne le dict de réponse : {"success": bool, "data": {"status": "SUCCESS"|"PENDING"|"FAILED", ...}}
    Lève PayPlusError en cas d'erreur réseau.
    """
    try:
        resp = requests.get(
            f'{PAYPLUS_BASE_URL}/v1/transaction/{token}',
            headers=_headers(),
            timeout=TIMEOUT,
        )
        logger.debug('[PayPlus] status status=%s', resp.status_code)
        data = resp.json()
        logger.debug('[PayPlus] status response=%s', data)
    except requests.exceptions.Timeout:
        raise PayPlusError('Timeout PayPlus Africa.', code='TIMEOUT')
    except Exception as exc:
        raise PayPlusError(f'Erreur réseau PayPlus : {exc}', code='NETWORK_ERROR')

    return data


def verifier_signature_webhook(raw_body: bytes, signature_header: str) -> bool:
    """
    Vérifie la signature HMAC-SHA256 du webhook PayPlus Africa.
    Retourne True si la signature est valide, False sinon.
    """
    if not PAYPLUS_WEBHOOK_SECRET:
        logger.warning('[PayPlus] PAYPLUS_WEBHOOK_SECRET non configuré — signature non vérifiable')
        return False

    expected = hmac.new(
        PAYPLUS_WEBHOOK_SECRET.encode('utf-8'),
        raw_body,
        hashlib.sha256,
    ).hexdigest()

    return hmac.compare_digest(signature_header, expected)
