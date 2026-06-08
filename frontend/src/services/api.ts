const API_URL = process.env.NEXT_PUBLIC_API_URL ?? "http://127.0.0.1:8000/api";

export const api = async (
  endpoint: string,
  method: string = "GET",
  body?: any,
  token?: string | null,   // null = endpoint public, pas de token envoyé
) => {
  // null → endpoint public (inscription, connexion) : on n'envoie pas de token
  // undefined → endpoint privé : on cherche dans localStorage
  const authToken = token === null ? null : (token || localStorage.getItem("token"));

  const isFormData = body instanceof FormData;

  const res = await fetch(`${API_URL}${endpoint}`, {
    method,
    headers: {
      ...(!isFormData && { "Content-Type": "application/json" }),
      ...(authToken && { Authorization: `Bearer ${authToken}` }),
    },
    body: body ? (isFormData ? body : JSON.stringify(body)) : undefined,
  });

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
