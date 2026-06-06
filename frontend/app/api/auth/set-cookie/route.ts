import { NextRequest, NextResponse } from 'next/server';

const ACCESS_TTL_SECONDS = 15 * 60; // doit correspondre à ACCESS_TOKEN_LIFETIME Django

export async function POST(request: NextRequest) {
    let access: string;
    try {
        const body = await request.json();
        access = body.access;
        if (!access || typeof access !== 'string') throw new Error();
    } catch {
        return NextResponse.json({ error: 'Token manquant.' }, { status: 400 });
    }

    const response = NextResponse.json({ ok: true });
    response.cookies.set('access_token', access, {
        httpOnly: true,                                      // inaccessible depuis JS → protège contre XSS
        secure: process.env.NODE_ENV === 'production',       // HTTPS uniquement en prod
        sameSite: 'lax',                                     // protection CSRF de base
        maxAge: ACCESS_TTL_SECONDS,
        path: '/',
    });
    return response;
}
