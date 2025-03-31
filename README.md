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
