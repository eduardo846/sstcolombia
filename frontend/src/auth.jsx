import { createContext, useContext, useEffect, useState, useCallback } from 'react';
import { api, getToken, saveToken, setUnauthorizedHandler } from './api.js';

const AuthCtx = createContext(null);

function decode(token) {
  try {
    const b64 = token.split('.')[1].replace(/-/g, '+').replace(/_/g, '/');
    const json = new TextDecoder().decode(Uint8Array.from(atob(b64), c => c.charCodeAt(0)));
    const claims = JSON.parse(json);
    return claims.exp * 1000 > Date.now() ? claims : null;
  } catch { return null; }
}

export function AuthProvider({ children }) {
  const [user, setUser] = useState(() => {
    const t = getToken();
    return t ? decode(t) : null;
  });

  const logout = useCallback(() => { saveToken(null); setUser(null); }, []);
  useEffect(() => setUnauthorizedHandler(logout), [logout]);

  async function login(email, password) {
    const { token } = await api.rpc('login', { email, password });
    saveToken(token);
    setUser(decode(token));
  }

  const puedeEscribir = !!user && ['admin', 'responsable_sst', 'copasst'].includes(user.app_rol);
  return <AuthCtx.Provider value={{ user, login, logout, puedeEscribir }}>{children}</AuthCtx.Provider>;
}

export const useAuth = () => useContext(AuthCtx);
