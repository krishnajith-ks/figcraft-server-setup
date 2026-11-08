#!/usr/bin/env bash
# FigCraft Server — One-Click Setup Script
# Installs CLI controls, desktop launcher, and network config.

set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> Setting up FigCraft collaboration server..."

# 1. Install fish function
mkdir -p "$HOME/.config/fish/functions"
cp "$REPO_DIR/config/fig-server.fish" "$HOME/.config/fish/functions/fig-server.fish"
echo "  [✓] Installed fish CLI function: fig-server"

# 2. Install desktop launcher binary & desktop entry
mkdir -p "$HOME/.local/bin" "$HOME/.local/share/applications"
cp "$REPO_DIR/scripts/figcraft-server-app" "$HOME/.local/bin/figcraft-server-app"
chmod +x "$HOME/.local/bin/figcraft-server-app"
cp "$REPO_DIR/config/figcraft-server.desktop" "$HOME/.local/share/applications/figcraft-server.desktop"
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
fi
echo "  [✓] Installed App Drawer launcher: 'FigCraft Server'"

# 3. Setup data directory and server.toml
DATA_DIR="$HOME/figcraft/figcraft-data"
mkdir -p "$DATA_DIR"

TS_IP=$(tailscale ip -4 2>/dev/null || ip -4 route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+' || echo "127.0.0.1")

if [ ! -f "$DATA_DIR/server.toml" ]; then
    printf 'listen = "0.0.0.0:47900"\ndata = "%s"\npublic_url = "ws://%s:47900/"\n' "$DATA_DIR" "$TS_IP" > "$DATA_DIR/server.toml"
    echo "  [✓] Generated server.toml with address: ws://$TS_IP:47900/"
fi

# 4. Optional: Clone shared data repository if argument provided
if [ -n "$1" ]; then
    echo "==> Cloning shared data repository from: $1"
    git clone "$1" "$DATA_DIR" 2>/dev/null || (cd "$DATA_DIR" && git pull)
    # Re-apply local public_url
    printf 'listen = "0.0.0.0:47900"\ndata = "%s"\npublic_url = "ws://%s:47900/"\n' "$DATA_DIR" "$TS_IP" > "$DATA_DIR/server.toml"
    echo "  [✓] Shared data repository synchronized"
fi

echo ""
echo "🎉 Setup complete! You can now:"
echo "   - Open 'FigCraft Server' from your application drawer"
echo "   - Or run 'fig-server start-bg' in fish terminal"
