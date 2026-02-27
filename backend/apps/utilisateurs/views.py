from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import AllowAny, IsAuthenticated, IsAdminUser
from rest_framework_simplejwt.tokens import RefreshToken
from django.contrib.auth import authenticate

from ..modeles.models import Utilisateur
from .serializers import InscriptionSerializer, ConnexionSerializer, UtilisateurSerializer


def get_tokens(utilisateur):
    """Génère access + refresh token pour un utilisateur."""
    refresh = RefreshToken.for_user(utilisateur)
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
        """Renouvelle l'access token via le refresh token."""
        try:
            refresh_token = request.data.get("refresh")
            token = RefreshToken(refresh_token)
            return Response({
                "access": str(token.access_token)
            }, status=status.HTTP_200_OK)
        except Exception:
            return Response({"error": "Refresh token invalide ou expiré."}, status=status.HTTP_400_BAD_REQUEST)


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