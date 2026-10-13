# htb-alt — a private pentest-training lab

A self-hosted, HTB-style practice range for building penetration-testing skills
for interviews. A **Kali attacker** container faces a set of **intentionally
vulnerable training targets** on an isolated network, with an optional
**Windows Active Directory** side and an **AWS cloud** side. A small CLI tracks
what you're learning.

Everything here is for **authorized practice against machines you own**. The
targets are purpose-built, deliberately-vulnerable training images. Keep the lab
isolated from your home LAN and the internet.

## Layout

```
lab                 # main CLI: network, attacker, targets, status
lib/common.sh       # shared config/helpers
attacker/           # Kali attacker image (Containerfile) + persistent work dir
catalog/targets.tsv # catalog of training targets
targets/            # compose files for multi-container targets
tracker/            # learning tracker: curriculum.json + ./track CLI
windows/            # KVM/libvirt Windows + Active Directory lab (GOAD) guide
aws/                # AWS cloud practice: runtime cred loading + free-tier guard
notes/              # your engagement notes (gitignored by default)
```

## Quick start (Linux targets)

```bash
./lab up                      # isolated network + build & start Kali attacker
./lab catalog                 # see available targets
./lab target up dvwa          # start a target on the lab network
./lab attacker shell          # hop onto Kali; reach the target as host "dvwa"
./lab status                  # what's running
./lab target down dvwa        # tear a target down
./lab reset                   # stop everything, remove the network
```

From the attacker shell, targets resolve by name (podman DNS), e.g. `dvwa`,
`metasploitable2` — just like being handed an in-scope host. Web targets also
publish to `http://localhost:<port>` on your host for convenience (see
`./lab catalog`).

The first `./lab up` pulls the Kali base and a toolset — a few GB. Edit
`attacker/Containerfile` (`TOOLSET=`) to go lighter (`kali-tools-top10`) or
heavier (`kali-linux-default`).

## Accessing targets from another machine (e.g. your XPS)

There's no single app website — each target is its own web app on its own port.
To get "one page with links", run the **portal**:

```bash
./lab portal          # serves a dashboard of running targets on :1337
```

Reach it from your XPS (or phone/laptop) over **Tailscale**:

```
http://<this-host-tailscale-ip>:1337
```

Each target card links straight to that target. The links follow whatever
address you arrived on, so Tailscale access gives Tailscale links.

**Exposure is tailnet-only by design.** Published ports bind to this host's
Tailscale IP, not `0.0.0.0`, so the deliberately-vulnerable apps are reachable
from devices on your tailnet but **not** from your home LAN or the internet.
Override per session if you really want LAN access:

```bash
PUBLISH_ADDR=0.0.0.0   ./lab target up dvwa   # expose on LAN too (riskier)
PUBLISH_ADDR=127.0.0.1 ./lab target up dvwa   # host-only
```

(If `tailscale0` isn't present, it falls back to `0.0.0.0`.)

## Targets

Single-container ones run straight from the catalog; multi-container ones
(Mutillidae, NodeGoat) have compose files under `targets/`. All are published by
their projects for security education — DVWA, OWASP Juice Shop / WebGoat /
Mutillidae / NodeGoat, bWAPP, Metasploitable 2, VAmPI, DVWS. Add your own by
appending a row to `catalog/targets.tsv`.

## Windows / Active Directory

Windows can't run in a Linux container, so it uses KVM/libvirt VMs. See
[`windows/README.md`](windows/README.md). The recommended AD range is **GOAD
(Game of Active Directory)** — the closest free equivalent to HTB's AD labs.
Start with `./windows/setup-check.sh`.

## AWS / cloud

See [`aws/README.md`](aws/README.md). Credentials are loaded at runtime from the
`tf-aws` repo and **never committed**; practice is pinned to **free-tier**
instances with `aws/guard.sh`.

## Tracking what you're learning

```bash
./tracker/track show              # progress bars by area
./tracker/track list web          # skills in one area + suggested targets
./tracker/track start web-sqli    # mark a skill in-progress
./tracker/track done  web-sqli    # mark it done
./tracker/track note  web-sqli "union-based worked on dvwa low/medium"
./tracker/track log "2h on juice shop, got the xss challenges"
```

Curriculum covers recon, web, API, network, privesc, AD, cloud, pivoting and
reporting — edit `tracker/curriculum.json` to shape it to the roles you're
interviewing for.

## Safety / git hygiene

- `.gitignore` blocks credentials, `*.tfstate`/`*.tfvars`, keys, VM images and
  your `notes/` + `attacker/work/` by default.
- Keep the lab off your production/home network.
- AWS: free-tier only, and set a $1 Budgets alarm as a backstop.
