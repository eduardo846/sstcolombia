const BASE = import.meta.env.VITE_API_URL ?? '/api';
const TOKEN_KEY = 'sgsst_token';

let onUnauthorized = () => {};
export const setUnauthorizedHandler = fn => { onUnauthorized = fn; };
export const getToken = () => localStorage.getItem(TOKEN_KEY);
export const saveToken = t => (t ? localStorage.setItem(TOKEN_KEY, t) : localStorage.removeItem(TOKEN_KEY));

// Traduce los errores de PostgreSQL/PostgREST a mensajes accionables
function mensajeError(err, status) {
  if (!err) return `Error ${status} del servidor`;
  switch (err.code) {
    case '23505': return 'Ya existe un registro con esos datos. Revisa los campos únicos (documento, código, año).';
    case '23503': return 'No se puede completar: el registro está relacionado con otros datos.';
    case '23502': return `Falta un campo obligatorio: ${err.message}`;
    case '23514': return `Un valor no cumple las reglas: ${err.message}`;
    case '42501': return 'Tu rol no tiene permiso para esta acción.';
    case '22P02': case '22007': case '22008': return 'Un valor tiene un formato no válido (número o fecha).';
    default: return err.message || `Error ${status} del servidor`;
  }
}

export async function request(path, { method = 'GET', body, prefer } = {}) {
  const headers = { 'Content-Type': 'application/json' };
  const token = getToken();
  if (token) headers.Authorization = `Bearer ${token}`;
  if (prefer) headers.Prefer = prefer;
  const res = await fetch(`${BASE}${path}`, {
    method, headers, body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  let data = null;
  try { data = text ? JSON.parse(text) : null; } catch { data = { message: text }; }
  if (res.status === 401 && token) {
    onUnauthorized();
    throw new Error('La sesión expiró. Inicia sesión de nuevo.');
  }
  if (!res.ok) throw new Error(mensajeError(data, res.status));
  return data;
}

export const api = {
  list: (table, query = '') => request(`/${table}${query ? `?${query}` : ''}`),
  one: async (table, query = '') => (await request(`/${table}?${query}&limit=1`))[0] ?? null,
  create: (table, row) => request(`/${table}`, { method: 'POST', body: row, prefer: 'return=representation' }),
  update: (table, id, row) => request(`/${table}?id=eq.${id}`, { method: 'PATCH', body: row, prefer: 'return=representation' }),
  remove: (table, id) => request(`/${table}?id=eq.${id}`, { method: 'DELETE' }),
  rpc: (fn, args = {}) => request(`/rpc/${fn}`, { method: 'POST', body: args }),
};

export function descargarCSV(nombre, columnas, filas) {
  const esc = v => {
    const s = v == null ? '' : String(v);
    return /[;"\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
  };
  const csv = [columnas.map(c => esc(c.label)).join(';'),
    ...filas.map(f => columnas.map(c => esc(c.value(f))).join(';'))].join('\n');
  const url = URL.createObjectURL(new Blob(['\ufeff' + csv], { type: 'text/csv;charset=utf-8' }));
  const a = Object.assign(document.createElement('a'), { href: url, download: `${nombre}.csv` });
  a.click();
  URL.revokeObjectURL(url);
}

export const fmtFecha = v => (v && /^\d{4}-\d{2}-\d{2}/.test(v) ? v.slice(0, 10).split('-').reverse().join('/') : v ?? '');
export const hoy = () => new Date().toISOString().slice(0, 10);
