#!/usr/bin/env bash
# Set up OpenJarvis (https://github.com/open-jarvis/OpenJarvis) on this machine.
# Tries the official one-line installer first, falls back to a manual clone +
# `uv sync` developer install if the installer host is unreachable.

set -euo pipefail

OPENJARVIS_REPO="https://github.com/open-jarvis/OpenJarvis.git"
INSTALL_URL="https://openjarvis.ai/install.sh"
TARGET_DIR="${OPENJARVIS_DIR:-$HOME/OpenJarvis}"

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

manual_install() {
    log "running manual developer install into $TARGET_DIR"
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

    log "manual install complete. Run jarvis with:"
    printf '    cd %s && uv run jarvis\n' "$TARGET_DIR"
}

main() {
    need curl
    if try_official_installer; then
        log "official installer finished. Try: jarvis"
    else
        warn "official installer unreachable, falling back to manual install"
        manual_install
    fi
}

main "$@"
