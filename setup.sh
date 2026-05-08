#!/usr/bin/env bash
# End-to-end setup for OpenJarvis (https://github.com/open-jarvis/OpenJarvis).
#
# What it does:
#   1. Installs OpenJarvis (tries official curl|bash; falls back to clone + uv sync).
#   2. Installs Ollama if missing and ensures the daemon is running.
#   3. Pulls a Qwen coding model into Ollama (default: qwen2.5-coder:7b).
#   4. Runs `jarvis init --preset code-assistant --engine ollama` non-interactively.
#
# Tunables (env vars):
#   OPENJARVIS_DIR     Where to put the OpenJarvis source (default: ~/OpenJarvis).
#   OLLAMA_MODEL       Model tag to pull (default: qwen2.5-coder:7b).
#                      For the 4070 Mobile (8 GB VRAM) try:
#                        qwen2.5-coder:7b      ~4.7 GB, fast, fully on GPU
#                        qwen2.5-coder:14b     ~9 GB, partial offload to RAM
#   JARVIS_PRESET      jarvis init preset (default: code-assistant).
#   SKIP_OLLAMA=1      Don't install/start Ollama or pull a model.
#   SKIP_MODEL_PULL=1  Don't pull the model (still installs Ollama).
#   SKIP_INIT=1        Don't run `jarvis init`.

set -euo pipefail

OPENJARVIS_REPO="https://github.com/open-jarvis/OpenJarvis.git"
INSTALL_URL="https://openjarvis.ai/install.sh"
TARGET_DIR="${OPENJARVIS_DIR:-$HOME/OpenJarvis}"
OLLAMA_MODEL="${OLLAMA_MODEL:-qwen2.5-coder:7b}"
JARVIS_PRESET="${JARVIS_PRESET:-code-assistant}"
SKIP_OLLAMA="${SKIP_OLLAMA:-0}"
SKIP_MODEL_PULL="${SKIP_MODEL_PULL:-0}"
SKIP_INIT="${SKIP_INIT:-0}"

log()  { printf '\033[1;34m[setup]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m  %s\n' "$*"; }
err()  { printf '\033[1;31m[err]\033[0m   %s\n' "$*" >&2; }

need() {
    command -v "$1" >/dev/null 2>&1 || { err "missing required tool: $1"; exit 1; }
}

ensure_uv() {
    if command -v uv >/dev/null 2>&1; then
        log "uv already installed: $(uv --version)"
        return
    fi
    log "installing uv"
    curl -fsSL https://astral.sh/uv/install.sh | sh
    # shellcheck disable=SC1091
    [ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"
    export PATH="$HOME/.local/bin:$PATH"
}

try_official_installer() {
    log "attempting official installer ($INSTALL_URL)"
    if curl -fsSL --max-time 15 "$INSTALL_URL" -o /tmp/openjarvis-install.sh; then
        bash /tmp/openjarvis-install.sh
        return 0
    fi
    return 1
}

manual_install_openjarvis() {
    log "manual developer install into $TARGET_DIR"
    need git
    ensure_uv

    if [ -d "$TARGET_DIR/.git" ]; then
        log "repo already present, pulling latest"
        git -C "$TARGET_DIR" pull --ff-only
    else
        git clone "$OPENJARVIS_REPO" "$TARGET_DIR"
    fi

    cd "$TARGET_DIR"
    log "uv sync --extra dev"
    uv sync --extra dev

    if [ -f .pre-commit-config.yaml ]; then
        uv run pre-commit install || warn "pre-commit install failed (non-fatal)"
    fi
}

install_openjarvis() {
    if try_official_installer; then
        log "official installer finished"
        # Official installer doesn't necessarily clone the source; ensure we
        # have a workspace with `uv` for jarvis CLI invocations below.
        if [ ! -d "$TARGET_DIR" ]; then
            manual_install_openjarvis
        fi
    else
        warn "official installer unreachable, falling back to manual install"
        manual_install_openjarvis
    fi
}

ensure_ollama() {
    if command -v ollama >/dev/null 2>&1; then
        log "ollama already installed: $(ollama --version 2>&1 | head -1)"
    else
        log "installing ollama"
        curl -fsSL https://ollama.com/install.sh | sh
    fi

    # Probe the API. If reachable, we're done. Otherwise, start a daemon.
    if curl -fsS --max-time 2 http://127.0.0.1:11434/api/version >/dev/null 2>&1; then
        log "ollama daemon already reachable"
        return
    fi

    if command -v systemctl >/dev/null 2>&1 && systemctl list-unit-files 2>/dev/null | grep -q '^ollama\.service'; then
        log "starting ollama systemd service"
        sudo systemctl enable --now ollama || warn "systemctl enable failed (continuing)"
    else
        log "starting ollama daemon in background (logs: /tmp/ollama.log)"
        nohup ollama serve >/tmp/ollama.log 2>&1 &
    fi

    log "waiting for ollama API on :11434"
    for _ in $(seq 1 30); do
        if curl -fsS --max-time 2 http://127.0.0.1:11434/api/version >/dev/null 2>&1; then
            log "ollama is up"
            return
        fi
        sleep 1
    done
    err "ollama did not become reachable within 30s — check /tmp/ollama.log"
    exit 1
}

pull_model() {
    log "pulling $OLLAMA_MODEL (this can take a few minutes)"
    ollama pull "$OLLAMA_MODEL"
    log "model ready:"
    ollama list | grep -E "NAME|$OLLAMA_MODEL" || true
}

init_jarvis() {
    log "running: jarvis init --preset $JARVIS_PRESET --engine ollama --force --no-download --no-scan"
    cd "$TARGET_DIR"
    uv run jarvis init \
        --preset "$JARVIS_PRESET" \
        --engine ollama \
        --force \
        --no-download \
        --no-scan

    # Point the default model at the one we pulled (the code-assistant preset
    # ships a placeholder tag that isn't on Ollama).
    uv run jarvis config set intelligence.default_model "$OLLAMA_MODEL" \
        || warn "could not set intelligence.default_model (jarvis may auto-route)"
}

gpu_hint() {
    if command -v nvidia-smi >/dev/null 2>&1; then
        log "nvidia-smi detected — Ollama will use CUDA automatically"
        nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>/dev/null || true
    else
        warn "nvidia-smi not found. If you have an NVIDIA GPU, install the proprietary driver first."
    fi
}

main() {
    need curl
    gpu_hint
    install_openjarvis

    if [ "$SKIP_OLLAMA" = "1" ]; then
        log "SKIP_OLLAMA=1, skipping Ollama setup"
    else
        ensure_ollama
        if [ "$SKIP_MODEL_PULL" = "1" ]; then
            log "SKIP_MODEL_PULL=1, skipping model download"
        else
            pull_model
        fi
    fi

    if [ "$SKIP_INIT" = "1" ]; then
        log "SKIP_INIT=1, skipping jarvis init"
    else
        init_jarvis
    fi

    cat <<EOF

[setup] all done.

  cd $TARGET_DIR
  uv run jarvis doctor                            # verify
  uv run jarvis ask "write a quicksort in python" # try it

Config: ~/.openjarvis/config.toml
Model:  $OLLAMA_MODEL (via Ollama on http://127.0.0.1:11434)
EOF
}

main "$@"
