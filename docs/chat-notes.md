# FigCraft Collaboration Server: Chat Notes

*Date: 2026-11-08. System: Arch Linux, fish shell, kitty terminal.*

> Secrets that were pasted in the chat (server key, join token) are replaced by placeholders here. Treat any key or token that appeared in a chat as exposed and rotate it if it matters.

---

## 1. What FigCraft is

- Open-source, clean-room interface design / prototyping app written in pure Rust: <https://github.com/storytold/figcraft>
- Dual-licensed MIT / Apache-2.0. Status: **early alpha** (the README estimates about 49% of the way to replacing proprietary tools).
- Native on macOS, Windows, Linux, FreeBSD, and in the browser via WebAssembly.
- Every action is a command, so the UI, CLI (`figcraft-cli`), MCP server and a JSON control channel all drive the same engine.
- Docs read during the chat: `README.md` and `docs/server.md`.

## 2. How collaboration works

- The app is the editor. `figcraft-server` is a separate program that stores shared files and relays live edits.
- Flow: share/publish a file, get a link or join code (edit or view), the other person joins, edits sync live (cursors, selections, follow mode, cursor chat). Undo only reverses your own changes.
- **No accounts.** The link or code is the access. The **server key** manages files and links.
- **Not end-to-end encrypted.** The server stores files unencrypted, and whoever runs it can read them.

### Three ways to invite someone

| Option | How | Notes |
|---|---|---|
| Default public server | **Share ▸ Online ▸ Start sharing** gives a join code. The friend uses **Share ▸ Join with a code**. | Zero setup. Server is `collab.craftapps.dev`. Unopened files are deleted after 30 days. No backup or uptime guarantees. |
| Local network | **Share ▸ Local network** | No server. Your app hosts the session. Not encrypted. Same network only. |
| Your own server | Run `figcraft-server`, publish a file, share the edit or view link | Described below. |

Join-code details: 9 symbols (like `K7M-2QX-9TD`), one code per link, edit and view codes differ. Wrong guesses are rate-limited. **Stop sharing** revokes the codes and disconnects everyone else.

## 3. Building and running the server on Arch

### Problems hit and their fixes

1. `cargo: Unknown command`. Rust wasn't installed or the shell wasn't ready. Fix:
   ```fish
   sudo pacman -S --needed base-devel rust
   ```
2. `could not find Cargo.toml in /home/jojo`. The command was run from `~`, not from the repo. Fix: `cd ~/figcraft` first, and check with `pwd`.
3. A heredoc (`cat > file << 'EOF'`) failed. **Fish doesn't support bash heredocs.** Fix: paste a fish `function` and run `funcsave`.
4. Build warnings about unused patches and missing `craft-fonts` are harmless for the server. The build took about 8 minutes.

### Commands

```fish
cd ~/figcraft
cargo build --release -p figcraft-server
target/release/figcraft-server --listen 0.0.0.0:47900 --data ./figcraft-data
target/release/figcraft-server --data ./figcraft-data key
```

- Default listen address is `127.0.0.1:47900` (this machine only). `0.0.0.0` lets the network in.
- On start the log said links name `ws://<LAN-IP>:47900/`, which is the machine's LAN address.
- The `key` command prints `ws://127.0.0.1:47900/?key=<SERVER_KEY>`. Using `127.0.0.1` is fine when publishing from the same PC.
- If a firewall is on: `sudo ufw allow 47900/tcp`.
- Health check: `http://<LAN-IP>:47900/healthz` should return `ok`.

### The desktop app

- Easiest: Linux AppImage/Flatpak/tarball from the GitHub releases page.
- From source: clone `craft-fonts` next to the repo (`../craft-fonts`), then `cargo run --release -p figcraft`.

## 4. Publishing and getting a link that works

1. In the app: **File ▸ Publish to server…**, paste `ws://127.0.0.1:47900/?key=<SERVER_KEY>`, give the file a name, click **Publish**.
2. The Share popover shows an **edit link** and a **view link**.

