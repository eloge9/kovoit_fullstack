"""
Client PayPlus Africa — API checkout-invoice.

Documentation officielle : https://developers.payplus.africa/
(intégration « sans redirection » / straight, section
integration-sans-redirection).

Contrairement à une intégration "collect + push silencieux", PayPlus renvoie
une URL de page de paiement hébergée (`response_text`) vers laquelle le
client doit être envoyé (navigateur / in-app browser) pour saisir son code
Mobile Money. La confirmation se fait ensuite via `verifier_facture()` ou
via le webhook `callback_url`.
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
PAYPLUS_API_KEY   = getattr(settings, 'PAYPLUS_API_KEY',   '')   # clé principale → header Apikey
PAYPLUS_TOKEN     = getattr(settings, 'PAYPLUS_TOKEN',     '')   # JWT → header Authorization: Bearer
PAYPLUS_ENV       = getattr(settings, 'PAYPLUS_ENV',       'prod')  # 'prod' | 'test'
PAYPLUS_WEBHOOK_SECRET = getattr(settings, 'PAYPLUS_WEBHOOK_SECRET', '')

TIMEOUT = 30  # secondes


class PayPlusError(Exception):
    """Erreur retournée par l'API PayPlus Africa."""
    def __init__(self, message: str, code: str = 'UNKNOWN'):
        super().__init__(message)
        self.code = code


def _headers() -> dict:
    return {
        'Content-Type':  'application/json',
        'Apikey':        PAYPLUS_API_KEY,
        'Authorization':  f'Bearer {PAYPLUS_TOKEN}',
    }


def generer_reference(identifiant) -> str:
    """Génère un identifiant de transaction unique au format KOVOIT-{id}-{hash}."""
    suffix = uuid.uuid4().hex[:8].upper()
    return f"KOVOIT-{identifiant}-{suffix}"


def normaliser_telephone_togo(phone: str) -> str:
    """
    PayPlus attend le numéro au format complet sans '+' (ex: 22890000000).
    Préfixe l'indicatif Togo (228) si l'utilisateur n'a saisi qu'un numéro local.
    """
    digits = ''.join(c for c in phone if c.isdigit())
    if digits.startswith('228') and len(digits) == 11:
        return digits
    if len(digits) == 8:
        return f'228{digits}'
    return digits


def creer_facture(
    *,
    phone: str,
    amount: int,
    description: str,
    transref: str,
    notify_url: str,
    return_url: str,
    cancel_url: str,
    website_url: str,
    store_name: str = 'KoVoit',
) -> dict:
    """
    Crée une facture checkout-invoice PayPlus Africa.

    Retourne {'token': ..., 'payment_url': ..., 'response_code': ...}.
    Lève PayPlusError en cas d'échec (réponse non-JSON, réseau, ou
    response_code != '00').
    """
    payload = {
        'commande': {
            'invoice': {
                'items': [{
                    'name':        description[:100] or 'KoVoit',
                    'description': description,
                    'quantity':    1,
                    'unit_price':  amount,
                    'total_price': amount,
                }],
                'total_amount': amount,
                'devise':       'xof',
                'description':  description,
                'customer':     normaliser_telephone_togo(phone),
                'otp':          '',  # uniquement pour Orange Money — non applicable au Togo
            },
            'store': {
                'name':        store_name,
                'website_url': website_url,
            },
            'actions': {
                'cancel_url':   f'{cancel_url}?transref={transref}',
                'return_url':   f'{return_url}?transref={transref}',
                'callback_url': f'{notify_url}?transref={transref}',
            },
            'custom_data': {
                'kovoit_ref': transref,
            },
        },
    }

    try:
        resp = requests.post(
            f'{PAYPLUS_BASE_URL}/pay/v01/redirect/checkout-invoice/create',
            json=payload,
            headers=_headers(),
            timeout=TIMEOUT,
        )
    except requests.exceptions.Timeout:
        raise PayPlusError('Timeout PayPlus Africa. Réessayez.', code='TIMEOUT')
    except requests.exceptions.RequestException as exc:
        raise PayPlusError(f'Erreur réseau PayPlus : {exc}', code='NETWORK_ERROR')

    logger.info('[PayPlus] create status=%s', resp.status_code)
    try:
        data = resp.json()
    except ValueError:
        logger.error(
            '[PayPlus] create réponse non-JSON status=%s body=%s',
            resp.status_code, resp.text[:1000],
        )
        raise PayPlusError(
            f'Réponse PayPlus invalide (HTTP {resp.status_code}).', code='INVALID_RESPONSE'
        )
    logger.debug('[PayPlus] create response=%s', data)

    response_code = str(data.get('response_code', ''))
    if response_code != '00':
        msg = data.get('response_text') or 'Erreur PayPlus inconnue'
        logger.error('[PayPlus] create failed: %s (code=%s)', msg, response_code)
        raise PayPlusError(msg, code=response_code or 'PAYPLUS_ERROR')

    token = data.get('token')
    payment_url = data.get('response_text')
    if not token or not payment_url:
        raise PayPlusError('Réponse PayPlus incomplète (token/URL manquants).', code='INCOMPLETE_RESPONSE')

    return {'token': token, 'payment_url': payment_url, 'response_code': response_code}


def verifier_facture(token: str) -> dict:
    """
    Vérifie le statut d'une facture checkout-invoice PayPlus Africa.

    Retourne {'statut': 'pending'|'completed'|'notcompleted'|'inconnu', 'response_code': ...}.
    Lève PayPlusError en cas d'erreur réseau/réponse invalide.
    """
    try:
        resp = requests.post(
            f'{PAYPLUS_BASE_URL}/pay/v01/redirect/checkout-invoice/confirm/',
            params={'invoiceToken': token},
            headers=_headers(),
            timeout=TIMEOUT,
        )
    except requests.exceptions.Timeout:
        raise PayPlusError('Timeout PayPlus Africa.', code='TIMEOUT')
    except requests.exceptions.RequestException as exc:
        raise PayPlusError(f'Erreur réseau PayPlus : {exc}', code='NETWORK_ERROR')

    logger.info('[PayPlus] confirm status=%s', resp.status_code)
    try:
        data = resp.json()
    except ValueError:
        logger.error(
            '[PayPlus] confirm réponse non-JSON status=%s body=%s',
            resp.status_code, resp.text[:1000],
        )
        raise PayPlusError(
            f'Réponse PayPlus invalide (HTTP {resp.status_code}).', code='INVALID_RESPONSE'
        )
    logger.debug('[PayPlus] confirm response=%s', data)

    response_code = str(data.get('response_code', ''))
    # description : 'pending' | 'completed' | 'notcompleted' — vide si response_code != '00'
    statut = data.get('description') or 'inconnu'

    return {'statut': statut, 'response_code': response_code, 'raw': data}


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
