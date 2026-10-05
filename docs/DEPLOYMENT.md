# Archlast Server Deployment Guide

## Docker & Coolify Deployment

Archlast can be packaged as a Docker container and deployed on platforms like Coolify, Railway, or any Docker-compatible host.

### Quick Start (Local Testing)

```bash
# Build the image
docker build -t archlast-server .

# Run with default config
docker run -d \
  --name archlast-server \
  -p 30000:30000/udp \
  -p 30000:30000/tcp \
  -v archlast-world:/home/archlast/.minetest/world \
  archlast-server
```

### Docker Compose (Local Development)

```bash
# Copy environment template
cp .env.example .env

# Edit .env with your settings
nano .env

# Start the server
docker compose up -d

# View logs
docker compose logs -f archlast-server
```

### Coolify Deployment

1. **Connect your repository** to Coolify (GitHub/GitLab)

2. **Configure the service:**
   - Service Type: `Docker Compose`
   - Repository: `your-repo/archlast-equileera`
   - Branch: `master` (or your target branch)

3. **Set environment variables** in Coolify's dashboard:
   ```
   SERVER_NAME=Your Server Name
   MAX_USERS=20
   GAME_ID=archlast
   ```

4. **Configure volumes:**
   - Ensure the `archlast-world` volume is persisted (Coolify handles this automatically for named volumes)

5. **Deploy** — Coolify will build from the `Dockerfile` and deploy using `docker-compose.yml`

### Configuration

Mount a custom `minetest.conf` to override defaults:

```conf
# minetest.conf
port = 30000
server_name = My Archlast Server
server_description = Custom Archlast Experience
max_users = 50
default_game = archlast
```

### Volume Structure

The container persists data at:
- `/home/archlast/.minetest/world` — World data, maps, player inventories
- `/home/archlast/minetest.conf` — Server configuration (mounted read-only)

### Health Checks

The container includes a health check that verifies the server is listening. In Coolify, configure:
- Health Check Path: N/A (UDP-based)
- Health Check Command: `grep -q "listening on" /home/archlast/.minetest/debug.txt`

### Troubleshooting

**Server won't start:**
- Check logs: `docker compose logs archlast-server`
- Verify game content exists: `ls game/arch_base/`
- Ensure port 30000 is not in use

**World not persisting:**
- Verify the volume mount: `docker volume inspect archlast-world`
- Check file permissions inside the container

**Game not loading:**
- Confirm `LUANTI_GAME_PATH` points to the correct game directory
- Check `debug.txt` for mod load errors