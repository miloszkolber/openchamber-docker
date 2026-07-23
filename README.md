# openchamber-docker

An AMD64 container for running the [OpenChamber](https://openchamber.dev) web interface with a bundled, managed [OpenCode](https://opencode.ai) server.

The image uses OpenChamber's verified web release package and OpenCode's verified Alpine binary. It also includes Git, Docker CLI, and Docker Compose for coding and container workflows. Both applications' self-update mechanisms are disabled; GitHub Actions publishes a new image when either upstream project releases a stable version.

## Features

- Runs as UID/GID `1000:1000`.
- Stores OpenChamber, OpenCode, and Docker client state under `/home/data`.
- Serves OpenChamber on port `4098` by default.
- Starts the bundled OpenCode server on container loopback.
- Publishes AMD64 images with SBOM and provenance attestations.
- Provides Docker host access through the mounted Docker socket.

## Usage

```sh
cp example.env .env
mkdir -p data
chown 1000:1000 data
docker compose up -d
```

Open `http://localhost:4098`.

The sample Compose file uses host networking, the host PID namespace, privileged mode, and the Docker socket. The process remains UID 1000, but these settings provide extensive host access and are intended only for trusted workloads.

Add project or data mounts in a local Compose override as needed.

## Configuration

`docker-compose.yaml` loads `.env`. Start with `example.env`.

| Variable | Default | Description |
|---|---|---|
| `DATA_PATH` | `./data` | Host path mounted at `/home/data` |
| `DOCKER_GID` | `109` | Numeric group owning `/var/run/docker.sock` |
| `OPENCHAMBER_PORT` | `4098` | OpenChamber port with host networking |
| `OPENCHAMBER_UI_PASSWORD` | empty | Optional web interface password |
| `TZ` | `Europe/Warsaw` | Container timezone |

Set `DOCKER_GID` using `stat -c '%g' /var/run/docker.sock`.

## Images

```text
ghcr.io/miloszkolber/openchamber-docker:latest
ghcr.io/miloszkolber/openchamber-docker:<openchamber-version>_<opencode-version>
```

The OCI image version uses `<openchamber-version>+<opencode-version>`. Docker tags use `_` because `+` is not valid in a Docker tag.

This project is not affiliated with OpenChamber or OpenCode. Each upstream project retains its own license and trademarks.
