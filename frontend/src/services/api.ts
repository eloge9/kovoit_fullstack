const API_URL = process.env.NEXT_PUBLIC_API_URL ?? "http://127.0.0.1:8000/api";

// Un seul rafraîchissement à la fois — évite plusieurs appels concurrents
let refreshPromise: Promise<string | null> | null = null;

const tryRefreshToken = async (): Promise<string | null> => {
  if (refreshPromise) return refreshPromise;

  refreshPromise = (async () => {
    try {
      const refresh = localStorage.getItem("refresh");
      if (!refresh) return null;

      const res = await fetch(`${API_URL}/utilisateurs/auth/refresh/`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ refresh }),
      });

      if (!res.ok) {
        // Refresh token invalide ou expiré — déconnexion forcée
        localStorage.removeItem("token");
        localStorage.removeItem("refresh");
        localStorage.removeItem("user_role");
        return null;
      }

      const data = await res.json();
      if (data.access) {
        localStorage.setItem("token", data.access);
        // Si le backend renvoie aussi un nouveau refresh token
        if (data.refresh) localStorage.setItem("refresh", data.refresh);
        return data.access;
      }
      return null;
    } catch {
      return null;
    } finally {
      refreshPromise = null;
    }
  })();

  return refreshPromise;
};

export const api = async (
  endpoint: string,
  method: string = "GET",
  body?: any,
  token?: string | null,   // null = endpoint public, pas de token envoyé
) => {
  // null → endpoint public (inscription, connexion) : on n'envoie pas de token
  // undefined → endpoint privé : on cherche dans localStorage
  const getToken = () =>
    token === null ? null : (token || localStorage.getItem("token"));

  const isFormData = body instanceof FormData;

  const buildInit = (accessToken: string | null): RequestInit => ({
    method,
    headers: {
      ...(!isFormData && { "Content-Type": "application/json" }),
      ...(accessToken && { Authorization: `Bearer ${accessToken}` }),
    },
    body: body ? (isFormData ? body : JSON.stringify(body)) : undefined,
  });

  let res = await fetch(`${API_URL}${endpoint}`, buildInit(getToken()));

  // Token expiré et endpoint privé → tenter le rafraîchissement puis rejouer
  if (res.status === 401 && token !== null) {
    const newToken = await tryRefreshToken();
    if (newToken) {
      res = await fetch(`${API_URL}${endpoint}`, buildInit(newToken));
    }
  }

  let data: any;
  try {
    data = await res.json();
  } catch {
    data = {};
  }

  if (!res.ok) {
    const error: any = new Error("Erreur API");
    error.response = { data, status: res.status };
    throw error;
  }

  return data;
};
