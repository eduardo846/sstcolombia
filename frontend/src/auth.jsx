import { createContext, useContext, useEffect, useState, useCallback } from 'react';
import { api, getToken, saveToken, setUnauthorizedHandler } from './api.js';

const AuthCtx = createContext(null);

// Cierre de sesión por inactividad. La última actividad se guarda en localStorage
// para que todas las pestañas abiertas compartan el mismo reloj.
const INACTIVIDAD_MS = 10 * 60 * 1000;
const ACTIVIDAD_KEY = 'sgsst_actividad';
const EVENTOS = ['pointerdown', 'pointermove', 'keydown', 'wheel', 'touchstart', 'scroll'];

const leerActividad = () => Number(localStorage.getItem(ACTIVIDAD_KEY)) || 0;
const marcarActividad = () => localStorage.setItem(ACTIVIDAD_KEY, String(Date.now()));
const inactivo = () => Date.now() - leerActividad() > INACTIVIDAD_MS;

function decode(token) {
  try {
    const b64 = token.split('.')[1].replace(/-/g, '+').replace(/_/g, '/');
    const json = new TextDecoder().decode(Uint8Array.from(atob(b64), c => c.charCodeAt(0)));
    const claims = JSON.parse(json);
    return claims.exp * 1000 > Date.now() ? claims : null;
  } catch { return null; }
}

export function AuthProvider({ children }) {
  // Al volver al sitio tras más de 10 minutos, la sesión guardada ya no vale
  const [motivo, setMotivo] = useState(() => (getToken() && inactivo() ? 'inactividad' : null));
  const [user, setUser] = useState(() => {
    const t = getToken();
    if (!t) return null;
    if (inactivo()) { saveToken(null); return null; }
    return decode(t);
  });

  const logout = useCallback((razon = null) => {
    saveToken(null);
    setUser(null);
    setMotivo(typeof razon === 'string' ? razon : null);
  }, []);
  useEffect(() => setUnauthorizedHandler(logout), [logout]);

  useEffect(() => {
    if (!user) return undefined;
    let ultimaEscritura = 0;
    const registrar = () => {
      const ahora = Date.now();
      if (ahora - ultimaEscritura > 5000) { ultimaEscritura = ahora; marcarActividad(); }
    };
    const revisar = () => { if (inactivo()) logout('inactividad'); };

    EVENTOS.forEach(ev => window.addEventListener(ev, registrar, { passive: true, capture: true }));
    // Los navegadores frenan los temporizadores en pestañas ocultas: se revisa también al volver
    document.addEventListener('visibilitychange', revisar);
    const reloj = setInterval(revisar, 15000);
    return () => {
      EVENTOS.forEach(ev => window.removeEventListener(ev, registrar, { capture: true }));
      document.removeEventListener('visibilitychange', revisar);
      clearInterval(reloj);
    };
  }, [user, logout]);

  async function login(email, password) {
    const { token } = await api.rpc('login', { email, password });
    marcarActividad();
    saveToken(token);
    setMotivo(null);
    setUser(decode(token));
  }

  const puedeEscribir = !!user && ['admin', 'responsable_sst', 'copasst'].includes(user.app_rol);
  return <AuthCtx.Provider value={{ user, login, logout, motivo, puedeEscribir }}>{children}</AuthCtx.Provider>;
}

export const useAuth = () => useContext(AuthCtx);
