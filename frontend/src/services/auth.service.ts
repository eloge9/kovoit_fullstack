import { api } from "./api";

export const inscription = async (data: FormData) => {
  const res = await api("/utilisateurs/auth/inscription/", "POST", data);
  // res = { message, utilisateur, tokens }
  return res;
};

export const connexion = async (data: { email: string; password: string }) => {
  const res = await api("/utilisateurs/auth/connexion/", "POST", data);
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
