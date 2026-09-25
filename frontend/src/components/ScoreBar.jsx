// Barra de puntaje con los umbrales de la Res. 0312 Art. 28: <60 crítico, 60–85 moderado, >85 aceptable
export default function ScoreBar({ puntaje, valoracion, compact = false }) {
  const p = Math.max(0, Math.min(100, Number(puntaje) || 0));
  const tono = p < 60 ? 'rojo' : p <= 85 ? 'amarillo' : 'verde';
  return (
    <figure className={`score ${compact ? 'compact' : ''} tono-${tono}`}>
      <div className="score-head">
        <span className="score-num">{p.toFixed(1).replace('.', ',')}<small>%</small></span>
        <span className="score-val">{valoracion}</span>
      </div>
      <div className="score-track" role="meter" aria-valuemin={0} aria-valuemax={100} aria-valuenow={p}
        aria-label="Puntaje de estándares mínimos">
        <div className="score-fill" style={{ width: `${p}%` }} />
        <span className="score-mark" style={{ left: '60%' }}><i>60</i></span>
        <span className="score-mark" style={{ left: '85%' }}><i>85</i></span>
      </div>
    </figure>
  );
}
