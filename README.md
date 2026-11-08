# FigCraft Collaboration Server

Lightweight, self-hosted collaboration setup for [FigCraft](https://github.com/storytold/figcraft) with **Tailscale**, **256 MB RAM protection**, fish CLI, and auto-shutdown app launcher.

---

## ⚡ 1-Line Setup (For You or a Friend)

Copy and run this on any Arch/Linux PC:

```bash
git clone https://github.com/krishnajith-ks/figcraft-server-setup.git ~/figcraft-setup && bash ~/figcraft-setup/scripts/install.sh
```

> **To also pull shared files & history from the private data repo:**
> ```bash
> git clone https://github.com/krishnajith-ks/figcraft-server-setup.git ~/figcraft-setup && bash ~/figcraft-setup/scripts/install.sh https://github.com/krishnajith-ks/figcraft-data.git
> ```

---

## 🚀 Daily Commands

Run from your `fish` terminal:

| Command | Action |
|---|---|
| `fig-server start-bg` | Start server in background (capped at 256 MB RAM) |
| `fig-server status` | Show status, PID, RAM usage, health, and IP |
| `fig-server ram` | Check live memory usage & cgroup limit |
| `fig-server log` | Stream live server logs |
| `fig-server stop` | Save files and shutdown server |
| `fig-server key` | Show master publish URL to paste into FigCraft |
| `fig-server link` | Generate an instant real-time edit link for friends |
| `fig-server link view` | Generate a view-only invite link |
| `fig-server backup` | Save local timestamped snapshot to `~/figcraft-backups/` |
| `fig-server push` | Push latest files & metadata to private GitHub repo |
| `fig-server pull` | Pull latest files & metadata from private GitHub repo |

---

## 🖥️ App Drawer Launcher

Search for **`FigCraft Server`** in your application launcher (Niri, rofi, fuzzel, etc.):
- **Opens**: Automatically starts background server and loads `/home/jojo/Downloads/sb.fig` (or default file).
- **Notifies**: Shows desktop toast with the live connection address.
- **Exits**: When you close FigCraft, the server shuts down automatically (uses **0 MB RAM** when idle).

---

## 👥 How to Invite Friends (Live Real-Time Editing)

1. Connect your friend to your **Tailscale** network.
2. In your FigCraft app: **File ▸ Publish to server…** (paste address from `fig-server key`).
3. Run `fig-server link` in terminal.
4. Send the `figcraft://join?...` link to your friend. Both of you can now edit live on the same canvas.

---

## 🔄 Server Handoff (Friend Hosts When Your PC is Off)

To let a friend run the **exact same server** with the **same files and history**:

1. **Before turning off your PC**:
   ```fish
   fig-server stop && fig-server push
   ```
2. **On your friend's PC**:
   ```fish
   fig-server pull && fig-server start-bg
   ```
3. **When friend is done**:
   ```fish
   fig-server stop && fig-server push
   ```
4. **When you are back**:
   ```fish
   fig-server pull && fig-server start-bg
   ```

---

## 📂 Storage & Security

- **Server Data**: `~/figcraft/figcraft-data/`
- **Secret Key**: `~/figcraft/figcraft-data/server.key` (*never committed to GitHub*)
- **Exporting Files**: Use **File ▸ Save** inside FigCraft anytime to save a standalone `.figcraft` file.
- **Safety**: Sensitive keys, lock files, and runtime tokens are automatically excluded by `.gitignore`.