### Why the join link failed for the friend

The app produced `figcraft://join?host=127.0.0.1:47900&file=<FILE_ID>&token=<TOKEN>`.

- `127.0.0.1` means "this computer". On the friend's machine it points to their own computer, so it fails. **Tailscale is not what makes it valid or invalid; the host part is.**
- Fix by hand: replace the host with the LAN address (`host=<LAN-IP>:47900`), or use the WebSocket form `ws://<LAN-IP>:47900/?file=<FILE_ID>&token=<TOKEN>`.
- Or publish using the LAN address so the app generates correct links.
- A LAN address (`192.168.x.x`) only works for someone on the **same Wi-Fi/LAN**.

### CLI way to get a working link

```fish
target/release/figcraft-server --data ./figcraft-data files list
target/release/figcraft-server --data ./figcraft-data links create <FILE_ID> --access edit --label friend
target/release/figcraft-server --data ./figcraft-data links list <FILE_ID>
target/release/figcraft-server --data ./figcraft-data links revoke <FILE_ID> <LINK_ID>
```

A new link is shown only once; the server keeps only a hash.

### Who can reach it

| Friend is... | Works without Tailscale? |
|---|---|
| On the same Wi-Fi/LAN | Yes |
| On a different network | No. Use Tailscale, a tunnel (Tailscale Funnel / Cloudflare Tunnel), the default public server, or a hosted server |

## 5. The `fig-server` fish function

Fish loads functions from `~/.config/fish/functions/`. Paste the function into the shell, then run `funcsave fig-server`. It persists in all future terminals.

### Simple version

```fish
function fig-server --description "Control the FigCraft collaboration server"
    set -l bin ~/figcraft/target/release/figcraft-server
    set -l data ~/figcraft/figcraft-data
    set -l cmd $argv[1]
    set -e argv[1]

    switch "$cmd"
        case start
            $bin --listen 0.0.0.0:47900 --data $data
        case key
            $bin --data $data key $argv
        case files
            $bin --data $data files list
        case link
            set -l access edit
            test -n "$argv[1]"; and set access $argv[1]
            set -l id $argv[2]
            test -z "$id"; and set id ($bin --data $data files list | string match -r -m1 '[0-9a-f]{16}')
            test -z "$id"; and echo "no file found, publish one first"; and return 1
            $bin --data $data links create $id --access $access
        case '*'
            echo "usage: fig-server start | key | files | link [edit|view] [FILE_ID]"
    end
end
```

Daily routine:

```fish
fig-server start    # terminal 1, leave running
fig-server link     # terminal 2, prints a link
```

Notes: don't paste trailing `# comments` after commands. Each `link` run creates a new link, so clean up with `links list` / `links revoke`. The file-ID auto-detect assumes 16 hex characters; adjust if `files list` looks different.

## 6. Running it 24/7

| Option | Verdict |
|---|---|
| **Google Colab** | Not suitable. Sessions disconnect, the disk is wiped, there is no stable public address, and it isn't meant for hosting. |
| **Vercel** | Can't run the server. It's serverless: no long-running process, no persistent WebSockets, no persistent disk. It *could* host the static WebAssembly web client, which would still need a real server. |
| **Fly.io** | Works in principle (containers, WebSockets, volumes, repo has `packaging/server/Dockerfile`). **No ongoing free tier**; short trial, then a credit card and usage billing. Roughly a few dollars/month (volumes about $0.15/GB/month). Turn off auto-stop. Untested with figcraft-server. |
| **Render** | Free tier **unusable** (spins down after 15 min idle, ephemeral filesystem, no persistent disk). Paid always-on is about $7/month plus about $0.25/GB/month disk. |
| **Oracle Cloud Free Tier** | Needs a credit or debit card. Prepaid, virtual and PIN-debit cards are rejected, and Indian signups often fail (RuPay especially). Articles claiming "no card needed" look unreliable. Oracle Academy students/educators may sign up without a card. |
| **A small VPS** | Cleanest 24/7 route. The repo ships Linux server release tarballs and `packaging/server/install.sh` (systemd, Caddy HTTPS, firewall). |

