"use client";

import { createContext, useEffect, useState } from "react";
import { getMe } from "../services/auth.service";

interface AuthContextType {
    user: any;
    token: string | null;
    loading: boolean;
    login: (data: any) => Promise<void>;
    logout: () => Promise<void>;
    updateUser: (userData: any, newToken?: string, newRefresh?: string) => void;
}

export const AuthContext = createContext<AuthContextType | null>(null);

export const AuthProvider = ({ children }: any) => {
    const [user, setUser]       = useState<any>(null);
    const [token, setToken]     = useState<string | null>(null);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        const storedToken = localStorage.getItem("token");
        if (storedToken) {
            setToken(storedToken);
            getMe(storedToken)
                .then((data) => setUser(data))
                .catch(() => {
                    localStorage.removeItem("token");
                    localStorage.removeItem("refresh");
                    localStorage.removeItem("user_role");
                })
                .finally(() => setLoading(false));
        } else {
            setLoading(false);
        }
    }, []);

    const login = async (data: any) => {
        setToken(data.tokens.access);
        setUser(data.utilisateur);
        localStorage.setItem("token", data.tokens.access);
        localStorage.setItem("refresh", data.tokens.refresh);
        localStorage.setItem("user_role", data.utilisateur.role);
        try {
            await fetch("/api/auth/set-cookie", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ access: data.tokens.access }),
            });
        } catch { }
    };

    const logout = async () => {
        setToken(null);
        setUser(null);
        localStorage.removeItem("token");
        localStorage.removeItem("refresh");
        localStorage.removeItem("user_role");
        await fetch("/api/auth/logout", { method: "POST" });
    };

    /**
     * Met à jour l'utilisateur en mémoire + localStorage après un changement de mode.
     * Si newToken est fourni, remplace aussi le token JWT (rôle mis à jour dans le JWT).
     */
    const updateUser = (userData: any, newToken?: string, newRefresh?: string) => {
        setUser(userData);
        localStorage.setItem("user_role", userData.role);
        if (newToken) {
            setToken(newToken);
            localStorage.setItem("token", newToken);
        }
        if (newRefresh) {
            localStorage.setItem("refresh", newRefresh);
        }
    };

    return (
        <AuthContext.Provider value={{ user, token, loading, login, logout, updateUser }}>
            {children}
        </AuthContext.Provider>
    );
};
