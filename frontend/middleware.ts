import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

export function middleware(request: NextRequest) {
    const token = request.cookies.get('access_token')?.value;
    const path = request.nextUrl.pathname;

    // Routes protégées sans token → redirect connexion
    if (!token) {
        return NextResponse.redirect(new URL('/auth/connexion', request.url));
    }

    // Vérification du rôle via le cookie rôle qu'on va sauvegarder
    const role = request.cookies.get('user_role')?.value;

    if (path.startsWith('/conducteur') && role !== 'conducteur') {
        return NextResponse.redirect(new URL('/auth/connexion', request.url));
    }
    if (path.startsWith('/passager') && role !== 'passager') {
        return NextResponse.redirect(new URL('/auth/connexion', request.url));
    }
    if (path.startsWith('/admin') && role !== 'admin') {
        return NextResponse.redirect(new URL('/auth/connexion', request.url));
    }

    return NextResponse.next();
}

export const config = {
    matcher: ['/conducteur/:path*', '/passager/:path*', '/admin/:path*'],
};