Pricing was checked from search results in Nov 2026 and changes often. Verify before relying on it.

### No credit card

1. **Own PC + Tailscale** (free, private, encrypted). Needs `public_url = "ws://<tailscale-ip>:47900/"` in a `server.toml` so links name the right address. Only works while the PC is on.
2. **Tailscale Funnel or Cloudflare Tunnel** from the PC for a public `https://` address. Probably passes WebSockets but untested with figcraft-server.
3. **Default public server** via Share ▸ Online ▸ Start sharing.
4. Router port forwarding is not recommended (security, CGNAT, unencrypted).

## 7. Where the data lives

- Files published to the server are stored in `figcraft-data/files/<id>/` (`snapshot.bin`, `log.bin`, `links.json`, `meta.json`). They survive restarts and crashes, and the same link opens the same, up-to-date file.
- It's the server's own format, not a normal `.figcraft` file. **Save a `.figcraft` copy from the app (File ▸ Save)** for real backups. **Leave session** also keeps the file as your own editable copy.
- `figcraft-data/server.key` gives full control of the server. Never share it.
- Only one server may use a data folder at a time. A plain copy of a running server's folder can miss changes, so copy it while the server is stopped.

## 8. Using GitHub with it

GitHub can sync and back up the data but can't be the live storage: the server writes constantly, Git can't merge binary data, and only one server may use the folder.

### Safe to commit

- `.figcraft` files saved from the app, and exports (PNG, SVG, PDF)
- your `fig-server` function

### Never commit

- `server.key`, join links, tokens

### Handoff pattern between two PCs (private repo)

1. `figcraft-data` becomes a **private** repo with `.gitignore`:
   ```
   server.key
   LOCK
   server.json
   *.tmp
   ```
2. `fig-server start` pulls, checks a `HOLDER` lock file, writes the lock, pushes it, and starts the server.
3. After stopping the server (Ctrl+C), `fig-server done` commits and pushes the data and removes the lock.
4. On the second PC: install the server (release tarball), clone the data repo into `~/figcraft/figcraft-data`, create the same function, run `fig-server start`.

Setup on the first PC:

```fish
cd ~/figcraft/figcraft-data
git init -b main
printf 'server.key\nLOCK\nserver.json\n*.tmp\n' > .gitignore
git add -A
git commit -m "initial data"
gh repo create figcraft-data --private --source . --push
```

### Limits

- GitHub rejects files over 100 MB, and binary commits make a repo grow quickly.
- Changes since the last `done` aren't pushed if the PC crashes.
- The lock is a convention, not a guarantee.
- Links name the host's current address, so after a handoff the host part of old links needs updating (tokens stay the same).
- Possible extra (untested): GitHub Codespaces as a free-hours host with a forwarded port. It sleeps when idle.

## 9. Quick reference

```fish
# build
cd ~/figcraft && cargo build --release -p figcraft-server

# run
fig-server start

# get links
fig-server link          # edit link
fig-server link view     # view-only link

# list files / links, revoke
target/release/figcraft-server --data ./figcraft-data files list
target/release/figcraft-server --data ./figcraft-data links list <FILE_ID>
target/release/figcraft-server --data ./figcraft-data links revoke <FILE_ID> <LINK_ID>

# rotate the server key (stop the server first)
target/release/figcraft-server --data ./figcraft-data key --rotate
```

## 10. Open items / next steps

- Decide how the friend will connect: same network, Tailscale, tunnel, or the public server.
- Optional: run the server as a systemd user service so it starts at login.
- Optional: a `fig-server backup` command for `.figcraft` exports.
- Optional: try Codespaces, a VPS, or Oracle later with a suitable card.
