#!/bin/bash
# Monitor NFS health and restart containers when it recovers

CHECK_INTERVAL=30
STATE_FILE="/tmp/nfs-state"

while true; do
    # Test if NFS is actually working (not just mounted)
    if timeout 2 ls /mnt/data/media >/dev/null 2>&1; then
        new_state="ok"
    else
        new_state="bad"
    fi
    
    old_state=$(cat "$STATE_FILE" 2>/dev/null || echo "unknown")
    echo "$new_state" > "$STATE_FILE"
    
    # If it just recovered, restart containers
    if [ "$old_state" = "bad" ] && [ "$new_state" = "ok" ]; then
        echo "[$(date)] NFS recovered - restarting media-stack"
        cd /home/kaf/docker/media-stack && docker compose restart
    fi
    
    sleep $CHECK_INTERVAL
done
