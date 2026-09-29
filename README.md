# Home-Server

Bash scripts that turn a fresh Ubuntu machine into my home server. They set the
timezone, install Docker and Docker Compose, add common command-line tools,
install Cloudflare's `cloudflared` tunnel client, and can install the Prometheus
Node Exporter as a systemd service. There is also a `requirements.txt` with the
Python packages I use on the server.

The scripts are written for my own setup (Ubuntu, `Asia/Jerusalem` timezone).
Read them before you run them on your own machine.

## Table of contents

- [What's included](#whats-included)
- [Requirements](#requirements)
- [Usage](#usage)
- [What each script does](#what-each-script-does)
- [Python packages (`requirements.txt`)](#python-packages-requirementstxt)
- [Known issues and limitations](#known-issues-and-limitations)
- [Security notes](#security-notes)
- [Contributing](#contributing)
- [License](#license)

## What's included

| File | Purpose | Run by `install.sh`? |
|------|---------|----------------------|
| [`install.sh`](install.sh) | Main entry point. Sets the timezone, installs Docker and Docker Compose, then runs `dependencies.sh` and `cftunnel.sh` from GitHub. | – (entry point) |
| [`dependencies.sh`](dependencies.sh) | Installs `ffmpeg`, `zip`, `unzip`, `python3-pip` and `git`, and removes Python's `EXTERNALLY-MANAGED` marker. | Yes |
| [`cftunnel.sh`](cftunnel.sh) | Adds Cloudflare's APT repository and installs `cloudflared`. | Yes |
| [`docker.sh`](docker.sh) | Alternative Docker install from Docker's official APT repository (Engine, Buildx and Compose plugins). | No |
| [`exporter.sh`](exporter.sh) | Installs Prometheus Node Exporter v1.8.2 as a hardened systemd service on port 9100. | No |
| [`requirements.txt`](requirements.txt) | Unpinned list of Python packages. | No (not used by any script) |

## Requirements

- **OS:** Ubuntu with `apt`, `systemd` and `timedatectl`. `dependencies.sh` says it
  was tested on Ubuntu 20.04, 22.04 and 24.04. `docker.sh` uses Docker's Ubuntu
  repository only, so it will not work on Debian or other distributions.
- **Root:** every script except `exporter.sh` checks for root and exits if it is
  not run as root. `exporter.sh` has no check, but it still needs root.
- **Internet access** to GitHub, `get.docker.com`, `download.docker.com` and
  `pkg.cloudflare.com`.
- **`curl`** must already be installed to run `install.sh`, `cftunnel.sh` or
  `exporter.sh`
  (`docker.sh` installs it itself).
- **CPU architecture (`exporter.sh`):** `x86_64` (amd64), `aarch64` (arm64) or
  `armv7l` (armv7). Other architectures make the script exit with an error.
- **Cloudflare account and tunnel token:** needed to actually use `cloudflared`.
  The scripts install the client only; you connect the tunnel yourself (see
  [cftunnel.sh](#cftunnelsh)).

## Usage

The scripts are not marked executable in the repository, so run them with `bash`.

### Option 1: one-shot install (runs the scripts from GitHub)

`install.sh` downloads `dependencies.sh` and `cftunnel.sh` from the `main` branch
of this repository and pipes them to `bash`. You only need `install.sh` itself:

```bash
curl -fsSL https://raw.githubusercontent.com/t0mer/Home-Server/main/install.sh -o install.sh
less install.sh          # review it first
sudo bash install.sh
```

### Option 2: clone and run the scripts one by one

```bash
git clone https://github.com/t0mer/Home-Server.git
cd Home-Server

sudo bash dependencies.sh   # command-line tools and pip
sudo bash docker.sh         # Docker from the official APT repo (instead of get.docker.com)
sudo bash cftunnel.sh       # cloudflared
sudo bash exporter.sh       # Prometheus Node Exporter (optional)
```

Pick **one** Docker install method: either `install.sh` (which uses the
`get.docker.com` convenience script) or `docker.sh`. Both add the same Docker APT
repository, so running both is redundant but harmless (`docker.sh` overwrites
the same `docker.list` file).

### After installing

1. **Docker group:** if you ran `docker.sh` with `sudo`, log out and back in (or
   reboot) so your user can run `docker` without `sudo`. `install.sh` does not
   add any user to the `docker` group.
2. **Cloudflare tunnel:** create a tunnel in the Cloudflare Zero Trust dashboard
   and connect this host with the token it gives you, for example:
   ```bash
   sudo cloudflared service install <YOUR_TUNNEL_TOKEN>
   ```
   Never commit the token to this repository.
3. **Node Exporter:** check that metrics are served at
   `http://localhost:9100/metrics`, then add the host as a target in Prometheus.

### Optional: Python packages

`requirements.txt` is not installed by any script. To install it by hand:

```bash
pip3 install -r requirements.txt
```

See [Python packages](#python-packages-requirementstxt) before you do this.

## What each script does

### `install.sh`

1. Exits unless run as root.
2. Sets the system timezone to `Asia/Jerusalem` with `timedatectl`.
3. Installs Docker with the convenience script from `https://get.docker.com`
   (downloaded and piped to `sh`).
4. Downloads the latest standalone Docker Compose binary from
   `https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)`
   to `/usr/local/bin/docker-compose` and makes it executable. This gives you the
   `docker-compose` command in addition to the `docker compose` plugin that the
   Docker install script adds. On 32-bit ARM (`armv7l`) this download fails; see
   [Known issues](#known-issues-and-limitations).
5. Runs `dependencies.sh` and then `cftunnel.sh`, each fetched from
   `https://raw.githubusercontent.com/t0mer/Home-Server/main/` and piped to `bash`.

It does **not** run `docker.sh` or `exporter.sh`.

### `dependencies.sh`

1. Exits unless run as root.
2. Runs `apt-get update` and installs `ffmpeg`, `zip`, `unzip`, `python3-pip` and `git`.
3. Prints the version of each tool.
4. Deletes `/lib/python3.12/EXTERNALLY-MANAGED`. This turns off the
   [PEP 668](https://peps.python.org/pep-0668/) protection, so `pip` can install
   packages into the system Python without `--break-system-packages`. The path is
   specific to Python 3.12 (Ubuntu 24.04); on other versions nothing is removed.

### `docker.sh`

1. Exits unless run as root.
2. Installs `ca-certificates`, `curl`, `gnupg` and `lsb-release`.
3. Downloads Docker's GPG key from `https://download.docker.com/linux/ubuntu/gpg`
   into `/etc/apt/keyrings/docker.gpg`.
4. Adds the repository
   `https://download.docker.com/linux/ubuntu <codename> stable` to
   `/etc/apt/sources.list.d/docker.list`, for the host's architecture and Ubuntu
   codename.
5. Installs `docker-ce`, `docker-ce-cli`, `containerd.io`, `docker-buildx-plugin`
   and `docker-compose-plugin`.
6. Enables and starts the `docker` systemd service.
7. If run through `sudo` by a non-root user, creates the `docker` group (if
   missing) and adds that user (`$SUDO_USER`) to it.
8. Prints `docker --version` and `docker compose version`. It does not run the
   `hello-world` container.

### `cftunnel.sh`

1. Exits unless run as root.
2. Downloads Cloudflare's GPG key from
   `https://pkg.cloudflare.com/cloudflare-public-v2.gpg` into
   `/usr/share/keyrings/cloudflare-public-v2.gpg`.
3. Adds the repository `https://pkg.cloudflare.com/cloudflared any main` to
   `/etc/apt/sources.list.d/cloudflared.list`.
4. Installs the `cloudflared` package and prints its version.

It does not log in to Cloudflare, create a tunnel or install a `cloudflared`
service. You do that yourself with your own tunnel token (see
[After installing](#after-installing)).

### `exporter.sh`

1. Maps the CPU architecture (`uname -m`) to `amd64`, `arm64` or `armv7`, and
   exits on anything else.
2. Creates a system user `node_exporter` (no home directory, shell
   `/usr/sbin/nologin`) if it does not exist.
3. Downloads
   `https://github.com/prometheus/node_exporter/releases/download/v1.8.2/node_exporter-1.8.2.linux-<arch>.tar.gz`
   into `/tmp`, extracts it, and copies the binary to
   `/usr/local/bin/node_exporter`.
4. Writes `/etc/systemd/system/node_exporter.service`, which runs as the
   `node_exporter` user, always restarts 5 seconds after it exits, and uses the
   hardening options `NoNewPrivileges`, `ProtectSystem=strict`, `ProtectHome` and
   `PrivateTmp`.
5. Reloads systemd and enables and starts the service.

Node Exporter runs with its default settings, so it listens on **port 9100 on
all interfaces** and serves metrics at `/metrics`. To change the version, edit
`NODE_EXPORTER_VERSION` at the top of the script.

## Python packages (`requirements.txt`)

`requirements.txt` lists 171 Python packages, none with a pinned version.
They cover the kinds of tools I run on the server: web frameworks (FastAPI,
Flask, Quart, Uvicorn), messaging bots (Telegram, WhatsApp), MQTT, Prometheus
client libraries, speech and audio processing, machine learning (PyTorch,
Transformers, scikit-learn, Whisper), computer vision (OpenCV, DeepFace),
scraping (Selenium, BeautifulSoup) and development tools (pytest, black, flake8,
mypy).

No script installs this file. It is a reference list, not a tested environment.

## Known issues and limitations

These come from reading the scripts; none of them has been fixed here.

- **Two Docker install paths.** `install.sh` uses `get.docker.com` plus a
  standalone `docker-compose` binary, while `docker.sh` uses the APT repository
  and the Compose plugin. `docker.sh` is not called by `install.sh`.
- **`exporter.sh` is not part of `install.sh`** and must be run on its own.
- **`install.sh` does not add your user to the `docker` group**, so you need
  `sudo` for Docker commands unless you run `docker.sh` or add the group yourself.
- **Hard-coded timezone.** `install.sh` always sets `Asia/Jerusalem`. Its message
  says "UTC+2", but Israel also uses daylight saving time (UTC+3 in summer).
  Edit the script if you live elsewhere.
- **`install.sh` always runs the scripts from the `main` branch on GitHub**, not
  your local copy. Local edits to `dependencies.sh` or `cftunnel.sh` are ignored
  unless you run those scripts directly.
- **Unpinned versions.** Docker, Docker Compose (`latest`), `cloudflared` and
  every package in `requirements.txt` install whatever is newest at the time.
  Only Node Exporter is pinned (v1.8.2).
- **`dependencies.sh` only handles Python 3.12** when it removes
  `EXTERNALLY-MANAGED`. Other releases that ship the marker (for example with
  Python 3.11 or 3.13) keep PEP 668 enabled.
- **On 32-bit ARM the standalone `docker-compose` download fails silently and
  leaves a broken file.** `uname -m` returns `armv7l`, and the Compose release has
  no asset with that name, so the download returns a 404. Because `install.sh`
  uses `curl -L` without `-f`, the 404 response body is saved as
  `/usr/local/bin/docker-compose`.
- **`exporter.sh` has no root check** and uses `set -e` without `-u` or
  `pipefail`, unlike the other scripts. It leaves the downloaded archive and
  extracted folder in `/tmp`.
- **`exporter.sh` overrides the shell's `USER` variable** with `node_exporter`
  inside the script. This has no effect outside the script.
- **`requirements.txt` has conflicting and outdated entries.** It lists both
  `opencv-python` and `opencv-python-headless`, and includes packages that are no
  longer maintained (for example `deepspeech`, `youtube-dl` and `telepot`).
  `deepspeech` has no build for Python 3.10+, so installing the whole file fails
  on Ubuntu 24.04's Python 3.12.

## Security notes

- **Piping downloads into a shell.** `install.sh` runs `curl … | sh` for
  `get.docker.com` and `curl … | bash` for its own scripts. Whoever controls those
  URLs, or the `main` branch of this repository, can run any command as root on
  your machine. Download and read the scripts before running them.
- **Everything runs as root.** The scripts install packages, add APT
  repositories and signing keys, create users and write systemd units.
- **Node Exporter is exposed on the network.** It listens on port 9100 on all
  interfaces with no authentication, and its metrics reveal details about the
  host. Restrict the port with a firewall, or bind it to a local or private
  address.
- **Docker group access equals root.** Any user in the `docker` group can get
  root access to the host. Only add users you trust.
- **PEP 668 protection is removed.** After `dependencies.sh`, `pip` can
  overwrite Python packages that Ubuntu itself depends on. Prefer a virtual
  environment (`python3 -m venv`) for `requirements.txt`.
- **Keep secrets out of the repository.** The Cloudflare tunnel token and any
  other credentials belong on the server only, not in these scripts or in git.

## Contributing

This is a personal setup, but issues and pull requests are welcome. Please test
changes on a fresh Ubuntu machine or VM, and keep each script runnable on its own.

## License

This repository has no `LICENSE` file, so no license is granted. All rights
are reserved by the author unless a license is added.
