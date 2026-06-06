"use client";

import { createContext, useEffect, useState } from "react";
import { getMe } from "../services/auth.service";

interface AuthContextType {
    user: any;
    token: string | null;
    loading: boolean;
    login: (data: any) => Promise<void>;
    logout: () => Promise<void>;
}

export const AuthContext = createContext<AuthContextType | null>(null);

export const AuthProvider = ({ children }: any) => {
    const [user, setUser]       = useState<any>(null);
    const [token, setToken]     = useState<string | null>(null);
    const [loading, setLoading] = useState(true);

    // Restaurer la session React depuis localStorage au montage
    useEffect(() => {
        const storedToken = localStorage.getItem("token");
        if (storedToken) {
            setToken(storedToken);
            getMe(storedToken)
                .then((data) => setUser(data))
                .catch(() => {
                    // Token localStorage expiré ou invalide : nettoyer tout
                    localStorage.removeItem("token");
                    localStorage.removeItem("refresh");
                    localStorage.removeItem("user_role");
                })
                .finally(() => setLoading(false));
        } else {
            setLoading(false);
        }
    }, []);

    /**
     * Appelé après une connexion réussie.
     * data = { tokens: { access, refresh }, utilisateur }
     * Le cookie httpOnly est posé côté serveur via /api/auth/set-cookie.
     */
    const login = async (data: any) => {
        setToken(data.tokens.access);
        setUser(data.utilisateur);
        localStorage.setItem("token", data.tokens.access);
        localStorage.setItem("refresh", data.tokens.refresh);
        localStorage.setItem("user_role", data.utilisateur.role);

        // Poser le cookie httpOnly (inaccessible depuis JS, protège contre XSS)
        await fetch("/api/auth/set-cookie", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ access: data.tokens.access }),
        });
    };

    const logout = async () => {
        setToken(null);
        setUser(null);
        localStorage.removeItem("token");
        localStorage.removeItem("refresh");
        localStorage.removeItem("user_role");

        // Supprimer le cookie httpOnly côté serveur
        await fetch("/api/auth/logout", { method: "POST" });
    };

    return (
        <AuthContext.Provider value={{ user, token, loading, login, logout }}>
            {children}
        </AuthContext.Provider>
    );
};
