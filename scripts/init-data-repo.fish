#!/usr/bin/env fish
# scripts/init-data-repo.fish
# Run once to turn ~/figcraft/figcraft-data into a git repo and push to GitHub.
# Usage: fish scripts/init-data-repo.fish

set data ~/figcraft/figcraft-data
set bin  ~/figcraft/target/release/figcraft-server

echo "==> Checking prerequisites..."

if pgrep -x figcraft-server >/dev/null
    echo "❌ Stop the server first: fig-server stop"
    exit 1
end

if not type -q gh
    echo "❌ gh CLI not installed: sudo pacman -S github-cli && gh auth login"
    exit 1
end

if not gh auth status >/dev/null 2>&1
    echo "❌ Not logged in to GitHub: gh auth login"
    exit 1
end

echo "==> Initialising git repo in $data ..."
cd $data

git init -b main

printf 'server.key\nLOCK\nserver.json\n*.tmp\n*.pid\nfiles/\n' > .gitignore

git add -A
git commit -m "initial data snapshot"

echo "==> Creating private GitHub repo 'figcraft-data' ..."
gh repo create figcraft-data \
    --private \
    --source . \
    --remote origin \
    --push \
    --description "FigCraft server data snapshots (private)"

echo ""
echo "✅ Done! figcraft-data is now at:"
echo "   https://github.com/krishnajith-ks/figcraft-data"
echo ""
echo "   fig-server push   → sync to GitHub (stop server first)"
echo "   fig-server pull   → sync from GitHub (stop server first)"
