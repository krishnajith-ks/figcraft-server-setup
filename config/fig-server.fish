function fig-server --description "Control the FigCraft collaboration server"
    set -l bin ~/figcraft/target/release/figcraft-server
    set -l data ~/figcraft/figcraft-data
    set -l log_file ~/figcraft/figcraft-server.log
    set -l pid_file ~/figcraft/figcraft-server.pid
    set -l cmd $argv[1]
    set -e argv[1]

    switch "$cmd"
        case start
            set -l ip (ip -4 route get 1.1.1.1 2>/dev/null | string match -r 'src (\S+)' | tail -n 1)
            echo "🚀 FigCraft server starting on $ip:47900"
            echo "   Health: http://$ip:47900/healthz"
            echo "   Press Ctrl+C to stop gracefully"
            # Run with memory limit via systemd-run so it can't hog RAM
            if type -q systemd-run
                systemd-run --user --scope \
                    -p MemoryMax=256M \
                    -p MemorySwapMax=64M \
                    -p OOMPolicy=kill \
                    -- $bin --listen 0.0.0.0:47900 --data $data
            else
                $bin --listen 0.0.0.0:47900 --data $data
            end

        case start-bg
            if pgrep -x figcraft-server >/dev/null
                echo "⚠️  Server already running (PID: "(pgrep -x figcraft-server)")"
                return 1
            end
            set -l ip (ip -4 route get 1.1.1.1 2>/dev/null | string match -r 'src (\S+)' | tail -n 1)
            # Start under a transient systemd scope so the OOM killer and memory cap apply
            if type -q systemd-run
                systemd-run --user --scope \
                    --unit=figcraft-server-bg \
                    -p MemoryMax=256M \
                    -p MemorySwapMax=64M \
                    -p OOMPolicy=kill \
                    -- $bin --listen 0.0.0.0:47900 --data $data >>$log_file 2>&1 &
            else
                nohup $bin --listen 0.0.0.0:47900 --data $data >>$log_file 2>&1 &
            end
            set -l pid $last_pid
            echo $pid > $pid_file
            sleep 1
            # Quick health check
            if pgrep -x figcraft-server >/dev/null
                echo "🟢 Server started (PID: $pid)"
                echo "   LAN  : http://$ip:47900"
                echo "   Log  : $log_file"
                # Show tailscale address if available
                if type -q tailscale
                    set -l ts_ip (tailscale ip -4 2>/dev/null)
                    test -n "$ts_ip"; and echo "   VPN  : http://$ts_ip:47900"
                end
            else
                echo "❌ Server failed to start. Check log: $log_file"
                tail -5 $log_file 2>/dev/null
                return 1
            end

        case stop
            if test -f $pid_file
                set -l pid (cat $pid_file)
                if kill $pid 2>/dev/null
                    echo "✅ Server stopped (PID $pid)"
                    # Give it a moment to flush/compact open files
                    sleep 1
                else
                    echo "⚠️  PID $pid not found, trying pkill..."
                    pkill -x figcraft-server; or echo "⚠️  No server found"
                end
                rm -f $pid_file
            else
                pkill -x figcraft-server; and echo "✅ Server stopped" ; or echo "⚠️  No server running"
            end

        case status
            set -l ip (ip -4 route get 1.1.1.1 2>/dev/null | string match -r 'src (\S+)' | tail -n 1)
            if pgrep -x figcraft-server >/dev/null
                set -l pid (pgrep -x figcraft-server | head -1)
                set -l mem_kb (cat /proc/$pid/status 2>/dev/null | grep VmRSS | awk '{print $2}')
                set -l mem_mb (math --scale=1 "$mem_kb / 1024" 2>/dev/null; or echo "?")
                echo "🟢 FigCraft server is RUNNING"
                echo "   PID    : $pid"
                echo "   RAM    : $mem_mb MB"
                echo "   LAN    : http://$ip:47900"
                # Health check
                set -l health (curl -sf --max-time 2 http://127.0.0.1:47900/healthz 2>/dev/null; or echo "unreachable")
                echo "   Health : $health"
                # Tailscale
                if type -q tailscale
                    set -l ts_ip (tailscale ip -4 2>/dev/null)
                    test -n "$ts_ip"; and echo "   VPN    : http://$ts_ip:47900"
                end
                # Overall RAM pressure
                set -l available_mb (math (grep MemAvailable /proc/meminfo | awk '{print $2}') / 1024)
                echo "   Free RAM : ~$available_mb MB available"
            else
                echo "🔴 FigCraft server is STOPPED"
            end

        case ram
            # Show current RAM usage of server + system
            set -l available_mb (math (grep MemAvailable /proc/meminfo | awk '{print $2}') / 1024)
            set -l total_mb (math (grep MemTotal /proc/meminfo | awk '{print $2}') / 1024)
            set -l used_mb (math "$total_mb - $available_mb")
            echo "── System RAM ──────────────────────────────"
            echo "  Total     : $total_mb MB"
            echo "  Used      : $used_mb MB"
            echo "  Available : $available_mb MB"
            # zram
            set -l zram_used (zramctl 2>/dev/null | awk 'NR==2{print $4}')
            test -n "$zram_used"; and echo "  zram used : $zram_used (compressed swap)"
            echo "── figcraft-server ─────────────────────────"
            if pgrep -x figcraft-server >/dev/null
                set -l pid (pgrep -x figcraft-server | head -1)
                set -l mem_kb (cat /proc/$pid/status 2>/dev/null | grep VmRSS | awk '{print $2}')
                set -l mem_mb (math --scale=1 "$mem_kb / 1024" 2>/dev/null; or echo "?")
                set -l peak_kb (cat /proc/$pid/status 2>/dev/null | grep VmPeak | awk '{print $2}')
                set -l peak_mb (math --scale=1 "$peak_kb / 1024" 2>/dev/null; or echo "?")
                echo "  Current   : $mem_mb MB RSS"
                echo "  Peak      : $peak_mb MB"
                echo "  Cap       : 256 MB (OOM kills if exceeded)"
            else
                echo "  Not running"
            end

        case key
            $bin --data $data key $argv

        case files
            $bin --data $data files list

        case link
            set -l access edit
            test -n "$argv[1]"; and set access $argv[1]
            set -l id $argv[2]
            if test -z "$id"
                set id ($bin --data $data files list | string match -r -m1 '[0-9a-f]{16}')
            end
            if test -z "$id"
                echo "❌ No file found — publish one first (File ▸ Publish to server…)"
                return 1
            end
            # Prefer tailscale IP if available, fall back to LAN
            set -l host_ip (ip -4 route get 1.1.1.1 2>/dev/null | string match -r 'src (\S+)' | tail -n 1)
            if type -q tailscale
                set -l ts_ip (tailscale ip -4 2>/dev/null)
                test -n "$ts_ip"; and set host_ip $ts_ip
            end
            echo "🔗 Creating $access link (host: $host_ip:47900) ..."
            $bin --data $data links create $id --access $access

        case links
            set -l id $argv[1]
            if test -z "$id"
                set id ($bin --data $data files list | string match -r -m1 '[0-9a-f]{16}')
            end
            $bin --data $data links list $id

        case revoke
            # fig-server revoke FILE_ID LINK_ID
            $bin --data $data links revoke $argv[1] $argv[2]

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
                echo "❌ Data directory is not a git repo. Run the data-repo init steps first."
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
            if test -f $log_file
                tail -f $log_file
            else
                echo "No log file. Use 'fig-server start-bg' to create one."
            end

        case '*'
            echo ""
            echo "  fig-server — FigCraft collaboration server control"
            echo ""
            echo "  RUNNING"
            echo "    start              Foreground (Ctrl+C to stop)"
            echo "    start-bg           Background (256 MB RAM cap, logs to ~/figcraft/figcraft-server.log)"
            echo "    stop               Stop background server"
            echo "    status             Running? PID, RAM, LAN/VPN address, health"
            echo "    ram                Full RAM breakdown (server + system)"
            echo "    log                Tail the background log"
            echo ""
            echo "  SHARING"
            echo "    key                Print server key URL (for publishing)"
            echo "    files              List published files"
            echo "    link [edit|view] [FILE_ID]   Create a share link"
            echo "    links [FILE_ID]              List all links for a file"
            echo "    revoke FILE_ID LINK_ID       Revoke a link"
            echo ""
            echo "  BACKUP & SYNC"
            echo "    backup             Snapshot the data dir (stop server first)"
            echo "    push               Push data to GitHub (stop server first)"
            echo "    pull               Pull data from GitHub (stop server first)"
            echo ""
    end
end
