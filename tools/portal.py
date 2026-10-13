#!/usr/bin/env python3
"""portal - one dashboard page listing the lab targets that are running.

Started by:  ./lab portal
Reach it from another machine (e.g. your XPS) over Tailscale:
    http://<this-host-tailscale-ip>:1337

On every request it asks podman what's running on the lab network and renders
clickable links. Links are built from the Host header the browser used, so
whether you arrive via the Tailscale IP or the LAN IP, the target links point
back to the same address with the right port.
"""
import http.server, socketserver, subprocess, os, html, json
from pathlib import Path

PORT = int(os.environ.get("PORTAL_PORT", "1337"))
# Default bind follows PUBLISH_ADDR (the Tailscale IP) set by lib/common.sh, so
# the portal is reachable from your tailnet but not the LAN. Falls back to all
# interfaces only if nothing set it.
BIND = os.environ.get("PORTAL_BIND", os.environ.get("PUBLISH_ADDR", "0.0.0.0"))
LAB_NET = os.environ.get("LAB_NET", "labnet")
ROOT = Path(__file__).resolve().parent.parent
CATALOG = ROOT / "catalog" / "targets.tsv"


def load_catalog():
    rows = {}
    for line in CATALOG.read_text().splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) < 6:
            continue
        cid, cat, typ, ref, ports, desc = parts[:6]
        rows[cid] = {"cat": cat, "ports": ports, "desc": desc}
    return rows


def running_targets():
    """Names of containers currently on the lab network (minus the attacker)."""
    try:
        out = subprocess.run(
            ["podman", "ps", "--filter", f"network={LAB_NET}", "--format", "{{.Names}}"],
            capture_output=True, text=True, timeout=10,
        ).stdout.split()
    except Exception:
        out = []
    return [n for n in out if n != "attacker"]


PAGE = """<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Lab Portal</title><style>
:root{{color-scheme:dark;--bg:#0d1117;--card:#161b22;--line:#30363d;--fg:#e6edf3;--mut:#8b949e;--accent:#2f81f7;--ok:#3fb950}}
*{{box-sizing:border-box}}body{{margin:0;background:var(--bg);color:var(--fg);
font:16px/1.5 ui-sans-serif,system-ui,Segoe UI,Roboto,sans-serif}}
.wrap{{max-width:860px;margin:0 auto;padding:32px 16px}}
h1{{font-size:1.5rem;margin:0 0 4px}}.sub{{color:var(--mut);margin:0 0 24px;font-size:.9rem}}
.grid{{display:grid;gap:14px}}
.card{{background:var(--card);border:1px solid var(--line);border-radius:12px;padding:16px 18px;
display:flex;align-items:center;justify-content:space-between;gap:16px;text-decoration:none;color:inherit}}
.card:hover{{border-color:var(--accent)}}
.name{{font-weight:600}}.desc{{color:var(--mut);font-size:.88rem;margin-top:2px}}
.tag{{font-size:.72rem;color:var(--mut);border:1px solid var(--line);border-radius:999px;padding:2px 8px;margin-left:8px}}
.go{{color:var(--accent);font-size:.85rem;white-space:nowrap}}
.dot{{color:var(--ok)}}.empty{{color:var(--mut);background:var(--card);border:1px dashed var(--line);
border-radius:12px;padding:24px;text-align:center}}
code{{background:#0d1117;border:1px solid var(--line);border-radius:6px;padding:1px 6px;font-size:.85em}}
footer{{color:var(--mut);font-size:.8rem;margin-top:28px;border-top:1px solid var(--line);padding-top:14px}}
</style></head><body><div class="wrap">
<h1>🎯 Lab Portal</h1>
<p class="sub">Targets live on <code>{net}</code>. This page updates each time you load it.</p>
<div class="grid">{cards}</div>
<footer>Internal lab — deliberately vulnerable apps. Reach this over Tailscale, not the open internet.</footer>
</div></body></html>"""


class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a):  # quiet
        pass

    def do_GET(self):
        if self.path not in ("/", "/index.html"):
            self.send_error(404); return
        host = self.headers.get("Host", "").split(":")[0] or "localhost"
        catalog = load_catalog()
        running = running_targets()
        cards = []
        for name in sorted(running):
            meta = catalog.get(name, {"cat": "?", "ports": "-", "desc": ""})
            port = meta["ports"].split(":")[0] if meta["ports"] not in ("-", "") else None
            desc = html.escape(meta["desc"])
            tag = html.escape(meta["cat"])
            if port:
                url = f"http://{host}:{port}/"
                cards.append(
                    f'<a class="card" href="{url}" target="_blank" rel="noopener">'
                    f'<div><div class="name"><span class="dot">●</span> {html.escape(name)}'
                    f'<span class="tag">{tag}</span></div>'
                    f'<div class="desc">{desc}</div></div>'
                    f'<div class="go">open :{port} →</div></a>')
            else:
                cards.append(
                    f'<div class="card"><div><div class="name"><span class="dot">●</span> '
                    f'{html.escape(name)}<span class="tag">{tag}</span></div>'
                    f'<div class="desc">{desc} — no web port; reach it from the Kali box as '
                    f'host <code>{html.escape(name)}</code></div></div></div>')
        body = (PAGE.format(net=html.escape(LAB_NET), cards="".join(cards))
                if cards else
                PAGE.format(net=html.escape(LAB_NET),
                            cards='<div class="empty">No targets running.<br>'
                                  'Start one with <code>./lab target up &lt;id&gt;</code></div>'))
        data = body.encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)


if __name__ == "__main__":
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer((BIND, PORT), Handler) as srv:
        print(f"[+] Lab portal on http://{BIND}:{PORT}")
        print(f"    from your XPS over Tailscale:  http://<this-host-tailscale-ip>:{PORT}")
        print("    Ctrl-C to stop")
        try:
            srv.serve_forever()
        except KeyboardInterrupt:
            print("\n[*] portal stopped")
