function fig-server --description "Control the FigCraft collaboration server"
    set -l bin ~/figcraft/target/release/figcraft-server
    if not test -x $bin
        if test -x ~/.local/bin/figcraft-server
            set bin ~/.local/bin/figcraft-server
        end
    end

    set -l data ~/figcraft/figcraft-data
    set -l config ~/figcraft/figcraft-data/server.toml
    set -l unit figcraft-server
    set -l cmd $argv[1]
    set -e argv[1]

    # Ensure server.toml exists with reasonable defaults if missing
    if not test -f $config
        set -l ts_ip ""
        if type -q tailscale
            set ts_ip (tailscale ip -4 2>/dev/null)
        end
        if test -n "$ts_ip"
            printf 'listen = "0.0.0.0:47900"\ndata = "%s"\npublic_url = "ws://%s:47900/"\n' $data $ts_ip > $config
        else
            set -l lan_ip (ip -4 route get 1.1.1.1 2>/dev/null | string match -r 'src (\S+)' | tail -n 1)
            printf 'listen = "0.0.0.0:47900"\ndata = "%s"\npublic_url = "ws://%s:47900/"\n' $data $lan_ip > $config
        end
    end

    switch "$cmd"
        case start
            set -l ip (ip -4 route get 1.1.1.1 2>/dev/null | string match -r 'src (\S+)' | tail -n 1)
            set -l ts_ip ""
            if type -q tailscale
                set ts_ip (tailscale ip -4 2>/dev/null)
            end
            echo "🚀 Starting FigCraft server (foreground)..."
            echo "   LAN    : ws://$ip:47900/"
            test -n "$ts_ip"; and echo "   VPN    : ws://$ts_ip:47900/"
            echo "   Health : http://127.0.0.1:47900/healthz"
            echo "   RAM cap: 256 MB (hard limit)"
            echo "   Press Ctrl+C to stop gracefully"

            if type -q systemd-run
                systemd-run --user --scope \
                    -p MemoryMax=256M \
                    -p MemorySwapMax=64M \
                    -p OOMPolicy=kill \
                    -- $bin --config $config
            else
                $bin --config $config
            end

        case start-bg
            if pgrep -x figcraft-server >/dev/null
                echo "⚠️  Server is already running (PID: "(pgrep -x figcraft-server | head -1)")"
                return 1
            end

            set -l ip (ip -4 route get 1.1.1.1 2>/dev/null | string match -r 'src (\S+)' | tail -n 1)
            set -l ts_ip ""
            if type -q tailscale
                set ts_ip (tailscale ip -4 2>/dev/null)
            end

            echo "🚀 Starting FigCraft server in background with 256MB RAM cap..."
            systemd-run --user --unit=$unit \
                --property=MemoryMax=256M \
                --property=MemorySwapMax=64M \
                --property=OOMPolicy=kill \
                -- $bin --config $config >/dev/null 2>&1

            sleep 1.5
            if pgrep -x figcraft-server >/dev/null
                set -l pid (pgrep -x figcraft-server | head -1)
                echo "🟢 Server started successfully (PID: $pid)"
                echo "   LAN    : ws://$ip:47900/"
                test -n "$ts_ip"; and echo "   VPN    : ws://$ts_ip:47900/"
                echo "   Health : http://127.0.0.1:47900/healthz"
                echo "   Capacity: Up to 256 simultaneous editors in real-time"
            else
                echo "❌ Server failed to start. Checking journal logs:"
                journalctl --user -u $unit -n 10 --no-pager
                return 1
            end

        case stop
            echo "Stopping server..."
            systemctl --user stop $unit 2>/dev/null
            if pgrep -x figcraft-server >/dev/null
                pkill -x figcraft-server
            end
            sleep 1
            if not pgrep -x figcraft-server >/dev/null
                echo "✅ Server stopped cleanly."
            else
                echo "⚠️  Force killing..."
                pkill -9 -x figcraft-server
            end

        case status
            set -l ip (ip -4 route get 1.1.1.1 2>/dev/null | string match -r 'src (\S+)' | tail -n 1)
            set -l ts_ip ""
            if type -q tailscale
                set ts_ip (tailscale ip -4 2>/dev/null)
            end

            if pgrep -x figcraft-server >/dev/null
                set -l pid (pgrep -x figcraft-server | head -1)
                set -l mem_kb (cat /proc/$pid/status 2>/dev/null | grep VmRSS | awk '{print $2}')
                set -l mem_mb (math --scale=1 "$mem_kb / 1024" 2>/dev/null; or echo "?")
                echo "🟢 FigCraft server is RUNNING"
                echo "   PID      : $pid"
                echo "   RAM      : $mem_mb MB (Max cap: 256 MB)"
                echo "   Health   : "(curl -sf --max-time 1 http://127.0.0.1:47900/healthz 2>/dev/null; or echo "unreachable")
                echo "   Capacity : Up to 256 editors simultaneously"
                echo "   LAN      : ws://$ip:47900/"
                test -n "$ts_ip"; and echo "   VPN      : ws://$ts_ip:47900/"
            else
                echo "🔴 FigCraft server is STOPPED"
            end

        case ram
            set -l available_mb (math (grep MemAvailable /proc/meminfo | awk '{print $2}') / 1024)
            set -l total_mb (math (grep MemTotal /proc/meminfo | awk '{print $2}') / 1024)
            set -l used_mb (math "$total_mb - $available_mb")
            echo "── System RAM ──────────────────────────────"
            echo "  Total     : $total_mb MB"
            echo "  Used      : $used_mb MB"
            echo "  Available : $available_mb MB"
            set -l zram_used (zramctl 2>/dev/null | awk 'NR==2{print $4}')
            test -n "$zram_used"; and echo "  zram swap : $zram_used (compressed)"
            echo "── figcraft-server ─────────────────────────"
            if pgrep -x figcraft-server >/dev/null
                set -l pid (pgrep -x figcraft-server | head -1)
                set -l mem_kb (cat /proc/$pid/status 2>/dev/null | grep VmRSS | awk '{print $2}')
                set -l mem_mb (math --scale=1 "$mem_kb / 1024" 2>/dev/null; or echo "?")
                set -l peak_kb (cat /proc/$pid/status 2>/dev/null | grep VmPeak | awk '{print $2}')
                set -l peak_mb (math --scale=1 "$peak_kb / 1024" 2>/dev/null; or echo "?")
                echo "  Current   : $mem_mb MB RSS"
                echo "  Peak      : $peak_mb MB"
                echo "  Cap       : 256 MB (hard cgroup limit)"
            else
                echo "  Not running"
            end

        case key
            $bin --config $config key $argv

        case files
            $bin --config $config files list $argv

        case link
            # Usage: fig-server link [edit|view] [FILE_ID] [LABEL]
            set -l access edit
            test -n "$argv[1]"; and set access $argv[1]
            set -l id $argv[2]
            set -l label $argv[3]
            if test -z "$id"
                set id ($bin --config $config files list | string match -r -m1 '[0-9a-f]{16}')
            end
            if test -z "$id"
                echo "❌ No file found — publish one first via FigCraft app (File ▸ Publish to server…)"
                return 1
            end
            if test -n "$label"
                $bin --config $config links create $id --access $access --label "$label"
            else
                $bin --config $config links create $id --access $access
            end

        case invite
            # Shortcut: fig-server invite [FRIEND_NAME]
            # Generates an edit link specifically labeled for a friend
            set -l friend_name $argv[1]
            test -z "$friend_name"; and set friend_name "Friend"
            set -l id ($bin --config $config files list | string match -r -m1 '[0-9a-f]{16}')
            if test -z "$id"
                echo "❌ No file found — publish one first via FigCraft app (File ▸ Publish to server…)"
                return 1
            end
            echo "🔗 Generating real-time edit link for $friend_name..."
            $bin --config $config links create $id --access edit --label "$friend_name"

        case links
            set -l id $argv[1]
            if test -z "$id"
                set id ($bin --config $config files list | string match -r -m1 '[0-9a-f]{16}')
            end
            $bin --config $config links list $id

        case revoke
            $bin --config $config links revoke $argv[1] $argv[2]

        case backup
            if pgrep -x figcraft-server >/dev/null
                echo "❌ Stop the server first: fig-server stop"
                return 1
            end
            set -l stamp (date +%Y%m%d-%H%M%S)
            set -l dest ~/figcraft-backups/backup-$stamp
            mkdir -p ~/figcraft-backups
            cp -a $data $dest
            set -l size (du -sh $dest | cut -f1)
            echo "✅ Backup saved → $dest ($size)"

        case push
            if pgrep -x figcraft-server >/dev/null
                echo "❌ Stop the server first: fig-server stop"
                return 1
            end
            cd $data
            if not git rev-parse --git-dir >/dev/null 2>&1
                echo "❌ Data directory is not a git repo."
                return 1
            end
            git add -A
            git commit -m "snapshot "(date "+%Y-%m-%d %H:%M"); or echo "(nothing new to commit)"
            git push
            cd -
            echo "✅ Data pushed to GitHub"

        case pull
            if pgrep -x figcraft-server >/dev/null
                echo "❌ Stop the server first: fig-server stop"
                return 1
            end
            cd $data
            if not git rev-parse --git-dir >/dev/null 2>&1
                echo "❌ Data directory is not a git repo."
                return 1
            end
            git pull --ff-only
            cd -
            echo "✅ Data pulled from GitHub"

        case log
            journalctl --user -u $unit -f

        case '*'
            echo ""
            echo "  fig-server — FigCraft collaboration server control"
            echo ""
            echo "  LIFECYCLE"
            echo "    start              Run in foreground (Ctrl+C to stop)"
            echo "    start-bg           Run in background (256 MB RAM cap, systemd managed)"
            echo "    stop               Stop background server"
            echo "    status             Check running status, PID, RAM, health, and URLs"
            echo "    ram                RAM monitor (system + server cgroup)"
            echo "    log                Tail live logs"
            echo ""
            echo "  SHARING (Up to 256 editors simultaneously)"
            echo "    key                Print server key URL (paste into FigCraft to publish)"
            echo "    files              List published files"
            echo "    link [edit|view]   Create a share link"
            echo "    invite [NAME]      Create a labeled edit link for a specific friend"
            echo "    links [FILE_ID]    List all links for a file"
            echo "    revoke FILE LINK   Revoke a link"
            echo ""
            echo "  BACKUP & GITHUB SYNC"
            echo "    backup             Snapshot data directory locally (stop server first)"
            echo "    push               Push metadata snapshot to GitHub (stop server first)"
            echo "    pull               Pull metadata snapshot from GitHub (stop server first)"
            echo ""
    end
end
