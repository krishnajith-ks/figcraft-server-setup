#!/usr/bin/env bash
# FigCraft Server & Client — Complete Automated Installer
# Installs system dependencies (tailscale, fish, git, curl),
# downloads prebuilt binaries if needed, and sets up launchers.

set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  FigCraft Collaboration Setup & Dependency Check   "
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 1. Detect & Install missing system dependencies
MISSING_PKGS=()
for cmd in fish tailscale git curl; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        MISSING_PKGS+=("$cmd")
    fi
done

if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
    echo "==> Missing packages detected: ${MISSING_PKGS[*]}"
    echo "==> Installing dependencies via package manager (sudo may ask for password)..."
    if command -v pacman >/dev/null 2>&1; then
        sudo pacman -S --needed --noconfirm "${MISSING_PKGS[@]}"
    elif command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update && sudo apt-get install -y "${MISSING_PKGS[@]}"
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y "${MISSING_PKGS[@]}"
    elif command -v zypper >/dev/null 2>&1; then
        sudo zypper install -y "${MISSING_PKGS[@]}"
    else
        echo "⚠️  Could not auto-detect package manager. Please install manually: ${MISSING_PKGS[*]}"
    fi
else
    echo "  [✓] All required packages present (fish, tailscale, git, curl)"
fi

# 2. Ensure tailscaled is running
if command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet tailscaled 2>/dev/null; then
    echo "  [✓] Tailscale service is active"
elif command -v systemctl >/dev/null 2>&1; then
    echo "==> Starting Tailscale service..."
    sudo systemctl enable --now tailscaled 2>/dev/null || true
fi

# 3. Check for figcraft-server binary (download prebuilt if not compiled)
mkdir -p "$HOME/.local/bin"
if [ -x "$HOME/figcraft/target/release/figcraft-server" ]; then
    echo "  [✓] Found compiled server binary at ~/figcraft/target/release/figcraft-server"
elif [ -x "$HOME/.local/bin/figcraft-server" ]; then
    echo "  [✓] Found server binary at ~/.local/bin/figcraft-server"
else
    echo "==> figcraft-server binary not found. Downloading prebuilt release (v0.16.0)..."
    TMP_DIR=$(mktemp -d)
    curl -sSL "https://github.com/storytold/figcraft/releases/download/v0.16.0/figcraft-server-0.16.0-linux-x86_64.tar.gz" -o "$TMP_DIR/server.tar.gz"
    tar -xzf "$TMP_DIR/server.tar.gz" -C "$TMP_DIR"
    cp "$TMP_DIR/figcraft-server" "$HOME/.local/bin/figcraft-server"
    chmod +x "$HOME/.local/bin/figcraft-server"
    rm -rf "$TMP_DIR"
    echo "  [✓] Installed figcraft-server to ~/.local/bin/figcraft-server"
fi

# 4. Check for FigCraft desktop app (download AppImage if not installed)
if command -v figcraft >/dev/null 2>&1; then
    echo "  [✓] Found system figcraft desktop application"
elif compgen -G "$HOME/ArtCraft/*figcraft*.AppImage" >/dev/null 2>&1; then
    echo "  [✓] Found FigCraft AppImage in ~/ArtCraft/"
else
    echo "==> FigCraft desktop app not found. Downloading Linux AppImage (v0.16.0)..."
    mkdir -p "$HOME/ArtCraft"
    curl -sSL "https://github.com/storytold/figcraft/releases/download/v0.16.0/figcraft-0.16.0-linux-x86_64.AppImage" -o "$HOME/ArtCraft/figcraft-0.16.0-linux-x86_64.AppImage"
    chmod +x "$HOME/ArtCraft/figcraft-0.16.0-linux-x86_64.AppImage"
    echo "  [✓] Downloaded FigCraft AppImage to ~/ArtCraft/"
fi

# 5. Install fish CLI function
mkdir -p "$HOME/.config/fish/functions"
cp "$REPO_DIR/config/fig-server.fish" "$HOME/.config/fish/functions/fig-server.fish"
echo "  [✓] Installed fish function: fig-server"

# 6. Install desktop launcher
mkdir -p "$HOME/.local/share/applications"
cp "$REPO_DIR/scripts/figcraft-server-app" "$HOME/.local/bin/figcraft-server-app"
chmod +x "$HOME/.local/bin/figcraft-server-app"
cp "$REPO_DIR/config/figcraft-server.desktop" "$HOME/.local/share/applications/figcraft-server.desktop"
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
fi
echo "  [✓] Configured app drawer entry: 'FigCraft Server'"

# 7. Setup data directory & server.toml
DATA_DIR="$HOME/figcraft/figcraft-data"
mkdir -p "$DATA_DIR"

TS_IP=$(tailscale ip -4 2>/dev/null || ip -4 route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+' || echo "127.0.0.1")

if [ ! -f "$DATA_DIR/server.toml" ]; then
    printf 'listen = "0.0.0.0:47900"\ndata = "%s"\npublic_url = "ws://%s:47900/"\n' "$DATA_DIR" "$TS_IP" > "$DATA_DIR/server.toml"
    echo "  [✓] Configured server.toml with address: ws://$TS_IP:47900/"
fi

# 8. Optional: Clone shared data repository if argument provided
if [ -n "$1" ]; then
    echo "==> Synchronizing shared data repo from: $1"
    if [ ! -d "$DATA_DIR/.git" ]; then
        git clone "$1" "$DATA_DIR"
    else
        (cd "$DATA_DIR" && git pull)
    fi
    printf 'listen = "0.0.0.0:47900"\ndata = "%s"\npublic_url = "ws://%s:47900/"\n' "$DATA_DIR" "$TS_IP" > "$DATA_DIR/server.toml"
    echo "  [✓] Shared data repository synchronized"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 Setup Complete!"
echo "   - Connection Address: ws://$TS_IP:47900/"
echo "   - App Drawer: 'FigCraft Server' is ready"
echo "   - Fish Shell: Run 'fig-server' for all controls"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
