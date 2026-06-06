from rest_framework_simplejwt.tokens import RefreshToken


class KovoitRefreshToken(RefreshToken):
    """
    Étend le token SimpleJWT standard avec les claims métier Kovoit.
    Le middleware Next.js lit 'role' et 'peut_conduire' depuis le payload JWT signé,
    ce qui élimine la dépendance au cookie user_role non signé.
    """

    @classmethod
    def for_user(cls, user):
        token = super().for_user(user)
        token["role"] = user.role
        token["peut_conduire"] = user.peut_conduire
        return token
