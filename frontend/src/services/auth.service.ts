import { api } from "./api";

// null comme 4e argument = pas d'Authorization envoyée (endpoints publics)
// Cela évite qu'un token expiré en localStorage bloque l'inscription/connexion

export const inscription = async (data: FormData) => {
  const res = await api("/utilisateurs/auth/inscription/", "POST", data, null);
  return res;
};

export const connexion = async (data: { email: string; password: string }) => {
  const res = await api("/utilisateurs/auth/connexion/", "POST", data, null);
  return res;
};

export const deconnexion = (refresh: string) =>
  api("/utilisateurs/auth/deconnexion/", "POST", { refresh });

export const getMe = (token: string) =>
  api("/utilisateurs/ko/profil/", "GET", undefined, token);

export const changePassword = (data: {
  current_password: string;
  new_password: string;
  new_password2: string;
}) => api("/utilisateurs/ko/profil/change-password/", "POST", data);

export const motDePasseOublie = (email: string) =>
  api("/utilisateurs/auth/mot-de-passe-oublie/", "POST", { email });

export const reinitialisation = (data: {
  uid: string;
  token: string;
  new_password: string;
  new_password2: string;
}) => api("/utilisateurs/auth/reinitialisation/", "POST", data);
