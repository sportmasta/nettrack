import { useEffect, useState } from "react";

function attachmentOptions(device) {
  return device?.attachments || [];
}

function attachValue(opt) {
  return opt.kind === "vlan" ? `vlan:${opt.vlan}` : `iface:${opt.name}`;
}

export default function PathTrace({ devices, snapshotId, onResult, hops, status, reason, busy, error }) {
  const list = devices || [];
  const first = list[0];
  const [deviceId, setDeviceId] = useState(first?.id || "");
  const [attach, setAttach] = useState("");
  const [clientIp, setClientIp] = useState("");
  const [dst, setDst] = useState("8.8.8.8");

  const selected = list.find((d) => d.id === deviceId) || first;
  const options = attachmentOptions(selected);

  useEffect(() => {
    if (!list.length) return;
    if (!list.some((d) => d.id === deviceId)) {
      setDeviceId(list[0].id);
    }
  }, [list, deviceId]);

  useEffect(() => {
    const firstOpt = options[0];
    if (!firstOpt) {
      setAttach("");
      return;
    }
    const value = attachValue(firstOpt);
    setAttach((cur) => (options.some((opt) => attachValue(opt) === cur) ? cur : value));
  }, [selected?.id]);

  async function onSubmit(ev) {
    ev.preventDefault();
    if (!snapshotId || !deviceId || !dst) return;
    const payload = { device_id: deviceId, dst };
    if (attach.startsWith("vlan:")) payload.vlan = attach.slice(5);
    if (attach.startsWith("iface:")) payload.interface = attach.slice(6);
    if (clientIp.trim()) payload.client_ip = clientIp.trim();
    await onResult(payload);
  }

  return (
    <form className="path-trace" onSubmit={onSubmit}>
      <div>Эмуляция клиента</div>
      <select aria-label="устройство клиента" value={selected?.id || ""} onChange={(e) => setDeviceId(e.target.value)}>
        {list.map((device) => (
          <option key={device.id} value={device.id}>
            {device.identity} ({device.role || "router"})
          </option>
        ))}
      </select>
      <select aria-label="vlan или интерфейс" value={attach} onChange={(e) => setAttach(e.target.value)}>
        {options.length ? (
          options.map((opt) => {
            const value = attachValue(opt);
            return (
              <option key={value} value={value}>
                {opt.label}
              </option>
            );
          })
        ) : (
          <option value="">нет VLAN / iface</option>
        )}
      </select>
      <input
        aria-label="IP клиента"
        placeholder="IP клиента (необязательно)"
        value={clientIp}
        onChange={(e) => setClientIp(e.target.value)}
      />
      <input aria-label="адрес назначения" placeholder="назначение" value={dst} onChange={(e) => setDst(e.target.value)} />
      <button type="submit" disabled={busy || !snapshotId}>
        Показать путь
      </button>
      {error ? <div className="status-err">{error}</div> : null}
      {status ? (
        <ol className="hop-list">
          {(hops || []).map((hop, idx) => (
            <li key={`${hop.device_id}-${idx}`}>
              <strong>{hop.device_name}</strong> · {hop.kind}
              {hop.iface ? ` · ${hop.iface}` : ""}
              {hop.route_dst ? ` · ${hop.route_dst}` : ""}
              {hop.gateway ? ` → ${hop.gateway}` : ""}
              {hop.note ? <span> — {hop.note}</span> : null}
            </li>
          ))}
        </ol>
      ) : (
        <p className="hint">Выберите устройство, VLAN и назначение — путь пойдёт по longest-prefix match.</p>
      )}
      {reason ? <p className="hint">{reason}</p> : null}
    </form>
  );
}
