#!/usr/bin/env fish
# scripts/init-data-repo.fish
# Run once to turn ~/figcraft/figcraft-data into a git repository and push to GitHub.
# Usage: fish scripts/init-data-repo.fish

set -l data ~/figcraft/figcraft-data

echo "==> Checking prerequisites..."

if pgrep -x figcraft-server >/dev/null
    echo "❌ Stop the server first: fig-server stop"
    exit 1
end

if not type -q gh
    echo "❌ gh CLI not installed. Install via package manager and authenticate with: gh auth login"
    exit 1
end

if not gh auth status >/dev/null 2>&1
    echo "❌ Not logged in to GitHub: run 'gh auth login' first"
    exit 1
end

echo "==> Initializing git repository in $data ..."
cd $data

git init -b main

# Essential ignores: protect secret keys, active locks, runtime state, and heavy binaries
printf 'server.key\nLOCK\nserver.json\n*.tmp\n*.pid\nfiles/\n' > .gitignore

git add -A
git commit -m "Initial data repository setup"

echo "==> Creating private GitHub repository 'figcraft-data' ..."
gh repo create figcraft-data \
    --private \
    --source . \
    --remote origin \
    --push \
    --description "FigCraft server data snapshots (private)"

set -l user (gh api user -q .login 2>/dev/null; or echo "your-account")

echo ""
echo "✅ Done! Your private data repository is now created at:"
echo "   https://github.com/$user/figcraft-data"
echo ""
echo "Daily sync commands:"
echo "   fig-server push   → sync data to GitHub (stop server first)"
echo "   fig-server pull   → sync data from GitHub (stop server first)"
