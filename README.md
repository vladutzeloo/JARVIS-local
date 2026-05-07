# JARVIS-local

Local setup for [OpenJarvis](https://github.com/open-jarvis/OpenJarvis) — a
framework for running personal AI agents on personal devices.

## Quick start

```bash
git clone <this-repo> JARVIS-local
cd JARVIS-local
./setup.sh
```

`setup.sh` tries the official one-line installer first, and falls back to a
manual developer install (clone + `uv sync --extra dev`) if the installer
host is unreachable.

By default the manual install lands in `~/OpenJarvis`. Override with:

```bash
OPENJARVIS_DIR=/path/to/openjarvis ./setup.sh
```

## What gets installed

Per the upstream installer:

- [`uv`](https://docs.astral.sh/uv/) (Python package/venv manager)
- A Python virtual environment for OpenJarvis
- [Ollama](https://ollama.com/) and a starter local model

The manual fallback installs `uv` and the OpenJarvis Python deps, but **does
not** install Ollama. Install it separately if you need it:

```bash
curl -fsSL https://ollama.com/install.sh | sh
```

## Common commands

```bash
jarvis doctor                       # check system status
jarvis init --preset chat-simple    # initialize with a preset
uv run jarvis ask "your query"      # ask a question
uv run pytest tests/ -v             # run tests (manual install only)
```

Available presets: `morning-digest-mac`, `morning-digest-linux`,
`morning-digest-minimal`, `deep-research`, `code-assistant`,
`scheduled-monitor`, `chat-simple`.

## Requirements

- macOS (Intel/Apple Silicon), Linux, or WSL2 on Windows
- Python 3.10+
- `curl` and `git`

## Troubleshooting

- **`openjarvis.ai` blocked / 403** — your network blocks the installer host.
  `setup.sh` automatically falls back to the manual install path.
- **`uv: command not found` after install** — open a new shell, or
  `source ~/.local/bin/env`.
- **Ollama not running** — `ollama serve &` then retry.

## License

OpenJarvis itself is Apache 2.0. This repo is your local config/setup; license
as you see fit.
