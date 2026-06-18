import { useEffect, useState } from "react";

// All calls are relative to the same origin: nginx (prod) / Vite proxy (dev)
// forwards /api to the backend Service. Keeps the frontend env-agnostic.
const api = {
  info: () => fetch("/api/info").then((r) => r.json()),
  list: () => fetch("/api/items").then((r) => r.json()),
  create: (name) =>
    fetch("/api/items", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name }),
    }).then((r) => r.json()),
};

export default function App() {
  const [info, setInfo] = useState(null);
  const [items, setItems] = useState([]);
  const [name, setName] = useState("");
  const [error, setError] = useState(null);

  const refresh = () =>
    api.list().then(setItems).catch((e) => setError(String(e)));

  useEffect(() => {
    api.info().then(setInfo).catch((e) => setError(String(e)));
    refresh();
  }, []);

  const onAdd = async (e) => {
    e.preventDefault();
    if (!name.trim()) return;
    try {
      await api.create(name.trim());
      setName("");
      refresh();
    } catch (e) {
      setError(String(e));
    }
  };

  return (
    <main style={{ fontFamily: "system-ui, sans-serif", maxWidth: 640, margin: "3rem auto", padding: "0 1rem" }}>
      <h1>Platform Observability Stack</h1>
      <p style={{ color: "#666" }}>
        {info ? `${info.app} · ${info.environment}` : "connecting to backend…"}
      </p>

      {error && (
        <p style={{ color: "#b00020" }}>Error talking to backend: {error}</p>
      )}

      <form onSubmit={onAdd} style={{ display: "flex", gap: 8, margin: "1.5rem 0" }}>
        <input
          value={name}
          onChange={(e) => setName(e.target.value)}
          placeholder="New item name"
          style={{ flex: 1, padding: 8 }}
        />
        <button type="submit" style={{ padding: "8px 16px" }}>Add</button>
      </form>

      <ul>
        {items.map((it) => (
          <li key={it.id}>
            #{it.id} — {it.name}
          </li>
        ))}
        {items.length === 0 && <li style={{ color: "#999" }}>No items yet.</li>}
      </ul>
    </main>
  );
}
