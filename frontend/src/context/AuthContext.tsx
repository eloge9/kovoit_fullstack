"use client";

import { createContext, useEffect, useState } from "react";
import { getMe } from "../services/auth.service";

interface AuthContextType {
    user: any;
    token: string | null;
    login: (data: any) => void;
    logout: () => void;
}

export const AuthContext = createContext<AuthContextType | null>(null);

export const AuthProvider = ({ children }: any) => {
    const [user, setUser] = useState<any>(null);
    const [token, setToken] = useState<string | null>(null);

    useEffect(() => {
        const storedToken = localStorage.getItem("token");
        if (storedToken) {
            // Restaure les cookies si localStorage a encore le token
            document.cookie = `access_token=${storedToken}; path=/; max-age=3600`;
            const storedRole = localStorage.getItem("user_role");
            if (storedRole) {
                document.cookie = `user_role=${storedRole}; path=/; max-age=604800`;
            }

            setToken(storedToken);
            getMe(storedToken)
                .then((data) => setUser(data))
                .catch(() => {
                    localStorage.removeItem("token");
                    localStorage.removeItem("user");
                    document.cookie = "access_token=; path=/; max-age=0";
                    document.cookie = "user_role=; path=/; max-age=0";
                });
        } else {
            setLoading(false);
        }
    }, []);

    const login = (data: any) => {
        setToken(data.tokens.access);
        setUser(data.utilisateur);

        // localStorage
        localStorage.setItem("token", data.tokens.access);
        localStorage.setItem("refresh", data.tokens.refresh);
        localStorage.setItem("user_role", data.utilisateur.role);

        // Cookies pour le middleware
        document.cookie = `access_token=${data.tokens.access}; path=/; max-age=3600`;
        document.cookie = `user_role=${data.utilisateur.role}; path=/; max-age=604800`;
    };

    const logout = () => {
        setToken(null);
        setUser(null);

        localStorage.removeItem("token");
        localStorage.removeItem("refresh");
        localStorage.removeItem("user_role");

        // Supprime les cookies
        document.cookie = "access_token=; path=/; max-age=0";
        document.cookie = "user_role=; path=/; max-age=0";
    };

    return (
        <AuthContext.Provider value={{ user, token, login, logout }}>
            {children}
        </AuthContext.Provider>
    );
};