import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';
import { jwtVerify } from 'jose';

// Routes publiques qui ne nécessitent AUCUNE vérification
const PUBLIC_ROUTES = [
  '/auth/connexion',
  '/auth/inscription',
  '/auth/forgot-password',
  '/auth/reset-password',
  '/', // page d'accueil
  '/api/auth', // endpoints d'authentification
];

// Routes protégées par rôle
const ROLE_PROTECTED_ROUTES = {
  '/conducteur': 'conducteur',
  '/passager': 'passager',
  '/admin': 'admin',
};

export async function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;

  // 1. Laisser passer les routes publiques (IMPORTANT pour éviter la boucle de redirection sur /login)
  if (PUBLIC_ROUTES.some(route => pathname === route || pathname.startsWith(route + '/'))) {
    return NextResponse.next();
  }

  // 2. Récupérer le token JWT
  const token = request.cookies.get('access_token')?.value;

  if (!token) {
    // Pas de token → redirection vers la page de connexion
    const loginUrl = new URL('/auth/connexion', request.url);
    loginUrl.searchParams.set('redirect', pathname);
    return NextResponse.redirect(loginUrl);
  }

  // 3. Valider le JWT côté serveur (Edge Runtime compatible)
  try {
    const secret = new TextEncoder().encode(process.env.JWT_SECRET || process.env.NEXT_PUBLIC_JWT_SECRET);
    
    const { payload } = await jwtVerify(token, secret);

    // 4. Vérification des rôles pour les routes protégées
    const userRole = payload.role as string; // Le rôle doit être dans les claims du JWT

    for (const [routePrefix, requiredRole] of Object.entries(ROLE_PROTECTED_ROUTES)) {
      if (pathname.startsWith(routePrefix)) {
        // Admin peut tout voir, sinon le rôle doit correspondre exactement
        if (userRole !== requiredRole && userRole !== 'admin') {
          return NextResponse.redirect(new URL('/unauthorized', request.url));
        }
      }
    }

    // 5. Optionnel : Injecter les infos utilisateur dans les headers pour les Server Components
    const response = NextResponse.next();
    response.headers.set('x-user-id', String(payload.user_id || payload.sub || ''));
    response.headers.set('x-user-role', userRole);
    
    return response;

  } catch (error) {
    // Token invalide, expiré ou malformé
    console.error('JWT validation failed:', error);
    
    // Supprimer le cookie invalide
    const response = NextResponse.redirect(new URL('/auth/connexion', request.url));
    response.cookies.delete('access_token');
    response.cookies.delete('user_role'); // Supprimer aussi l'ancien cookie non sécurisé
    return response;
  }
}

export const config = {
  // Matcher toutes les routes SAUF les assets statiques de Next.js
  matcher: ['/((?!_next/static|_next/image|favicon.ico|api/auth).*)'],
};