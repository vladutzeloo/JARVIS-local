# JARVIS-local

End-to-end local setup for [OpenJarvis](https://github.com/open-jarvis/OpenJarvis)
with [Ollama](https://ollama.com) and [Qwen2.5-Coder](https://ollama.com/library/qwen2.5-coder)
for local code assistance.

## Quick start

```bash
git clone <this-repo> JARVIS-local
cd JARVIS-local
./setup.sh
```

That runs:

1. **OpenJarvis** — official `openjarvis.ai/install.sh`, with a clone +
   `uv sync --extra dev` fallback if the host is blocked.
2. **Ollama** — installs if missing, ensures the daemon on `:11434` is up.
3. **Qwen2.5-Coder** — pulls **`qwen2.5-coder:14b`** (primary, best quality
   that fits on a 4070 Mobile with partial offload) and
   **`qwen2.5-coder:7b`** (fast fallback, fully GPU-resident).
4. **`jarvis init`** — generates `~/.openjarvis/config.toml` with the
   `code-assistant` preset wired to the `ollama` engine, then sets
   `intelligence.default_model` and `intelligence.fallback_model`.

When it finishes:

```bash
cd ~/OpenJarvis
uv run jarvis doctor
uv run jarvis ask "write a quicksort in python"
uv run jarvis chat
```

## Picking the right Qwen model for your GPU

| GPU VRAM | Recommended model     | Approx size (Q4_K_M) | Notes                                    |
|----------|-----------------------|----------------------|------------------------------------------|
| 6 GB     | `qwen2.5-coder:3b`    | ~2.0 GB              | Snappy, weaker reasoning.                |
| 8 GB     | `qwen2.5-coder:7b`    | ~4.7 GB              | **Default.** Good speed + quality.       |
| 12 GB    | `qwen2.5-coder:14b`   | ~9.0 GB              | Stronger; fits fully on GPU.             |
| 16+ GB   | `qwen2.5-coder:32b`   | ~20 GB               | Best in family; needs a desktop GPU.     |

**RTX 4070 Mobile (8 GB VRAM, 24 GB RAM):** the default setup pulls **both**
`qwen2.5-coder:14b` (primary, ~85% GPU + ~15% RAM offload, 15–25 tok/s,
strongest quality) and `qwen2.5-coder:7b` (fallback, 100% GPU,
50–80 tok/s). OpenJarvis will use 14B by default and fall back to 7B when
appropriate. To override:

```bash
OLLAMA_MODEL=qwen2.5-coder:7b OLLAMA_FALLBACK_MODEL="" ./setup.sh   # only fast 7B
OLLAMA_MODEL=qwen2.5-coder:32b ./setup.sh                            # max quality, slow
```

## Tunables

```bash
OPENJARVIS_DIR=~/code/OpenJarvis     ./setup.sh   # custom install dir
OLLAMA_MODEL=qwen2.5-coder:32b       ./setup.sh   # bigger primary
OLLAMA_FALLBACK_MODEL=""             ./setup.sh   # skip fallback pull
JARVIS_PRESET=chat-simple            ./setup.sh   # different preset
SKIP_OLLAMA=1                        ./setup.sh   # only OpenJarvis
SKIP_MODEL_PULL=1                    ./setup.sh   # skip the GB downloads
SKIP_INIT=1                          ./setup.sh   # don't write config
```

Available presets: `morning-digest-mac`, `morning-digest-linux`,
`morning-digest-minimal`, `deep-research`, `code-assistant` (default),
`scheduled-monitor`, `chat-simple`.

## Common commands

```bash
jarvis doctor                        # health check
jarvis quickstart                    # guided 5-step setup (alternative to init)
uv run jarvis ask "your query"       # one-shot
uv run jarvis chat                   # multi-turn
uv run jarvis model list             # models known to running engines
uv run jarvis model pull qwen2.5-coder:14b
uv run jarvis config show            # inspect ~/.openjarvis/config.toml
uv run jarvis config set engine.ollama.default_model qwen2.5-coder:14b
ollama ps                            # see what's loaded in VRAM
```

## Requirements

- Linux (incl. WSL2) or macOS. The script targets Linux for the daemon flow;
  on macOS Ollama runs as a desktop app.
- `curl`, `git`
- For NVIDIA: working proprietary driver (`nvidia-smi` should print your GPU).
  Ollama detects CUDA automatically — no extra config needed.
- ~10–15 GB free disk for OpenJarvis + a 7B model.

## Troubleshooting

- **Installer host blocked** — `setup.sh` automatically falls back to the
  manual `uv sync` install. No action needed.
- **`uv: command not found` after install** — open a new shell, or
  `source ~/.local/bin/env`.
- **Ollama daemon won't start / port 11434 busy** — `ss -ltnp | grep 11434`
  to see who's holding it; `systemctl status ollama` for the service.
  Logs from the script's fallback start are at `/tmp/ollama.log`.
- **Model is slow / partially on CPU** — `ollama ps` shows GPU vs CPU split.
  Drop to a smaller tag (e.g. `qwen2.5-coder:7b-instruct-q4_K_S`).
- **`jarvis doctor` shows engines unreachable** — that's fine for engines
  you don't use. Only `ollama` needs to be reachable.

## License

OpenJarvis itself is Apache 2.0. This repo (your local setup) — license as
you wish.
