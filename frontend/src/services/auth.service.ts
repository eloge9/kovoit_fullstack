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

export const changerMode = () =>
  api("/utilisateurs/ko/changer-mode/", "POST", {});

export const initierConducteur = (data: {
  numero_permis: string;
  experience_annees: number;
  type_vehicule: string;
  marque: string;
  modele: string;
  couleur: string;
  plaque: string;
}) => api("/utilisateurs/ko/basculer-role/", "POST", data);

export const demanderCodeReset = (email: string) =>
  api("/utilisateurs/auth/demander-code/", "POST", { email }, null);

export const reinitialisation = (data: {
  email: string;
  code: string;
  new_password: string;
  new_password2: string;
}) => api("/utilisateurs/auth/reinitialisation/", "POST", data, null);
