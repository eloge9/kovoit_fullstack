"""
Moteur de règles pour le chatbot Kovi.
Répond aux questions fréquentes sans appel IA.
Retourne None si aucune règle ne correspond → l'IA prend le relais.
"""

# ── Règles : (liste de mots-clés, réponse) ───────────────────────────────────
# Les mots-clés sont cherchés dans le message normalisé (minuscules, sans accents).
# La PREMIÈRE règle dont un mot-clé correspond est utilisée.

_RULES: list[tuple[list[str], str]] = [

    # ── Salutations ──────────────────────────────────────────────────────────
    (
        ['bonjour', 'bonsoir', 'bonne nuit', 'salut', 'hello', 'hi', 'hey',
         'coucou', 'yo', 'slt', 'bjr', 'good morning', 'good evening',
         'allo', 'allô', 'bien le bonjour'],
        "Bonjour ! 👋 Je suis **Kovi**, l'assistant virtuel de Kovoit.\n"
        "Comment puis-je vous aider aujourd'hui ?\n\n"
        "Je peux répondre à vos questions sur :\n"
        "• 🚗 Réserver ou proposer un trajet\n"
        "• 💳 Paiements et tarifs\n"
        "• 📋 Devenir conducteur\n"
        "• 🔒 Sécurité et vérification\n"
        "• 📞 Contact et support\n"
        "Posez votre question !"
    ),

    # ── Comment ça va ────────────────────────────────────────────────────────
    (
        ['comment ca va', 'comment vas-tu', 'comment tu vas', 'ca va',
         'tu vas bien', 'comment allez-vous', 'la forme'],
        "Je vais très bien, merci de demander ! 😊\n"
        "Je suis Kovi, prêt à vous aider avec tout ce qui concerne Kovoit.\n"
        "Qu'est-ce que je peux faire pour vous ?"
    ),

    # ── Qui est Kovi ─────────────────────────────────────────────────────────
    (
        ['qui es-tu', 'qui etes-vous', 'qui es tu', 'qui êtes vous',
         'c\'est quoi kovi', 'kovi c\'est qui', 'tu es qui', 'vous etes qui',
         'tu es un robot', 'tu es une ia', 'es-tu humain', 'es tu humain'],
        "Je suis **Kovi** 🤖, l'assistant virtuel officiel de l'application **Kovoit**.\n\n"
        "Je suis là pour répondre à toutes vos questions sur l'application : "
        "réservations, paiements, conducteurs, sécurité, et plus encore.\n\n"
        "Pour parler à un humain, contactez notre support : **91 27 10 04** 📞"
    ),

    # ── Présentation Kovoit ──────────────────────────────────────────────────
    (
        ['qu\'est-ce que kovoit', 'c\'est quoi kovoit', 'kovoit c\'est quoi',
         'presentation de kovoit', 'a propos de kovoit', 'kovoit kesako',
         'kovoit c\'est', 'parle moi de kovoit', 'decris kovoit',
         'kovoit application', 'kovoit plateforme'],
        "**Kovoit** est une plateforme intelligente de covoiturage pour le **Togo et l'Afrique de l'Ouest** 🌍\n\n"
        "Elle met en relation des conducteurs (qui ont des places libres) avec des passagers "
        "(qui font le même trajet) pour voyager moins cher et réduire les embouteillages.\n\n"
        "🌟 Ce qui nous distingue :\n"
        "• 📍 Géolocalisation GPS en temps réel\n"
        "• 🗺️ Cartographie intelligente (monter/descendre n'importe où sur le trajet)\n"
        "• 💳 Paiement Mobile Money sécurisé (Flooz, Yas) ou espèces\n"
        "• 🤖 IA pour la vérification des documents conducteur\n"
        "• 💬 Messagerie instantanée privée et de groupe\n"
        "• ⭐ Système de notation bidirectionnel\n"
        "• 🆘 Bouton SOS d'urgence intégré"
    ),

    # ── Mission et valeurs ───────────────────────────────────────────────────
    (
        ['mission', 'valeur', 'objectif de kovoit', 'but de kovoit',
         'pourquoi kovoit', 'vision'],
        "🎯 **Mission de Kovoit** :\nRendre le transport plus accessible, sécurisé et économique pour tous.\n\n"
        "💡 **Nos valeurs** :\n"
        "• 🔒 Sécurité et confiance\n"
        "• 💡 Innovation technologique\n"
        "• ♿ Accessibilité pour tous\n"
        "• 🌱 Respect de l'environnement\n"
        "• 🤝 Solidarité et économie partagée"
    ),

    # ── Zones couvertes ──────────────────────────────────────────────────────
    (
        ['zone', 'couverture', 'disponible ou', 'disponible dans', 'pays',
         'togo', 'afrique', 'ville', 'lome', 'kpalime', 'atakpame',
         'sokode', 'kara', 'dapaong', 'region', 'ou est disponible',
         'disponibilite'],
        "📍 Kovoit est disponible au **Togo** et s'étend en **Afrique de l'Ouest** 🌍\n\n"
        "Villes couvertes au Togo :\n"
        "• Lomé (capitale)\n"
        "• Kpalimé, Atakpamé, Sokodé, Kara, Dapaong\n"
        "• Et tous les axes interurbains\n\n"
        "La couverture s'agrandit régulièrement ! Si votre ville n'est pas encore disponible, "
        "revenez bientôt 🚀"
    ),

    # ── Créer un compte ──────────────────────────────────────────────────────
    (
        ['creer un compte', 'créer compte', 'inscription', 'inscrire',
         'enregistrer', 'nouveau compte', 'ouvrir un compte', 'rejoindre kovoit',
         'comment s\'inscrire', 'comment m\'inscrire', 'sign up', 'register'],
        "📝 Pour créer votre compte Kovoit :\n\n"
        "1️⃣ Téléchargez l'application (ou allez sur le site web)\n"
        "2️⃣ Tapez **S'inscrire**\n"
        "3️⃣ Renseignez : nom, prénom, email, téléphone, mot de passe\n"
        "4️⃣ Choisissez votre rôle : **passager**, **conducteur**, ou les deux !\n"
        "5️⃣ Validez votre compte\n\n"
        "✅ C'est gratuit et rapide — moins de 2 minutes !"
    ),

    # ── Connexion / Mot de passe oublié ─────────────────────────────────────
    (
        ['connexion', 'connecter', 'login', 'se connecter', 'mot de passe oublie',
         'reinitialiser mot de passe', 'reset password', 'mot de passe perdu',
         'j\'ai oublie mon mot de passe', 'oublie mon mdp'],
        "🔑 Pour vous connecter : entrez votre email et mot de passe.\n\n"
        "**Mot de passe oublié ?**\n"
        "1️⃣ Allez sur la page de connexion\n"
        "2️⃣ Tapez **Mot de passe oublié**\n"
        "3️⃣ Entrez votre email\n"
        "4️⃣ Recevez un lien de réinitialisation par email\n"
        "5️⃣ Créez un nouveau mot de passe\n\n"
        "Toujours bloqué ? Contactez le support au **91 27 10 04** 📞"
    ),

    # ── Réserver un trajet (passager) ────────────────────────────────────────
    (
        ['reserver', 'reservation', 'comment reserver', 'prendre un trajet',
         'trouver un trajet', 'chercher un trajet', 'book', 'booking',
         'rechercher trajet', 'je veux voyager', 'je veux un trajet'],
        "🚗 Pour réserver un trajet en tant que passager :\n\n"
        "1️⃣ Connectez-vous et allez dans **Rechercher un trajet**\n"
        "2️⃣ Entrez votre point de **départ** et votre **destination**\n"
        "3️⃣ Choisissez la date et le nombre de places\n"
        "4️⃣ Parcourez les trajets disponibles (triés par compatibilité GPS)\n"
        "5️⃣ Choisissez un trajet et tapez **Réserver**\n"
        "6️⃣ Payez (Mobile Money ou espèces)\n"
        "7️⃣ Recevez votre **code d'embarquement KVT-XXXX** et votre QR Code\n"
        "8️⃣ Le jour du trajet : montrez votre QR Code au conducteur ✅"
    ),

    # ── Proposer / Créer un trajet (conducteur) ──────────────────────────────
    (
        ['proposer un trajet', 'creer un trajet', 'publier un trajet',
         'ajouter un trajet', 'comment proposer', 'mettre un trajet',
         'offrir un trajet', 'je veux proposer'],
        "🚘 Pour proposer un trajet en tant que conducteur :\n\n"
        "1️⃣ Passez en **mode Conducteur** (bouton en haut à droite)\n"
        "2️⃣ Tapez le bouton **+** au centre du bas de l'écran\n"
        "3️⃣ Renseignez :\n"
        "   • Point de départ et destination\n"
        "   • Date et heure du départ\n"
        "   • Votre véhicule et le nombre de places\n"
        "   • Étapes intermédiaires (optionnel)\n"
        "4️⃣ Le **prix est calculé automatiquement** 💰\n"
        "5️⃣ Publiez — les passagers peuvent réserver immédiatement !"
    ),

    # ── Devenir conducteur ───────────────────────────────────────────────────
    (
        ['devenir conducteur', 'devenir chauffeur', 'passer conducteur',
         'mode conducteur', 'conducteur kovoit', 'comment conduire',
         'je veux conduire', 'je veux etre conducteur'],
        "🚗 Pour devenir conducteur sur Kovoit :\n\n"
        "1️⃣ Allez dans **Mon compte → Devenir conducteur**\n"
        "2️⃣ Ajoutez votre véhicule :\n"
        "   • Marque, modèle, couleur, numéro de plaque\n"
        "3️⃣ Soumettez vos documents :\n"
        "   • 🪪 Permis de conduire\n"
        "   • 📋 Carte grise du véhicule\n"
        "4️⃣ Nos agents + IA vérifient vos documents (sous 24h)\n"
        "5️⃣ Une fois validé → vous pouvez proposer des trajets et gagner de l'argent ! 💰\n\n"
        "La vérification garantit la sécurité de tous les passagers ✅"
    ),

    # ── Documents vérification ───────────────────────────────────────────────
    (
        ['document', 'verification', 'valider document', 'permis',
         'carte grise', 'piece identite', 'justificatif', 'validation',
         'documents requis', 'quels documents'],
        "📋 Documents requis pour devenir conducteur :\n\n"
        "• 🪪 **Permis de conduire** (obligatoire)\n"
        "• 📄 **Carte grise** du véhicule (obligatoire)\n"
        "• 🛡️ Assurance véhicule (recommandée)\n\n"
        "🤖 La vérification est faite par notre **IA** et nos agents sous **24h**.\n"
        "Vous recevrez une notification quand c'est validé.\n\n"
        "En cas de refus, vous pouvez soumettre à nouveau vos documents."
    ),

    # ── Code d'embarquement / QR Code ───────────────────────────────────────
    (
        ['code embarquement', 'kvt', 'qr code', 'qr', 'code qr',
         'valider montee', 'confirmation montee', 'embarquement',
         'code de reservation', 'scanner'],
        "🎟️ Le **Code d'embarquement** est généré automatiquement pour chaque réservation confirmée.\n\n"
        "Format : **KVT-XXXX** (ex: KVT-4782)\n\n"
        "**Comment ça marche :**\n"
        "• Le passager affiche son **QR Code** dans l'app\n"
        "• Le conducteur scanne le QR Code OU saisit le code KVT manuellement\n"
        "• ✅ L'embarquement est validé → le trajet commence\n\n"
        "QR Code non reconnu ? Demandez au conducteur de saisir le code KVT-XXXX à la main."
    ),

    # ── Paiement ─────────────────────────────────────────────────────────────
    (
        ['payer', 'paiement', 'comment payer', 'mode de paiement',
         'flooz', 'moov flooz', 'yas', 'mixx', 'mobile money',
         'especes', 'cash', 'payplus'],
        "💳 Kovoit accepte **3 modes de paiement** :\n\n"
        "1. 📱 **FLOOZ** — Moov Flooz (Mobile Money)\n"
        "2. 📱 **YAS** — Mixx by Yas (Mobile Money)\n"
        "3. 💵 **Espèces** — payées directement au conducteur\n\n"
        "**Comment payer par Mobile Money :**\n"
        "1️⃣ Sélectionnez votre méthode après la réservation\n"
        "2️⃣ Entrez votre numéro de téléphone\n"
        "3️⃣ Confirmez le paiement sur votre téléphone\n"
        "4️⃣ ✅ Paiement sécurisé via **PayPlus Africa**"
    ),

    # ── Tarifs / Prix ────────────────────────────────────────────────────────
    (
        ['tarif', 'prix', 'combien ca coute', 'combien coute', 'combien ca',
         'cout', 'frais', 'commission', 'calcul prix', 'calculer prix',
         'prix du trajet', 'tarification', 'devise', 'fcfa', 'franc cfa'],
        "💰 Le prix d'un trajet Kovoit est calculé **automatiquement** selon :\n\n"
        "• 📏 La **distance réelle** entre départ et destination\n"
        "• 🚗 Le **type de véhicule** du conducteur :\n"
        "   - 🏍️ Moto → tarif le plus bas\n"
        "   - 🚗 Voiture → tarif standard\n"
        "   - 🚌 Minibus → tarif intermédiaire\n"
        "   - 🚛 Camion → tarif variable\n"
        "• 👥 Le nombre de places réservées\n\n"
        "La devise est le **Franc CFA (FCFA)**.\n"
        "Kovoit prend une petite commission — le reste va directement au conducteur."
    ),

    # ── Gains conducteur / Portefeuille ─────────────────────────────────────
    (
        ['gain', 'revenu', 'argent', 'portefeuille', 'solde', 'combien je gagne',
         'retrait', 'virement', 'economie', 'mes gains', 'mon argent',
         'paiement recu', 'comment gagner', 'riche', 'richesse',
         'gagner de l\'argent', 'gagner argent', 'faire de l\'argent',
         'maximiser', 'plus de gains', 'augmenter revenus', 'bien gagner'],
        "💰 Voici comment maximiser vos gains sur Kovoit :\n\n"
        "**1. Proposez plus de trajets**\n"
        "• Plus vous conduisez, plus vous gagnez. Chaque trajet terminé = argent crédité.\n\n"
        "**2. Soignez votre note ⭐**\n"
        "• Une note élevée = plus de réservations acceptées = plus de revenus.\n"
        "• Soyez ponctuel, propre et courtois avec vos passagers.\n\n"
        "**3. Choisissez les bons créneaux**\n"
        "• Matin et soir (heures de pointe) = plus de demandes.\n"
        "• Trajets interurbains = prix plus élevés.\n\n"
        "**4. Remplissez votre véhicule**\n"
        "• Acceptez plusieurs passagers sur le même trajet = revenus multipliés.\n\n"
        "**Voir vos gains** : Mon compte → **Économie**\n\n"
        "Pour toute question sur un virement, contactez le **91 27 10 04** 📞"
    ),

    # ── Messagerie / Chat ────────────────────────────────────────────────────
    (
        ['message', 'messagerie', 'chat', 'ecrire', 'discuter', 'parler',
         'contacter le conducteur', 'contacter passager', 'envoyer message',
         'messagerie privee', 'groupe trajet'],
        "💬 Kovoit propose **2 types de messagerie** :\n\n"
        "**1. Messagerie privée** (entre 2 utilisateurs) :\n"
        "• Une conversation permanente, accessible depuis l'onglet **Messages**\n"
        "• Fonctionne même sans trajet en commun\n\n"
        "**2. Chat de groupe de trajet** :\n"
        "• Créé automatiquement à la confirmation de réservation\n"
        "• Inclut le conducteur + tous les passagers du trajet\n"
        "• Accessible depuis le détail de la réservation\n\n"
        "Fonctionnalités : texte, 🎤 messages vocaux, réactions emoji, modification, suppression ✏️"
    ),

    # ── Suivi GPS / Trajet en cours ──────────────────────────────────────────
    (
        ['suivi', 'gps', 'localisation', 'position', 'trajet en cours',
         'ou est le conducteur', 'temps reel', 'carte', 'suivre le trajet',
         'itineraire', 'navigation'],
        "📍 Kovoit propose un **suivi GPS en temps réel** !\n\n"
        "**Le passager peut :**\n"
        "• Voir la position du conducteur sur la carte\n"
        "• Suivre le déplacement du véhicule\n"
        "• Consulter l'heure d'arrivée estimée\n"
        "• Voir l'itinéraire complet\n\n"
        "**Le conducteur peut :**\n"
        "• Naviguer avec le GPS intégré\n"
        "• Voir la position des passagers avant l'embarquement\n\n"
        "Un bouton animé 🟢 apparaît dans l'app quand un trajet est en cours !"
    ),

    # ── Notation / Évaluation ────────────────────────────────────────────────
    (
        ['notation', 'evaluation', 'noter', 'note', 'avis', 'commentaire',
         'etoile', 'score', 'reputation', 'confiance', 'noter conducteur',
         'noter passager'],
        "⭐ Le système de notation Kovoit fonctionne dans les **deux sens** :\n\n"
        "• Le **passager** note le conducteur (1 à 5 étoiles + commentaire)\n"
        "• Le **conducteur** note le passager\n\n"
        "La note moyenne est visible sur **le profil public** de chaque utilisateur.\n\n"
        "💡 Une bonne note favorise l'acceptation des réservations. "
        "Soyez ponctuel, respectueux et communicatif ! 😊"
    ),

    # ── Sécurité / SOS ───────────────────────────────────────────────────────
    (
        ['securite', 'sos', 'urgence', 'danger', 'probleme pendant trajet',
         'accident', 'appel urgence', 'bouton sos', 'en danger',
         'contact urgence', 'securise'],
        "🆘 En cas d'urgence pendant un trajet :\n\n"
        "• Appuyez sur le **bouton SOS** dans l'application\n"
        "• Votre **position GPS** est envoyée automatiquement\n"
        "• Votre contact d'urgence est alerté\n\n"
        "🔒 Kovoit sécurise vos données :\n"
        "• Authentification JWT sécurisée\n"
        "• Vérification IA des documents conducteur\n"
        "• Chiffrement des données sensibles\n"
        "• Contrôle des accès par rôle\n\n"
        "Pour tout incident, contactez aussi le **91 27 10 04** 📞"
    ),

    # ── Annulation ───────────────────────────────────────────────────────────
    (
        ['annuler', 'annulation', 'cancel', 'rembours', 'remboursement',
         'je veux annuler', 'comment annuler'],
        "❌ Pour annuler une réservation :\n\n"
        "1️⃣ Allez dans **Mes réservations**\n"
        "2️⃣ Sélectionnez la réservation à annuler\n"
        "3️⃣ Tapez **Annuler la réservation**\n\n"
        "⚠️ Une **pénalité d'annulation** peut s'appliquer selon le délai.\n"
        "Le remboursement dépend des conditions de la réservation.\n\n"
        "Pour toute question sur un remboursement, contactez le **91 27 10 04** 📞"
    ),

    # ── Historique ───────────────────────────────────────────────────────────
    (
        ['historique', 'mes trajets', 'trajets passes', 'trajets effectues',
         'mes reservations', 'voir mes trajets', 'passe', 'anciens trajets'],
        "📅 Vous retrouvez tout votre historique dans l'app :\n\n"
        "**En tant que passager :**\n"
        "• Onglet **Réservations** → filtre *Terminées*\n\n"
        "**En tant que conducteur :**\n"
        "• Onglet **Trajets** → section *Historique*\n\n"
        "Vous y verrez :\n"
        "• Tous les trajets passés (dates, prix, passagers)\n"
        "• Toutes les réservations (en attente, confirmées, annulées)\n"
        "• Tous les paiements et gains reçus 💰"
    ),

    # ── Notifications ────────────────────────────────────────────────────────
    (
        ['notification', 'alerte', 'rappel', 'pas de notification',
         'je recois pas', 'activer notification'],
        "🔔 Kovoit vous envoie des notifications pour :\n\n"
        "• 📥 Nouvelle réservation reçue (conducteur)\n"
        "• ✅ Réservation acceptée ou ❌ refusée (passager)\n"
        "• 💬 Nouveau message reçu\n"
        "• 🚗 Début d'un trajet\n"
        "• 💳 Paiement effectué ou reçu\n"
        "• ⏰ Rappels de trajet\n\n"
        "Si vous ne recevez pas de notifications, vérifiez que les notifications "
        "sont **activées** dans les paramètres de votre téléphone pour l'application Kovoit."
    ),

    # ── Profil / Compte ──────────────────────────────────────────────────────
    (
        ['profil', 'mon profil', 'modifier profil', 'changer photo',
         'photo de profil', 'modifier compte', 'parametres', 'modifier informations'],
        "👤 Pour gérer votre profil :\n\n"
        "• **Modifier le profil** : Mon compte → *Mon profil* → *Modifier*\n"
        "• **Changer la photo** : Mon profil → icône appareil photo 📷\n"
        "• **Changer le mot de passe** : Mon profil → *Sécurité* → *Changer le mot de passe*\n"
        "• **Changer de rôle** (passager ↔ conducteur) : depuis le tableau de bord\n\n"
        "Vos informations sont sécurisées et chiffrées 🔒"
    ),

    # ── Changer de rôle ──────────────────────────────────────────────────────
    (
        ['changer de role', 'passer en passager', 'passer en conducteur',
         'basculer', 'switch', 'mode passager', 'changer mode'],
        "🔄 Vous pouvez facilement basculer entre les modes :\n\n"
        "• **Passager → Conducteur** : Mon compte → *Passer en mode Conducteur*\n"
        "• **Conducteur → Passager** : Mon compte → *Passer en mode Passager*\n\n"
        "⚠️ Pour passer en mode conducteur, votre compte doit être **validé conducteur** "
        "(documents soumis et approuvés)."
    ),

    # ── Véhicule ─────────────────────────────────────────────────────────────
    (
        ['vehicule', 'voiture', 'moto', 'minibus', 'camion', 'ajouter vehicule',
         'mon vehicule', 'plaque', 'immatriculation', 'enregistrer voiture'],
        "🚗 Pour ajouter ou gérer votre véhicule :\n\n"
        "• Allez dans **Mon compte → Mes véhicules**\n"
        "• Renseignez : marque, modèle, couleur, numéro de plaque\n\n"
        "**Types de véhicules acceptés :**\n"
        "• 🏍️ Moto\n"
        "• 🚗 Voiture\n"
        "• 🚌 Minibus\n"
        "• 🚛 Camion\n\n"
        "Le type de véhicule influence le **calcul automatique du prix** de vos trajets."
    ),

    # ── Escales / Étapes intermédiaires ─────────────────────────────────────
    (
        ['escale', 'etape', 'arret', 'intermediaire', 'point intermediaire',
         'monter en route', 'descendre en route', 'trajet partiel'],
        "📍 Kovoit supporte les **étapes intermédiaires** (escales) !\n\n"
        "En tant que conducteur, vous pouvez ajouter des points d'arrêt entre le départ et la destination.\n\n"
        "En tant que passager :\n"
        "• Vous pouvez **monter à n'importe quel point** du trajet du conducteur\n"
        "• Et **descendre où vous voulez** sur l'itinéraire\n\n"
        "Le système GPS calcule intelligemment la compatibilité entre votre trajet et celui du conducteur 🗺️"
    ),

    # ── Recherche intelligente GPS ───────────────────────────────────────────
    (
        ['recherche intelligente', 'gps recherche', 'trajet compatible',
         'compatibilite', 'score compatibilite', 'comment la recherche marche',
         'algorithme'],
        "🤖 La recherche de trajets Kovoit est **intelligente** :\n\n"
        "• Elle utilise les **coordonnées GPS réelles**, pas seulement les noms de villes\n"
        "• Elle analyse la géométrie de l'itinéraire du conducteur\n"
        "• Elle calcule un **score de compatibilité (%)** pour chaque trajet\n"
        "• Les résultats sont triés du plus au moins compatible\n\n"
        "Un passager peut monter et descendre à **n'importe quel point** du trajet du conducteur, "
        "même sans partager exactement le même départ ou la même destination 🗺️"
    ),

    # ── Problèmes fréquents ──────────────────────────────────────────────────

    # Conducteur absent / en retard
    (
        ['conducteur n\'arrive pas', 'conducteur en retard', 'conducteur pas la',
         'conducteur absent', 'trajet annule par conducteur', 'je l\'attends'],
        "😟 Votre conducteur n'est pas là ?\n\n"
        "1️⃣ Envoyez-lui un **message** depuis l'onglet Messages\n"
        "2️⃣ Si pas de réponse → appuyez sur **SOS** pour une assistance urgente\n"
        "3️⃣ Contactez notre support : **91 27 10 04** 📞\n\n"
        "Si le conducteur annule ou ne se présente pas, votre paiement vous sera remboursé. 💳"
    ),

    # Paiement échoué
    (
        ['paiement echoue', 'paiement rate', 'paiement refuse', 'transaction echouee',
         'erreur paiement', 'je n\'arrive pas a payer', 'probleme paiement'],
        "💳 Problème de paiement ?\n\n"
        "**Causes possibles :**\n"
        "• Solde Mobile Money insuffisant\n"
        "• Numéro de téléphone incorrect\n"
        "• Réseau instable\n\n"
        "**Solutions :**\n"
        "1️⃣ Vérifiez votre solde Flooz / Yas\n"
        "2️⃣ Vérifiez que le numéro est correct\n"
        "3️⃣ Réessayez en vous reconnectant\n"
        "4️⃣ Choisissez **Espèces** comme alternative\n\n"
        "Toujours bloqué ? Contactez le **91 27 10 04** 📞"
    ),

    # Réservation non confirmée
    (
        ['reservation pas confirmee', 'pas de confirmation', 'conducteur pas repondu',
         'en attente de confirmation', 'attendre confirmation'],
        "⏳ Votre réservation est en attente ?\n\n"
        "Le conducteur a **24 heures** pour accepter ou refuser votre demande.\n"
        "Vous recevrez une **notification** dès qu'il répond.\n\n"
        "Si 24h se sont écoulées sans réponse → contactez le support au **91 27 10 04** 📞\n"
        "Votre paiement ne sera débité qu'après confirmation."
    ),

    # Application lente / bug
    (
        ['application lente', 'app lente', 'bug', 'plante', 'crash',
         'ne fonctionne pas', 'probleme app', 'application ne marche pas',
         'bloque', 'freeze', 'gelée'],
        "📱 L'application pose problème ?\n\n"
        "**Essayez ces solutions :**\n"
        "1️⃣ Vérifiez votre **connexion internet** (WiFi ou données mobiles)\n"
        "2️⃣ **Fermez et relancez** l'application\n"
        "3️⃣ **Redémarrez** votre téléphone\n"
        "4️⃣ Vérifiez si une **mise à jour** est disponible dans le store\n"
        "5️⃣ Désinstallez et réinstallez l'application\n\n"
        "Problème persistant ? Contactez le support : **91 27 10 04** 📞"
    ),

    # QR Code ne marche pas
    (
        ['qr code ne marche pas', 'qr ne fonctionne pas', 'scan impossible',
         'scanner ne marche pas', 'code non reconnu'],
        "📱 QR Code non reconnu ?\n\n"
        "**Solution immédiate :**\n"
        "Demandez au conducteur de saisir **manuellement** votre code **KVT-XXXX** "
        "(affiché sous le QR Code dans l'application).\n\n"
        "Cela fonctionne exactement comme le QR Code — votre embarquement sera validé ✅"
    ),

    # ── Contact / Support ────────────────────────────────────────────────────
    (
        ['contact', 'support', 'joindre', 'appeler', 'numero',
         'telephone', 'email', 'aide', 'service client', 'whatsapp',
         'comment vous contacter', 'parler a quelqu\'un', 'humain'],
        "📞 Pour contacter l'équipe Kovoit :\n\n"
        "• **Téléphone / WhatsApp** : **91 27 10 04**\n"
        "• **Email** : **gominaeloge@gmail.com**\n\n"
        "Notre équipe est disponible pour vous aider avec toutes vos questions. "
        "N'hésitez pas à nous écrire ! 😊"
    ),

    # ── Télécharger l'application ────────────────────────────────────────────
    (
        ['telecharger', 'download', 'installer l\'app', 'installer application',
         'ou telecharger', 'play store', 'app store', 'android', 'ios'],
        "📲 Téléchargez l'application **Kovoit** :\n\n"
        "• 🤖 **Android** : Google Play Store — recherchez *Kovoit*\n"
        "• 🍎 **iOS** : App Store — recherchez *Kovoit*\n\n"
        "L'application est **gratuite** ! 🎉\n"
        "Pour toute difficulté d'installation, contactez le **91 27 10 04** 📞"
    ),

    # ── Intelligence artificielle / IA ───────────────────────────────────────
    (
        ['intelligence artificielle', 'ia', 'ia kovoit', 'technologie',
         'comment ca marche', 'algorithme ia', 'verification ia'],
        "🤖 Kovoit utilise l'IA à plusieurs niveaux :\n\n"
        "• **Vérification des documents** : les permis et cartes grises sont analysés automatiquement\n"
        "• **Assistant Kovi** : c'est moi ! Je réponds à vos questions 24h/24 😊\n"
        "• **Recherche intelligente** : algorithme GPS pour trouver les trajets compatibles\n"
        "• **Réalité augmentée** : pour guider les utilisateurs\n\n"
        "La technologie au service d'un transport plus sûr et plus facile ! 🚀"
    ),

    # ── Remerciements / Bonne réponse ────────────────────────────────────────
    (
        ['merci', 'super', 'parfait', 'nickel', 'top', 'genial',
         'tres bien', 'excellent', 'bravo', 'chapeau', 'bien joue',
         'ca m\'aide', 'c\'est utile', 'ca repond', 'thanks', 'thank you'],
        "Avec plaisir ! 😊 Je suis là pour vous aider.\n"
        "N'hésitez pas si vous avez d'autres questions sur Kovoit !"
    ),

    # ── Au revoir ────────────────────────────────────────────────────────────
    (
        ['au revoir', 'bye', 'a bientot', 'a plus', 'bonne journee',
         'bonne soiree', 'bonne nuit', 'salut bye', 'ciao', 'tchao',
         'a tout a l\'heure', 'a la prochaine'],
        "Au revoir ! 👋 Bonne route sur Kovoit !\n"
        "N'hésitez pas à revenir si vous avez des questions. À bientôt ! 🚗"
    ),

    # ── Oui / Non / D'accord ─────────────────────────────────────────────────
    (
        ['d\'accord', 'ok', 'okay', 'compris', 'je comprends', 'j\'ai compris',
         'entendu', 'c\'est bon', 'vu', 'bien recu'],
        "Parfait ! 👍 N'hésitez pas si vous avez d'autres questions !"
    ),

    # ── Insultes / Frustration (réponse douce) ───────────────────────────────
    (
        ['nul', 'inutile', 'pas utile', 'mauvais', 'horrible', 'naze',
         'c\'est nul', 'vous servez a rien'],
        "Je suis désolé de ne pas avoir pu vous aider comme vous l'espériez. 😔\n\n"
        "Pour une assistance directe, contactez notre équipe :\n"
        "• 📞 **91 27 10 04**\n"
        "• 📧 **gominaeloge@gmail.com**\n\n"
        "Nous ferons de notre mieux pour résoudre votre problème rapidement."
    ),

]


def _normalize(text: str) -> str:
    """Minuscules + suppression des accents courants pour la comparaison."""
    text = text.lower().strip()
    accents = {
        'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
        'à': 'a', 'â': 'a', 'ä': 'a',
        'ù': 'u', 'û': 'u', 'ü': 'u',
        'ô': 'o', 'ö': 'o',
        'î': 'i', 'ï': 'i',
        'ç': 'c', 'ñ': 'n',
    }
    for a, b in accents.items():
        text = text.replace(a, b)
    return text


def find_rule_response(message: str) -> str | None:
    """
    Cherche une réponse dans les règles prédéfinies.
    Retourne la réponse si une règle correspond, sinon None (→ l'IA prend le relais).
    """
    normalized = _normalize(message)

    for keywords, response in _RULES:
        for kw in keywords:
            if _normalize(kw) in normalized:
                return response

    return None
