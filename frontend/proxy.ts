import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';
import { jwtVerify } from 'jose';

const PUBLIC_ROUTES = [
    '/auth/connexion',
    '/auth/inscription',
    '/auth/mot-de-passe-oublie',
    '/auth/reinitialisation',
    '/',
];

// Routes conducteur dont l'accès est limité selon le statut (géré côté page)
// La vérification, les documents et le statut sont accessibles même sans être ACTIVE

// Rôles autorisés par préfixe de route
const ROLE_ROUTES: Record<string, string[]> = {
    '/admin':      ['admin'],
    '/conducteur': ['conducteur', 'admin'],
    '/passager':   ['passager', 'conducteur', 'admin'],
};

function getSecret(): Uint8Array {
    const secret = process.env.JWT_SECRET;
    if (!secret) throw new Error('JWT_SECRET non configuré');
    return new TextEncoder().encode(secret);
}

export async function proxy(request: NextRequest) {
    const { pathname } = request.nextUrl;

    // Routes publiques : laisser passer sans vérification
    if (PUBLIC_ROUTES.some(r => pathname === r || pathname.startsWith(r + '/'))) {
        return NextResponse.next();
    }

    const token = request.cookies.get('access_token')?.value;

    if (!token) {
        const loginUrl = new URL('/auth/connexion', request.url);
        loginUrl.searchParams.set('redirect', pathname);
        return NextResponse.redirect(loginUrl);
    }

    try {
        // Vérification cryptographique du JWT (signature + expiration)
        const { payload } = await jwtVerify(token, getSecret(), {
            algorithms: ['HS256'],
        });

        const role = payload['role'] as string | undefined;
        const peutConduire = payload['peut_conduire'] as boolean | undefined;

        // Token sans claim de rôle = ancien token généré avant la correction → rejeter
        if (!role) throw new Error('claim role absent');

        // Vérification des droits par route
        for (const [prefix, allowedRoles] of Object.entries(ROLE_ROUTES)) {
            if (!pathname.startsWith(prefix)) continue;

            // Un passager avec peut_conduire peut accéder aux routes /conducteur
            const roleEffectif =
                prefix === '/conducteur' && peutConduire ? 'conducteur' : role;

            if (!allowedRoles.includes(roleEffectif)) {
                return NextResponse.redirect(new URL('/auth/connexion', request.url));
            }
        }

        // Injecter les infos dans les headers pour les Server Components
        const response = NextResponse.next();
        response.headers.set('x-user-id', String(payload['user_id'] ?? ''));
        response.headers.set('x-user-role', role);
        return response;

    } catch (err) {
        // Erreur de config serveur (JWT_SECRET absent) : ne pas supprimer le cookie
        if (err instanceof Error && err.message === 'JWT_SECRET non configuré') {
            console.error('[middleware] JWT_SECRET manquant dans .env.local — vérifiez la configuration.');
            return NextResponse.next();
        }
        // Token expiré, signature invalide ou claim manquant → déconnexion propre
        const response = NextResponse.redirect(new URL('/auth/connexion', request.url));
        response.cookies.delete('access_token');
        return response;
    }
}

export const config = {
    matcher: ['/((?!_next/static|_next/image|favicon.ico|api/).*)'],
};
