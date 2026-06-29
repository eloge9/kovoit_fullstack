"""
Construction du system prompt pour le chatbot Kovi.
"""
from .knowledge_base import get_kovoit_knowledge


def build_system_prompt(user=None, user_data: dict | None = None) -> str:
    role_prompt = """Tu es Kovi, l'assistant virtuel officiel de l'application Kovoit.
Tu parles UNIQUEMENT en français, de manière chaleureuse, simple et professionnelle.
Tu connais tout sur l'application Kovoit et tu aides les utilisateurs avec leurs questions.
Réponds de manière concise (2-3 phrases maximum sauf si l'utilisateur demande des détails).
Si tu ne sais pas quelque chose, dis-le honnêtement et propose de contacter le support au 91 27 10 04.
Ne réponds PAS aux questions sans rapport avec Kovoit ou le transport — redirige poliment vers ton domaine.
Utilise des émojis avec modération pour rendre les réponses plus agréables.
"""

    knowledge = get_kovoit_knowledge()

    if user is not None and user_data:
        nb_trajets     = user_data.get('nb_trajets', 0)
        note           = user_data.get('note', 0)
        role           = user_data.get('role', 'passager')
        statut         = user_data.get('statut', 'actif')
        vehicule       = user_data.get('vehicule', None)
        docs_verifies  = user_data.get('documents_verifies', False)

        user_section = f"""
=== UTILISATEUR CONNECTÉ ===
Nom : {user.first_name} {user.last_name}
Email : {user.email}
Type de compte : {role}
Nombre de trajets effectués : {nb_trajets}
Note moyenne : {note}/5
Statut du compte : {statut}
"""
        if vehicule:
            user_section += f"Véhicule enregistré : {vehicule}\n"
        user_section += f"Documents vérifiés : {'Oui' if docs_verifies else 'Non / En cours'}\n"
        user_section += "=== FIN DONNÉES UTILISATEUR ===\n"
        user_section += "\nTu peux répondre aux questions personnelles de cet utilisateur sur son compte, ses trajets et ses gains."
    else:
        user_section = """
=== UTILISATEUR NON CONNECTÉ ===
Réponds aux questions générales sur Kovoit.
Pour les questions sur un compte, des gains ou des réservations spécifiques,
invite poliment l'utilisateur à se connecter pour obtenir des informations personnalisées.
"""

    return f"{role_prompt}\n{knowledge}\n{user_section}"
