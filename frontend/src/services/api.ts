const API_URL = "http://127.0.0.1:8000/api";

export const api = async (
  endpoint: string,
  method: string = "GET",
  body?: any,
  token?: string,
) => {
  // Récupère le token depuis localStorage si non fourni
  const authToken = token || localStorage.getItem("token");

  const isFormData = body instanceof FormData;

  const res = await fetch(`${API_URL}${endpoint}`, {
    method,
    headers: {
      ...(!isFormData && { "Content-Type": "application/json" }),
      ...(authToken && { Authorization: `Bearer ${authToken}` }),
    },
    body: body ? (isFormData ? body : JSON.stringify(body)) : undefined,
  });

  const data = await res.json();

  if (!res.ok) {
    const error: any = new Error("Erreur API");
    error.response = { data, status: res.status };
    throw error;
  }

  return data;
};
