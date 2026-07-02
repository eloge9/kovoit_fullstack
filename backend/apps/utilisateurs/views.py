import logging
import uuid
import requests as http_requests

from rest_framework import viewsets, status, serializers as drf_serializers
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import AllowAny, IsAuthenticated, IsAdminUser
from rest_framework.throttling import AnonRateThrottle, UserRateThrottle


class SosThrottle(UserRateThrottle):
    scope = 'sos'
from rest_framework_simplejwt.tokens import RefreshToken
from django.contrib.auth import authenticate
from django.conf import settings

logger = logging.getLogger(__name__)

from ..modeles.models import Utilisateur, Vehicule, Conducteur, Passager, Evaluation, PLACES_MAX_PAR_TYPE, PasswordResetCode
from django.db.models import Avg
from django.core.mail import send_mail
from .serializers import InscriptionSerializer, ConnexionSerializer, UtilisateurSerializer, ChangePasswordSerializer
from .tokens import KovoitRefreshToken
import random
import re
import secrets

# Types MIME autorisés pour les documents d'identité
_ALLOWED_DOC_MIME = {'image/jpeg', 'image/png', 'image/webp', 'application/pdf'}
_MAX_DOC_SIZE     = 10 * 1024 * 1024  # 10 Mo


def _validate_document_file(f):
    """Valide taille et MIME déclaré d'un fichier document ; renomme aléatoirement."""
    if f.size > _MAX_DOC_SIZE:
        raise drf_serializers.ValidationError("Fichier trop volumineux (max 10 Mo).")
    mime = getattr(f, 'content_type', '') or ''
    if mime not in _ALLOWED_DOC_MIME:
        raise drf_serializers.ValidationError("Format non autorisé (JPG, PNG, WEBP ou PDF).")
    ext_map = {
        'image/jpeg': '.jpg', 'image/png': '.png',
        'image/webp': '.webp', 'application/pdf': '.pdf',
    }
    f.name = f"{uuid.uuid4().hex}{ext_map.get(mime, '.bin')}"
    return f


class AuthRateThrottle(AnonRateThrottle):
    """5 tentatives/minute sur les endpoints login et inscription."""
    scope = 'auth'


def get_tokens(utilisateur):
    """Génère access + refresh token incluant les claims role et peut_conduire."""
    refresh = KovoitRefreshToken.for_user(utilisateur)
    return {
        'refresh': str(refresh),
        'access': str(refresh.access_token),
    }


