export default function RouteTable({
  routes,
  selectedId,
  onSelect,
  query,
  onlyEnabled,
  direction,
  deviceFilter = "all",
}) {
  const filtered = routes.filter((route) => {
    if (onlyEnabled && route.disabled) return false;
    if (direction !== "all" && route.direction !== direction) return false;
    if (deviceFilter !== "all" && route.device_id !== deviceFilter) return false;
    const blob = `${route.dst} ${route.gateway} ${route.interface || ""} ${route.comment} ${route.routing_table} ${route.device_name || ""}`.toLowerCase();
    return blob.includes(query.toLowerCase());
  });

  return (
    <div className="table-wrap">
      <table>
        <thead>
          <tr>
            <th>dst</th>
            <th>gw</th>
            <th>iface</th>
            <th>dir</th>
          </tr>
        </thead>
        <tbody>
          {filtered.map((route) => (
            <tr
              key={route.id}
              className={route.id === selectedId ? "active" : ""}
              onClick={() => onSelect(route.id)}
              onKeyDown={(ev) => {
                if (ev.key === "Enter" || ev.key === " ") onSelect(route.id);
              }}
              tabIndex={0}
              role="button"
            >
              <td>
                {route.dst}
                {route.routing_table !== "main" ? <small> {route.routing_table}</small> : null}
                {route.device_name ? <small> {route.device_name}</small> : null}
              </td>
              <td>{route.gateway}</td>
              <td>{route.interface || "—"}</td>
              <td className={`dir ${route.direction}`}>{route.direction}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
