# figcraft-server-setup

Personal setup for running a [FigCraft](https://github.com/storytold/figcraft) collaboration server on **CachyOS (Arch Linux)** with **fish shell**.

FigCraft is an open-source, Rust-based interface design/prototyping app. `figcraft-server` is its self-hosted real-time collaboration backend.

---

## What's in this repo

| Path | Purpose |
|---|---|
| `config/fig-server.fish` | Fish function — full server control with RAM monitoring |
| `config/figcraft-server.service` | systemd user service (optional auto-start) |
| `config/server.toml.example` | Example server config (Tailscale / LAN public_url) |
| `docs/setup-guide.md` | Full setup guide with GitHub integration |
| `docs/chat-notes.md` | Original session notes |
| `scripts/init-data-repo.fish` | One-shot script to init the data git repo |

---

## Quick start

### Prerequisites

```fish
sudo pacman -S github-cli tailscale
gh auth login
git config --global user.name "krishnajith-ks"
git config --global user.email "YOUR_GITHUB_EMAIL"
```

### Install the fish function

```fish
cp config/fig-server.fish ~/.config/fish/functions/
# or: source config/fig-server.fish
```

### Start the server

```fish
fig-server start      # foreground
fig-server start-bg   # background (256 MB RAM cap)
fig-server status     # check health + RAM usage
```

### Get a share link

```fish
fig-server key        # print server key (for publishing from the app)
fig-server link       # edit link
fig-server link view  # view-only link
```

---

## RAM management

The server typically uses **5–30 MB** at rest. The fish function enforces a **256 MB hard cap** via `systemd-run --scope -p MemoryMax=256M` — the kernel OOM-kills the server if it exceeds this, so it can never starve your desktop.

Check it any time:

```fish
fig-server ram     # system + server breakdown
fig-server status  # includes current RSS
```

Your system already has:
- `zram0` (zstd, 7.5 GB compressed swap) — excellent, keeps things fast under pressure
- `systemd-oomd` running — kills cgroups that go over their limit before the global OOM fires

---

## Remote access (Tailscale)

```fish
sudo systemctl enable --now tailscaled
sudo tailscale up          # browser login
tailscale ip -4            # get your Tailscale IP
```

Then update `server.toml` so links use the VPN address:

```fish
set ts_ip (tailscale ip -4)
printf 'listen = "0.0.0.0:47900"\ndata = "/home/jojo/figcraft/figcraft-data"\npublic_url = "ws://%s:47900/"\n' $ts_ip \
    > ~/figcraft/figcraft-data/server.toml
```

After this, `fig-server link` automatically uses the Tailscale IP instead of the LAN IP.

---

## Two-repo layout

| Repo | Contents | Privacy |
|---|---|---|
| `figcraft-server-setup` (this repo) | Scripts, config, docs | Private |
| `figcraft-data` | Server metadata snapshots | Private |

See `docs/setup-guide.md` for the full data-repo handoff pattern.
