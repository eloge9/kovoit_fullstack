"""Permissions RBAC pour le système de vérification."""
from rest_framework.permissions import BasePermission


class IsAdmin(BasePermission):
    def has_permission(self, request, view):
        return bool(request.user and request.user.is_authenticated and request.user.role == 'admin')


class IsSuperAdmin(BasePermission):
    def has_permission(self, request, view):
        return bool(request.user and request.user.is_authenticated and (
            request.user.is_superuser or request.user.role == 'admin'
        ))


class IsDriverOwner(BasePermission):
    def has_object_permission(self, request, view, obj):
        if hasattr(obj, 'user'):
            return obj.user == request.user
        if hasattr(obj, 'driver_profile'):
            return obj.driver_profile.user == request.user
        return False


class IsAdminOrDriverOwner(BasePermission):
    def has_permission(self, request, view):
        return bool(request.user and request.user.is_authenticated)

    def has_object_permission(self, request, view, obj):
        if request.user.role == 'admin':
            return True
        if hasattr(obj, 'user'):
            return obj.user == request.user
        if hasattr(obj, 'driver_profile'):
            return obj.driver_profile.user == request.user
        return False


class IsVerifiedDriver(BasePermission):
    """Le conducteur doit être ACTIVE pour accéder à la ressource."""
    message = "Votre compte conducteur n'est pas encore activé."

    def has_permission(self, request, view):
        if not (request.user and request.user.is_authenticated):
            return False
        try:
            dp = request.user.driver_profile
            return dp.status == 'ACTIVE' and dp.is_verified
        except Exception:
            return False
