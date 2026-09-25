import { useState } from 'react';
import { useAuth } from '../auth.jsx';

export default function Login() {
  const { login } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [enviando, setEnviando] = useState(false);

  async function entrar(e) {
    e.preventDefault();
    setEnviando(true); setError('');
    try { await login(email, password); }
    catch (err) { setError(err.message); }
    finally { setEnviando(false); }
  }

  return (
    <div className="login">
      <form className="login-card" onSubmit={entrar}>
        <span className="brand-mark big" aria-hidden="true" />
        <h1>Sistema de Gestión de Seguridad y Salud en el Trabajo</h1>
        <p className="norma">Decreto 1072 de 2015 y Resolución 0312 de 2019</p>
        <div className="field">
          <label htmlFor="email">Correo</label>
          <input id="email" type="email" autoComplete="username" required value={email} onChange={e => setEmail(e.target.value)} />
        </div>
        <div className="field">
          <label htmlFor="pw">Contraseña</label>
          <input id="pw" type="password" autoComplete="current-password" required value={password} onChange={e => setPassword(e.target.value)} />
        </div>
        {error && <p className="alert rojo" role="alert">{error}</p>}
        <button className="btn primary block" disabled={enviando}>{enviando ? 'Ingresando…' : 'Ingresar'}</button>
      </form>
    </div>
  );
}