class AuthViewSet(viewsets.GenericViewSet):
    """
    ViewSet pour l'inscription et la connexion.
    POST /api/utilisateurs/auth/inscription/
    POST /api/utilisateurs/auth/connexion/
    POST /api/utilisateurs/auth/deconnexion/
    POST /api/utilisateurs/auth/refresh/
    """
    permission_classes = [AllowAny]
    throttle_classes   = [AuthRateThrottle]

    def get_serializer_class(self):
        if self.action == 'inscription':
            return InscriptionSerializer
        return ConnexionSerializer

    @action(detail=False, methods=['post'])
    def inscription(self, request):
        serializer = InscriptionSerializer(data=request.data)
        if serializer.is_valid():
            utilisateur = serializer.save()
            tokens = get_tokens(utilisateur)
            return Response({
                "message": "Inscription réussie.",
                "utilisateur": UtilisateurSerializer(utilisateur).data,
                "tokens": tokens
            }, status=status.HTTP_201_CREATED)

        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    @action(detail=False, methods=['post'])
    def connexion(self, request):
        serializer = ConnexionSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        email = serializer.validated_data['email']
        password = serializer.validated_data['password']

        try:
            user_obj = Utilisateur.objects.get(email=email)
        except Utilisateur.DoesNotExist:
            return Response({"error": "Identifiants invalides."}, status=status.HTTP_401_UNAUTHORIZED)

        utilisateur = authenticate(request, username=user_obj.username, password=password)

        if not utilisateur:
            return Response({"error": "Identifiants invalides."}, status=status.HTTP_401_UNAUTHORIZED)

        utilisateur.last_login_provider = 'email'
        utilisateur.save(update_fields=['last_login_provider'])

        tokens = get_tokens(utilisateur)
        return Response({
            "message": "Connexion réussie.",
            "utilisateur": UtilisateurSerializer(utilisateur).data,
            "tokens": tokens
        }, status=status.HTTP_200_OK)

    @action(detail=False, methods=['post'], permission_classes=[IsAuthenticated])
    def deconnexion(self, request):
        """Blackliste le refresh token."""
        try:
            refresh_token = request.data.get("refresh")
            token = RefreshToken(refresh_token)
            token.blacklist()
            return Response({"message": "Déconnexion réussie."}, status=status.HTTP_200_OK)
        except Exception:
            return Response({"error": "Token invalide."}, status=status.HTTP_400_BAD_REQUEST)

    @action(detail=False, methods=['post'])
    def refresh(self, request):
        """Renouvelle l'access token via le refresh token (avec rotation)."""
        refresh_str = request.data.get("refresh")
        if not refresh_str:
            return Response({"error": "Refresh token requis."}, status=status.HTTP_400_BAD_REQUEST)
        try:
            token = RefreshToken(refresh_str)
            # Blackliste l'ancien token puis génère un nouveau refresh token
            try:
                token.blacklist()
            except AttributeError:
                pass
            token.set_jti()
            token.set_exp()
            return Response({
                "access":  str(token.access_token),
                "refresh": str(token),
            }, status=status.HTTP_200_OK)
        except Exception:
            return Response({"error": "Refresh token invalide ou expiré."}, status=status.HTTP_401_UNAUTHORIZED)

    @action(detail=False, methods=['post'], url_path='demander-code')
    def demander_code(self, request):
        email = request.data.get('email', '').strip().lower()
        if not email:
            return Response({'error': 'Email requis.'}, status=status.HTTP_400_BAD_REQUEST)
        if not Utilisateur.objects.filter(email=email).exists():
            # Réponse identique pour ne pas révéler si l'email existe
            return Response({'message': 'Si cet email existe, un code a été envoyé.'})

        # Invalider les anciens codes
        PasswordResetCode.objects.filter(email=email, used=False).update(used=True)

        code = f"{secrets.randbelow(1_000_000):06d}"
        PasswordResetCode.objects.create(email=email, code=code)

        try:
            send_mail(
                subject='KoVoit — Code de réinitialisation',
                message=(
                    f"Votre code de réinitialisation KoVoit est : {code}\n\n"
                    f"Ce code est valable 10 minutes.\n"
                    f"Si vous n'avez pas demandé cette réinitialisation, ignorez cet email."
                ),
                html_message=(
                    f"<div style='font-family:sans-serif;max-width:480px;margin:auto;padding:32px;'>"
                    f"<h2 style='color:#3b82f6;'>KoVoit</h2>"
                    f"<p>Votre code de réinitialisation de mot de passe :</p>"
                    f"<div style='font-size:36px;font-weight:bold;letter-spacing:8px;"
                    f"background:#f1f5f9;padding:16px 24px;border-radius:12px;"
                    f"text-align:center;margin:24px 0;'>{code}</div>"
                    f"<p style='color:#64748b;font-size:14px;'>Ce code expire dans <strong>10 minutes</strong>.</p>"
                    f"<p style='color:#64748b;font-size:14px;'>Si vous n'avez pas fait cette demande, ignorez cet email.</p>"
                    f"</div>"
                ),
                from_email=settings.DEFAULT_FROM_EMAIL,
                recipient_list=[email],
                fail_silently=False,
            )
        except Exception as e:
            logger.error(f"Erreur envoi email reset: {e}")
            return Response({'error': "Impossible d'envoyer l'email. Réessayez plus tard."}, status=500)

        return Response({'message': 'Si cet email existe, un code a été envoyé.'})

    @action(detail=False, methods=['post'], url_path='google')
    def google_auth(self, request):
        """
        POST /api/utilisateurs/auth/google/
        Body: { "id_token": "<Google ID token>" }
        Vérifie le token, crée ou trouve l'utilisateur, retourne des JWT KoVoit.
        """
        id_token_str = request.data.get('id_token', '').strip()
        if not id_token_str:
            return Response({'error': 'id_token requis.'}, status=status.HTTP_400_BAD_REQUEST)

        client_id = getattr(settings, 'GOOGLE_CLIENT_ID', '')
        if not client_id:
            logger.error("GOOGLE_CLIENT_ID non configuré")
            return Response(
                {'error': 'Google Sign-In non configuré sur le serveur.'},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )

        try:
            from google.oauth2 import id_token as google_id_token
            from google.auth.transport import requests as google_requests
            idinfo = google_id_token.verify_oauth2_token(
                id_token_str, google_requests.Request(), client_id,
            )
        except ValueError:
            return Response(
                {'error': 'Token Google invalide ou expiré.'},
                status=status.HTTP_401_UNAUTHORIZED,
            )

        google_sub = idinfo.get('sub', '')
        email      = idinfo.get('email', '').lower().strip()
        first_name = idinfo.get('given_name', '')
        last_name  = idinfo.get('family_name', '')
        picture    = idinfo.get('picture', '')

        if not email or not google_sub:
            return Response(
                {'error': 'Compte Google incomplet (email ou identifiant manquant).'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        is_new = False

        # 1) Lookup par google_id (compte déjà lié)
        try:
            utilisateur = Utilisateur.objects.get(google_id=google_sub)
            # Mettre à jour la photo Google si elle a changé
            if picture and utilisateur.photo_google != picture:
                utilisateur.photo_google = picture
                utilisateur.save(update_fields=['photo_google'])
        except Utilisateur.DoesNotExist:
            # 2) Lookup par email (compte email existant → on lie)
            try:
                utilisateur = Utilisateur.objects.get(email=email)
                if not utilisateur.google_id:
                    fields_to_update = ['google_id', 'auth_provider', 'last_login_provider']
                    utilisateur.google_id = google_sub
                    utilisateur.auth_provider = 'google'
                    if picture:
                        utilisateur.photo_google = picture
                        fields_to_update.append('photo_google')
                        if not utilisateur.photo_url:
                            utilisateur.photo_url = picture
                            fields_to_update.append('photo_url')
                    utilisateur.save(update_fields=fields_to_update)
            except Utilisateur.DoesNotExist:
                # 3) Nouveau compte passager via Google
                username_base = re.sub(r'[^a-zA-Z0-9_]', '_', email.split('@')[0])[:28]
                username = username_base
                counter  = 1
                while Utilisateur.objects.filter(username=username).exists():
                    username = f"{username_base}{counter}"
                    counter += 1

                utilisateur = Utilisateur(
                    email=email,
                    username=username,
                    first_name=first_name,
                    last_name=last_name,
                    google_id=google_sub,
                    auth_provider='google',
                    photo_url=picture,
                    photo_google=picture,
                    role=Utilisateur.Role.PASSAGER,
                )
                utilisateur.set_unusable_password()
                utilisateur.save()
                Passager.objects.create(utilisateur=utilisateur)
                is_new = True

        utilisateur.last_login_provider = 'google'
        utilisateur.save(update_fields=['last_login_provider'])

        tokens = get_tokens(utilisateur)
        return Response({
            'message': 'Connexion Google réussie.',
            'utilisateur': UtilisateurSerializer(utilisateur).data,
            'tokens': tokens,
            'is_new_user': is_new,
        }, status=status.HTTP_200_OK)

    @action(detail=False, methods=['post'], url_path='reinitialisation')
    def reinitialisation(self, request):
        email        = request.data.get('email', '').strip().lower()
        code         = request.data.get('code', '').strip()
        new_password = request.data.get('new_password', '')
        new_password2 = request.data.get('new_password2', '')

        if not all([email, code, new_password, new_password2]):
            return Response({'error': 'Tous les champs sont requis.'}, status=400)

        if new_password != new_password2:
            return Response({'error': 'Les mots de passe ne correspondent pas.'}, status=400)

        if len(new_password) < 8:
            return Response({'error': 'Le mot de passe doit contenir au moins 8 caractères.'}, status=400)

        reset = PasswordResetCode.objects.filter(email=email, code=code, used=False).order_by('-created_at').first()
        if not reset or not reset.is_valid():
            return Response({'error': 'Code invalide ou expiré.'}, status=400)

        try:
            user = Utilisateur.objects.get(email=email)
        except Utilisateur.DoesNotExist:
            return Response({'error': 'Code invalide ou expiré.'}, status=400)

        user.set_password(new_password)
        user.save()
        reset.used = True
        reset.save()

        return Response({'message': 'Mot de passe réinitialisé avec succès.'})


class UtilisateurViewSet(viewsets.GenericViewSet):
    """
    GET    /api/utilisateurs/ko/profil/        → profil connecté
    PUT    /api/utilisateurs/ko/profil/  → modifier profil
    PATCH  /api/utilisateurs/ko/profil/  → modifier profil
    DELETE /api/utilisateurs/ko/profil/  → modifier profil
    """
    permission_classes = [IsAuthenticated]
    serializer_class = UtilisateurSerializer
    queryset = Utilisateur.objects.all()

    @action(detail=False, methods=['get'])
    def profil(self, request):
        serializer = UtilisateurSerializer(request.user)
        return Response(serializer.data)

    @action(detail=False, methods=['put', 'patch'], url_path='profil/update')
    def update_profil(self, request):
        serializer = UtilisateurSerializer(
            request.user,
            data=request.data,
            partial=request.method == 'PATCH'
        )
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    @action(detail=False, methods=['post'], url_path='profil/change-password')
    def change_password(self, request):
        serializer = ChangePasswordSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        current_password = serializer.validated_data['current_password']
        new_password = serializer.validated_data['new_password']

        if not request.user.check_password(current_password):
            return Response({
                'current_password': 'Mot de passe actuel incorrect.'
            }, status=status.HTTP_400_BAD_REQUEST)

        request.user.set_password(new_password)
        request.user.save()
        return Response({"message": "Mot de passe mis à jour avec succès."}, status=status.HTTP_200_OK)

    @action(detail=False, methods=['delete'], url_path='profil/delete')
    def delete_profil(self, request):
        """Supprime le compte de l'utilisateur connecté."""
        utilisateur = request.user
        try:
            # Blackliste le refresh token avant suppression
            refresh_token = request.data.get("refresh")
            if refresh_token:
                token = RefreshToken(refresh_token)
                token.blacklist()
        except Exception:
            pass  # On supprime quand même même si le token est invalide

        utilisateur.delete()
        return Response({"message": "Compte supprimé avec succès."}, status=status.HTTP_204_NO_CONTENT)

    @action(detail=True, methods=['delete'], url_path='delete', permission_classes=[IsAdminUser])
    def delete_utilisateur(self, request, pk=None):
        """Supprime un utilisateur par son ID (admin seulement)."""
        try:
            utilisateur = Utilisateur.objects.get(pk=pk)
            utilisateur.delete()
            return Response({"message": f"Utilisateur {utilisateur.username} supprimé."},
                            status=status.HTTP_204_NO_CONTENT)
        except Utilisateur.DoesNotExist:
            return Response({"error": "Utilisateur introuvable."}, status=status.HTTP_404_NOT_FOUND)
        
    @action(detail=False, methods=['get'], url_path='vehicules')
    def vehicules(self, request):
        try:
            conducteur = request.user.profil_conducteur
        except Exception:
            return Response({"error": "Profil conducteur introuvable."}, status=403)
 
        vehicules = Vehicule.objects.filter(conducteur=conducteur).order_by('created_at')
        data = [{
            "id":            v.id,
            "type_vehicule": v.type_vehicule,
            "marque":        v.marque,
            "modele":        v.modele,
            "couleur":       v.couleur,
            "plaque":        v.plaque,
            "places_max":    v.places_max,
            "est_actif":     v.est_actif,
        } for v in vehicules]
        return Response(data)
 
    # ── Ajouter un véhicule ───────────────────────────────────────────────
    @action(detail=False, methods=['post'], url_path='vehicules/ajouter')
    def ajouter_vehicule(self, request):
        try:
            conducteur = request.user.profil_conducteur
        except Exception:
            return Response({"error": "Profil conducteur introuvable."}, status=403)
 
        required = ['type_vehicule', 'marque', 'modele', 'couleur', 'plaque']
        for field in required:
            if not request.data.get(field):
                return Response({field: "Ce champ est requis."}, status=400)
 
        type_v = request.data.get('type_vehicule')
        if type_v not in PLACES_MAX_PAR_TYPE:
            return Response({"type_vehicule": "Type invalide. Choisir parmi : moto, voiture, minibus, camion."}, status=400)
 
        if Vehicule.objects.filter(plaque=request.data.get('plaque')).exists():
            return Response({"plaque": "Cette plaque est déjà enregistrée."}, status=400)
 
        vehicule = Vehicule.objects.create(
            conducteur=conducteur,
            type_vehicule=type_v,
            marque=request.data.get('marque'),
            modele=request.data.get('modele'),
            couleur=request.data.get('couleur'),
            plaque=request.data.get('plaque'),
            places_max=request.data.get('places_max') or PLACES_MAX_PAR_TYPE[type_v],
        )
        return Response({
            "id":            vehicule.id,
            "type_vehicule": vehicule.type_vehicule,
            "marque":        vehicule.marque,
            "modele":        vehicule.modele,
            "couleur":       vehicule.couleur,
            "plaque":        vehicule.plaque,
            "places_max":    vehicule.places_max,
            "est_actif":     vehicule.est_actif,
        }, status=201)
 
    # ── Upload CNI / Permis ───────────────────────────────────────────────
    @action(detail=False, methods=['post'], url_path='upload-documents')
    def upload_documents(self, request):
        """
        Upload photo_cni et/ou photo_permis.
        Passe statut_validation à 'en_attente' dès qu'un document est reçu.
        """
        user = request.user
        recu = False

        try:
            if 'photo_cni' in request.FILES:
                user.photo_cni = _validate_document_file(request.FILES['photo_cni'])
                recu = True
            if 'photo_permis' in request.FILES:
                user.photo_permis = _validate_document_file(request.FILES['photo_permis'])
                recu = True
        except drf_serializers.ValidationError as exc:
            return Response({"error": exc.detail[0] if exc.detail else "Fichier invalide."}, status=400)

        if not recu:
            return Response({"error": "Aucun document fourni."}, status=status.HTTP_400_BAD_REQUEST)

        user.statut_validation = 'en_attente'
        user.save()
        return Response({
            "message": "Documents uploadés. En attente de validation par l'administrateur.",
            "statut_validation": user.statut_validation,
        })

    # ── Bascule Passager → Conducteur ─────────────────────────────────────
    @action(detail=False, methods=['post'], url_path='basculer-role')
    def basculer_role(self, request):
        """
        Permet à un passager de devenir conducteur.
        Crée le profil Conducteur + un premier véhicule.
        Passe le rôle à 'conducteur' et statut_validation à 'en_attente'.
        """
        user = request.user

        if user.role != Utilisateur.Role.PASSAGER:
            return Response(
                {"error": "Seuls les passagers peuvent demander un changement de rôle."},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Champs conducteur obligatoires
        numero_permis     = request.data.get('numero_permis', '').strip()
        experience_annees = int(request.data.get('experience_annees', 0))

        if not numero_permis:
            return Response({"error": "Le numéro de permis est requis."}, status=status.HTTP_400_BAD_REQUEST)

        # Champs véhicule obligatoires
        type_vehicule = request.data.get('type_vehicule', '').strip()
        marque        = request.data.get('marque', '').strip()
        modele        = request.data.get('modele', '').strip()
        couleur       = request.data.get('couleur', '').strip()
        plaque        = request.data.get('plaque', '').strip()

        if not all([type_vehicule, marque, modele, couleur, plaque]):
            return Response(
                {"error": "Tous les champs du véhicule sont requis (type, marque, modèle, couleur, plaque)."},
                status=status.HTTP_400_BAD_REQUEST
            )

        if type_vehicule not in PLACES_MAX_PAR_TYPE:
            return Response(
                {"type_vehicule": "Type invalide. Choisir parmi : moto, voiture, minibus, camion."},
                status=status.HTTP_400_BAD_REQUEST
            )

        if Vehicule.objects.filter(plaque=plaque).exists():
            return Response({"plaque": "Cette plaque est déjà enregistrée."}, status=status.HTTP_400_BAD_REQUEST)

        # Upload documents si fournis (avec validation)
        try:
            if 'photo_cni' in request.FILES:
                user.photo_cni = _validate_document_file(request.FILES['photo_cni'])
            if 'photo_permis' in request.FILES:
                user.photo_permis = _validate_document_file(request.FILES['photo_permis'])
        except drf_serializers.ValidationError as exc:
            return Response({"error": exc.detail[0] if exc.detail else "Fichier invalide."}, status=400)

        # Changer le rôle et passer en attente
        user.role = 'conducteur'
        user.statut_validation = 'en_attente'
        user.is_driver = True
        user.save()

        # Créer le profil conducteur (idempotent)
        conducteur, _ = Conducteur.objects.get_or_create(
            utilisateur=user,
            defaults={
                'numero_permis':     numero_permis,
                'experience_annees': experience_annees,
            }
        )

        # Créer le premier véhicule
        places_max = PLACES_MAX_PAR_TYPE.get(type_vehicule, 4)
        Vehicule.objects.create(
            conducteur=conducteur,
            type_vehicule=type_vehicule,
            marque=marque,
            modele=modele,
            couleur=couleur,
            plaque=plaque,
            places_max=places_max,
        )

        return Response({
            "message": "Demande de bascule soumise avec succès. En attente de validation admin.",
            "utilisateur": UtilisateurSerializer(user).data,
        }, status=status.HTTP_200_OK)

    # ── Basculement rapide de mode (conducteur ↔ passager) ────────────────
    @action(detail=False, methods=['post'], url_path='changer-mode')
    def changer_mode(self, request):
        """
        Bascule le mode courant sans changer le rôle permanent.
        → Conducteur mode : autorisé si role='conducteur' OU peut_conduire OU profil conducteur.
        → Passager mode   : toujours autorisé si l'utilisateur a des droits conducteur.
        Le champ 'role' n'est jamais modifié ici ; seul 'mode_courant' change.
        """
        user = request.user
        Role = Utilisateur.Role

        nouveau_mode = request.data.get('mode', '')
        if nouveau_mode not in ('passager', 'conducteur'):
            return Response(
                {"error": "Mode invalide. Utilisez 'passager' ou 'conducteur'."},
                status=status.HTTP_400_BAD_REQUEST
            )

        has_driver_profile = hasattr(user, 'driver_profile') or hasattr(user, 'profil_conducteur')
        has_driver_access = (
            user.role == Role.CONDUCTEUR or
            user.peut_conduire or
            has_driver_profile
        )

        if nouveau_mode == 'conducteur':
            if not has_driver_access:
                return Response(
                    {"error": "Vous devez d'abord soumettre un dossier conducteur.", "code": "NO_DRIVER_PROFILE"},
                    status=status.HTTP_403_FORBIDDEN
                )
            # Créer le profil passager si manquant (peut être utile côté passager)
            if not hasattr(user, 'profil_passager'):
                Passager.objects.create(utilisateur=user)

        elif nouveau_mode == 'passager':
            if not has_driver_access:
                return Response(
                    {"error": "Basculement non autorisé."},
                    status=status.HTTP_403_FORBIDDEN
                )

        # Ne change pas role — met à jour uniquement mode_courant
        user.mode_courant = nouveau_mode
        user.save(update_fields=['mode_courant'])

        tokens = get_tokens(user)
        return Response({
            "message": f"Mode {nouveau_mode} activé.",
            "mode": nouveau_mode,
            "role": user.role,
            "tokens": tokens,
            "utilisateur": UtilisateurSerializer(user).data,
        })

    # ── Désactiver un véhicule ────────────────────────────────────────────
    @action(detail=True, methods=['post'], url_path='desactiver')
    def desactiver_vehicule(self, request, pk=None):
        from django.db import transaction as db_transaction
        try:
            conducteur = request.user.profil_conducteur
        except Exception:
            return Response({"error": "Non autorisé."}, status=403)

        with db_transaction.atomic():
            try:
                vehicule = Vehicule.objects.select_for_update().get(pk=pk, conducteur=conducteur)
            except Vehicule.DoesNotExist:
                return Response({"error": "Véhicule introuvable."}, status=404)

            if not vehicule.est_actif:
                return Response({"error": "Ce véhicule est déjà désactivé."}, status=400)

            vehicule.est_actif = False
            vehicule.save(update_fields=['est_actif'])

        return Response({"message": "Véhicule désactivé."})

    # ── Bouton SOS ────────────────────────────────────────────────────────
    @action(detail=False, methods=['post'], url_path='sos', throttle_classes=[SosThrottle])
    def sos(self, request):
        """
        Déclenche un SOS : envoie un SMS au contact d'urgence via Africa's Talking.
        Body: { latitude, longitude, trajet_id (optionnel) }
        """
        user = request.user

        if not user.contact_urgence_telephone:
            return Response(
                {"error": "Aucun contact d'urgence configuré. Ajoutez-en un dans votre profil."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        tid = str(request.data.get('trajet_id', '') or '')[:50]

        # Valider que lat/lng sont bien des nombres flottants (évite l'injection dans l'URL)
        try:
            lat = float(request.data.get('latitude',  0))
            lng = float(request.data.get('longitude', 0))
            if not (-90 <= lat <= 90) or not (-180 <= lng <= 180):
                raise ValueError
            maps_url = f"https://maps.google.com/?q={lat:.6f},{lng:.6f}"
        except (TypeError, ValueError):
            lat, lng  = None, None
            maps_url  = "Position inconnue"
        nom_user = user.get_full_name() or user.username

        message_sms = (
            f"URGENCE KoVoit\n"
            f"{nom_user} a activé le bouton SOS.\n"
            f"Position : {maps_url}\n"
            f"Trajet : {tid or 'non précisé'}\n"
            f"Appelez-le/la immédiatement."
        )

        at_api_key  = getattr(settings, 'AFRICASTALKING_API_KEY',  '')
        at_username = getattr(settings, 'AFRICASTALKING_USERNAME', 'sandbox')
        sms_envoye  = False

        if at_api_key:
            try:
                resp = http_requests.post(
                    "https://api.africastalking.com/version1/messaging",
                    headers={
                        "apiKey":       at_api_key,
                        "Content-Type": "application/x-www-form-urlencoded",
                        "Accept":       "application/json",
                    },
                    data={
                        "username": at_username,
                        "to":       user.contact_urgence_telephone,
                        "message":  message_sms,
                    },
                    timeout=10,
                )
                sms_envoye = resp.status_code == 201
            except Exception as exc:
                logger.error("SOS SMS échec pour %s : %s", user.username, exc)

        logger.warning(
            "SOS déclenché — user=%s lat=%s lng=%s trajet=%s contact=%s sms=%s",
            user.username, lat, lng, tid,
            user.contact_urgence_telephone,
            "OK" if sms_envoye else "ECHEC",
        )

        return Response({
            "message":    "SOS envoyé avec succès." if sms_envoye
                          else "SOS enregistré. SMS non envoyé (clé API Africa's Talking manquante).",
            "contact_nom": user.contact_urgence_nom,
            "sms_envoye":  sms_envoye,
        })

    # ── Mettre à jour le contact d'urgence ────────────────────────────────
    @action(detail=False, methods=['post'], url_path='contact-urgence')
    def contact_urgence(self, request):
        """
        Enregistre ou met à jour le contact d'urgence.
        Body: { contact_urgence_nom, contact_urgence_telephone }
        """
        nom       = str(request.data.get('contact_urgence_nom', '')).strip()
        telephone = str(request.data.get('contact_urgence_telephone', '')).strip()

        if not nom or not telephone:
            return Response(
                {"error": "Le nom et le téléphone du contact d'urgence sont requis."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Validation format téléphone (international ou local Bénin/CI)
        _TEL_RE = re.compile(r'^\+?[1-9]\d{7,14}$')
        if not _TEL_RE.match(telephone.replace(' ', '').replace('-', '')):
            return Response(
                {"error": "Numéro de téléphone invalide (ex : +22991271004)."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        request.user.contact_urgence_nom       = nom
        request.user.contact_urgence_telephone = telephone
        request.user.save(update_fields=['contact_urgence_nom', 'contact_urgence_telephone'])

        return Response({
            "message":                  "Contact d'urgence mis à jour.",
            "contact_urgence_nom":       nom,
            "contact_urgence_telephone": telephone,
        })


class ProfilPublicViewSet(viewsets.GenericViewSet):
    """
    Profil public d'un conducteur — accessible sans authentification.
    GET /api/utilisateurs/conducteur/{id}/
    """
    permission_classes = [AllowAny]

    @action(detail=True, methods=['get'], url_path='profil')
    def profil(self, request, pk=None):
        try:
            conducteur = Utilisateur.objects.get(pk=pk, role=Utilisateur.Role.CONDUCTEUR)
        except Utilisateur.DoesNotExist:
            return Response({"error": "Conducteur introuvable."}, status=404)

        # Score de confiance : moyenne pondérée des 20 dernières évaluations
        evaluations_recentes = Evaluation.objects.filter(
            cible=conducteur, signale=False
        ).order_by('-date_evaluation')[:20]

        score_confiance = 0.0
        if evaluations_recentes:
            note_moy = sum(e.note for e in evaluations_recentes) / len(evaluations_recentes)
            # Bonus si validé, note ramenée sur 100
            score_confiance = round((note_moy / 5) * 90 + (10 if conducteur.statut_validation == 'valide' else 0), 1)

        vehicules = []
        try:
            vehicules = [{
                "type_vehicule": v.type_vehicule,
                "marque":        v.marque,
                "modele":        v.modele,
                "couleur":       v.couleur,
                "places_max":    v.places_max,
            } for v in conducteur.profil_conducteur.vehicules.filter(est_actif=True)]
        except Exception:
            pass

        evaluations_data = [{
            "auteur":      f"{e.auteur.first_name} {e.auteur.last_name}".strip() or e.auteur.username,
            "note":        e.note,
            "commentaire": e.commentaire,
            "date":        e.date_evaluation,
        } for e in evaluations_recentes[:5]]

        from django.conf import settings as dj_settings
        from .serializers import UtilisateurSerializer

        photo_url = None
        if conducteur.photo_profil:
            photo_url = request.build_absolute_uri(conducteur.photo_profil.url)

        return Response({
            "id":                 str(conducteur.id),
            "nom":                f"{conducteur.first_name} {conducteur.last_name}".strip() or conducteur.username,
            "photo_profil":       photo_url,
            "note":               conducteur.note,
            "score_confiance":    score_confiance,
            "statut_validation":  conducteur.statut_validation,
            "est_verifie":        conducteur.statut_validation == 'valide',
            "vehicules":          vehicules,
            "evaluations_recentes": evaluations_data,
            "nb_evaluations":     Evaluation.objects.filter(cible=conducteur, signale=False).count(),
        })