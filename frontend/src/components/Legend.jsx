const ITEMS = [
  ["L2 LACP", "#4cc9f0", "solid"],
  ["L2 vPC", "#ffd166", "solid"],
  ["L3 via", "#6d8196", "dash"],
  ["GRE Tun", "#c77dff", "dash"],
  ["путь", "#ffe08a", "solid"],
];

export default function Legend() {
  return (
    <div className="legend">
      {ITEMS.map(([label, color, stroke]) => (
        <div className="swatch" key={label}>
          <span className={`dot ${stroke === "dash" ? "is-dash" : ""}`} style={{ background: stroke === "dash" ? "transparent" : color, borderColor: color }} />
          {label}
        </div>
      ))}
    </div>
  );
}
