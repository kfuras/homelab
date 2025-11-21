# My Homelab Infrastructure

This repository contains the Docker Compose configurations for my homelab services, structured into logical stacks. Each stack runs in its own isolated Docker network and stores persistent data under `appdata/`.


## Stack Overview

| Stack             | Description                          |
|------------------|--------------------------------------|
| `management-stack` | Monitoring & uptime tools           |
| `media-stack`     | Media automation (Radarr, Plex, etc) |
| `unifi-stack`     | UniFi Controller + MongoDB           |

## Directory Structure

```bash
docker/
├── management-stack/
│   ├── appdata/
│   │   ├── grafana/
│   │   ├── prometheus/
│   │   └── uptime-kuma/
│   └── docker-compose.yml
├── media-stack/
│   ├── appdata/
│   │   ├── radarr/
│   │   ├── sonarr/
│   │   ├── plex/
│   │   └── ...
│   └── docker-compose.yml
└── unifi-stack/
    ├── appdata/
    │   ├── mongodb/
    │   └── unifi-network-application/
    └── docker-compose.yml
```

## How to Deploy

1. Clone the repo to your Docker host:

```bash
git clone git@github.com:kfuras/homelab.git ~/docker
```
2. Make sure required external Docker networks exist:

```bash
docker network create media-net
docker network create unifi-net
docker network create management-net
```
3. Set up .env files as needed (see `.env.example`).

4. Start a stack:

```bash
cd ~/docker/management-stack
docker compose up -d
```

## Monitoring (Management Stack)

| Service          | Port    |
|------------------|---------|
| Prometheus       | 9090    |
| Grafana	         | 3000    |
| Uptime Kuma      | 3001    |

Prometheus scrapes the following:

- Media stack: Radarr, Sonarr, Plex, qBittorrent, Unpackerr

- Unifi stack: Unifi Controller via exporter

- Management stack itself (Grafana, Kuma, cAdvisor)


## Reliable Unraid Share Mounting for docker-01

Ensuring Docker Starts Only After the Unraid Array Is Unlocked and Ready

This guide documents how to ensure docker-01 (running on Proxmox) waits for Unraid’s array to unlock and export its NFS/SMB shares before starting Docker and your containers.

This solves the classic problem:

> docker-01 boots before Unraid finishes unlocking the array → the share mounts empty → containers break.

**This method guarantees**

-	docker-01 never sees an empty mount
-	Docker never starts prematurely
-	No race conditions
-	Fully automatic recovery after reboots or Unraid downtime

**We accomplish this by**

1.	Removing the automatic mount from /etc/fstab
2.	Letting a custom systemd service mount the Unraid share
3.	Waiting for a sentinel file that confirms the array is ready
4.	Starting Docker only after everything is confirmed healthy

**This method works for both NFS and SMB.**

### 1. Add a Sentinel File on Unraid

This file indicates that the Unraid array is fully unlocked and mounted.

On Unraid:

```bash
touch /mnt/user/media/.unraid-ready
```

Replace media with your actual share name.

Remove Auto-Mount From /etc/fstab on docker-01

On docker-01:

```bash
sudo nano /etc/fstab
```

### 2. Comment out the Unraid share line:

```bash
# tower:/mnt/user/media  /mnt/data  nfs  defaults,_netdev,nofail  0  0
```

Or SMB:

```bash
# //tower/media  /mnt/data cifs credentials=/root/.smbcred,iocharset=utf8,vers=3.0,_netdev,nofail 0 0
```

This prevents the OS from mounting the share too early.

Make sure the mountpoint exists:

```bash
sudo mkdir -p /mnt/data
```

### 3. Install the wait-for-unraid.sh Script

Create:

```bash
sudo nano /usr/local/bin/wait-for-unraid.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

# CONFIGURE THESE
SERVER="10.160.0.21"                # Unraid IP or hostname
EXPORT="/mnt/user/media"            # Unraid export path
MOUNTPOINT="/mnt/data"              # Local mountpoint on docker-01
SENTINEL="$MOUNTPOINT/.unraid-ready" # Marker file from Unraid

# NFS mount command
MOUNT_CMD="mount -t nfs ${SERVER}:${EXPORT} ${MOUNTPOINT}"

log() {
  echo "[wait-for-unraid] $(date +'%F %T')] $*"
}

log "Starting. Will mount ${SERVER}:${EXPORT} at ${MOUNTPOINT} and wait for ${SENTINEL}"

while true; do
  # Attempt mount if not mounted
  if ! mountpoint -q "${MOUNTPOINT}"; then
    log "Mountpoint not mounted, attempting mount..."
    if ${MOUNT_CMD}; then
      log "Mount succeeded."
    else
      log "Mount failed, retrying in 5 seconds..."
      sleep 5
      continue
    fi
  fi

  # Mounted — now check if Unraid array is ready
  if [ -f "${SENTINEL}" ]; then
    log "Sentinel detected. Unraid array is ready."
    break
  else
    log "Mounted, but sentinel not found. Waiting..."
    sleep 5
  fi
done

log "Starting Docker..."
systemctl start docker || log "Failed to start Docker."

log "Done."
exit 0
```

Make it executable:
```bash

sudo chmod +x /usr/local/bin/wait-for-unraid.sh
```

### 4. Create systemd Service

```bash
sudo nano /etc/systemd/system/wait-for-unraid.service
```

Insert:

```bash
[Unit]
Description=Wait for Unraid share and then start Docker
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/wait-for-unraid.sh
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

Enable it:

```bash
sudo systemctl daemon-reload
sudo systemctl disable docker
sudo systemctl stop docker
sudo systemctl enable wait-for-unraid.service
```

### 5. Test It

Reboot:

```bash
sudo reboot
```

Watch logs:

```bash
journalctl -u wait-for-unraid.service -f
```
You should see:

	•	Attempts to mount the share
	•	Waiting on sentinel
	•	Sentinel detected
	•	Docker started

### Result

	•	docker-01 never boots broken again
	•	Docker starts only when the Unraid array is fully unlocked
	•	Containers always see the correct files
	•	Works even if Unraid is slow or doing parity checks
	•	Fully automatic — no manual steps required
