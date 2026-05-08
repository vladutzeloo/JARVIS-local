#!/usr/bin/env bash
# Prepare a fresh Ubuntu (incl. WSL2) for OpenJarvis + Ollama + Qwen.
#
# What it does:
#   1. apt update + install of build/runtime prerequisites.
#   2. WSL2 detection + GPU sanity check (nvidia-smi inside WSL).
#   3. Hands off to ./setup.sh (which installs OpenJarvis, Ollama, models).
#
# Designed for Ubuntu 22.04 / 24.04. Run from inside Ubuntu (not PowerShell).
#
#   git clone https://github.com/vladutzeloo/JARVIS-local.git
#   cd JARVIS-local
#   ./bootstrap-ubuntu.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log()  { printf '\033[1;34m[bootstrap]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m      %s\n' "$*"; }
err()  { printf '\033[1;31m[err]\033[0m       %s\n' "$*" >&2; }

SUDO=""
if [ "$(id -u)" != "0" ]; then
    if command -v sudo >/dev/null 2>&1; then
        SUDO="sudo"
    else
        err "not root and sudo not installed"
        exit 1
    fi
fi

if [ ! -f /etc/os-release ] || ! grep -qi 'ubuntu\|debian' /etc/os-release; then
    warn "this script targets Ubuntu/Debian; continuing anyway"
fi

log "apt-get update"
$SUDO apt-get update

log "installing prerequisites"
$SUDO DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    build-essential \
    pkg-config \
    python3 \
    python3-venv \
    jq \
    unzip

# WSL2 detection + GPU sanity
if grep -qi microsoft /proc/version 2>/dev/null; then
    log "WSL2 detected"
    if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then
        log "GPU visible inside WSL2:"
        nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader
    else
        warn "nvidia-smi not working inside WSL2."
        warn "Fix on the Windows side:"
        warn "  1. Install the latest NVIDIA Game Ready or Studio driver."
        warn "     https://www.nvidia.com/Download/index.aspx"
        warn "     The Windows driver provides /usr/lib/wsl/lib/libcuda.so to WSL."
        warn "     Do NOT install a CUDA toolkit inside Ubuntu."
        warn "  2. PowerShell (admin):  wsl --update  &&  wsl --shutdown"
        warn "  3. Reopen Ubuntu, re-run this script."
        warn "Continuing — Ollama will fall back to CPU (very slow for LLMs)."
    fi
else
    log "non-WSL Linux"
    if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then
        log "GPU detected:"
        nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader
    else
        warn "no NVIDIA GPU detected. Install the proprietary driver if you have one."
    fi
fi

if [ ! -f "$SCRIPT_DIR/setup.sh" ]; then
    err "setup.sh not found at $SCRIPT_DIR/setup.sh"
    exit 1
fi
chmod +x "$SCRIPT_DIR/setup.sh"

log "handing off to setup.sh"
exec "$SCRIPT_DIR/setup.sh" "$@"
