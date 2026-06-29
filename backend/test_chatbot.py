"""
Script de diagnostic du chatbot Kovi.
Lancer depuis le dossier backend/ :
    python test_chatbot.py
"""
import os
import sys
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'backend.settings')
sys.path.insert(0, os.path.dirname(__file__))
django.setup()

from django.conf import settings

print("=" * 60)
print("DIAGNOSTIC CHATBOT KOVI")
print("=" * 60)

# 1. Vérifier les clés API
gemini_key = settings.GEMINI_API_KEY_CHATBOT
anthropic_key = settings.ANTHROPIC_API_KEY
print(f"\n[1] Clés API :")
print(f"    GEMINI_API_KEY_CHATBOT  : {'OK (' + gemini_key[:10] + '...)' if gemini_key else 'MANQUANTE ❌'}")
print(f"    ANTHROPIC_API_KEY       : {'OK (' + anthropic_key[:10] + '...)' if anthropic_key else 'MANQUANTE ❌'}")

# 2. Vérifier les imports
print(f"\n[2] Imports Python :")
try:
    import google.generativeai as genai
    print(f"    google-generativeai : OK ✓ (version {genai.__version__})")
except ImportError as e:
    print(f"    google-generativeai : ABSENT ❌  → pip install google-generativeai")

try:
    import anthropic
    print(f"    anthropic           : OK ✓ (version {anthropic.__version__})")
except ImportError as e:
    print(f"    anthropic           : ABSENT ❌  → pip install anthropic")

# 3. Test Gemini
print(f"\n[3] Test Gemini :")
if not gemini_key:
    print("    Ignoré (clé absente)")
else:
    try:
        import google.generativeai as genai
        genai.configure(api_key=gemini_key)
        model = genai.GenerativeModel("gemini-1.5-flash")
        resp = model.generate_content("Dis juste 'OK'")
        print(f"    Réponse : {resp.text.strip()[:80]} ✓")
    except Exception as e:
        print(f"    ÉCHEC ❌ — {type(e).__name__}: {e}")

# 4. Test Claude
print(f"\n[4] Test Claude :")
if not anthropic_key:
    print("    Ignoré (clé absente)")
else:
    try:
        import anthropic as ant
        client = ant.Anthropic(api_key=anthropic_key)
        resp = client.messages.create(
            model="claude-haiku-4-5-20251001",
            max_tokens=10,
            messages=[{"role": "user", "content": "Dis juste 'OK'"}],
        )
        print(f"    Réponse : {resp.content[0].text.strip()[:80]} ✓")
    except Exception as e:
        print(f"    ÉCHEC ❌ — {type(e).__name__}: {e}")

print("\n" + "=" * 60)
