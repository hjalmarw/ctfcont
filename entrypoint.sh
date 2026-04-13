#!/bin/bash
set -e

PI_AGENT_DIR="${HOME}/.pi/agent"
STAMP_DIR="${HOME}/.pi/.ctfcont_installed"
mkdir -p "${STAMP_DIR}" "${PI_AGENT_DIR}"

# ── 0. Fix ownership of persistent volume dirs (first-run race) ───────────────
# Persistent volumes are created root-owned; stamp dir creation above handles
# ~/.pi, but ~/.claude may also be root-owned if volume was pre-created.
if [ -d "${HOME}/.claude" ] && [ ! -w "${HOME}/.claude" ]; then
    echo "[ctfcont] WARNING: ~/.claude is not writable — skipping graphify install"
    SKIP_GRAPHIFY=1
fi

# ── 1. Restore AGENTS.md (wiped by persistent volume mount over ~/.pi) ────────
AGENTS_MD="${PI_AGENT_DIR}/AGENTS.md"
if [ ! -f "${AGENTS_MD}" ]; then
    cat > "${AGENTS_MD}" <<'EOF'
# ctfcont — agent context

You are a specialist in code analysis and security research operating inside an isolated container.

## mission

Analyse the source code at `/src` and produce actionable findings. Look for:
- Logic flaws, authentication bypasses, injection points, memory safety issues
- Hidden flags, secrets, hardcoded credentials
- Obfuscation, custom encoding, or weak cryptography
- Architectural weaknesses

## rules

- `/src` is READ-ONLY. Never write here.
- All output goes to `/output`: patches as `.patch`, notes as `.md`, scripts as their natural extension.
- Name files descriptively: `vuln_fmt_string_handler.patch`, `findings.md`, `exploit_poc.py`.
- Document findings immediately in `/output/findings.md` with: location, class, severity, reproduction step.

## available tools

`gdb` `strace` `ltrace` `radare2 (r2)` `pwntools` `angr` `ropper` `capstone` `semgrep` `bandit` `afl++`

## workflow

1. Orient — language, entrypoints, attack surface
2. Triage — highest-risk areas first
3. Dig — go deep with dynamic tools where needed
4. Document — write to `/output/findings.md` as you go
5. Prove — working PoC or patch where possible
EOF
fi

# ── 2. Configure pi models.json (proxy base URL) ──────────────────────────────
if [ -n "${ANTHROPIC_BASE_URL}" ]; then
    echo "[ctfcont] Configuring pi Anthropic proxy -> ${ANTHROPIC_BASE_URL}"
    python3 - <<PYEOF
import json, os

models_path = os.path.expanduser("~/.pi/agent/models.json")
base_url    = os.environ["ANTHROPIC_BASE_URL"].rstrip("/")

try:
    with open(models_path) as f:
        cfg = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    cfg = {}

cfg.setdefault("providers", {})
cfg["providers"].setdefault("anthropic", {})
cfg["providers"]["anthropic"]["baseUrl"] = base_url

with open(models_path, "w") as f:
    json.dump(cfg, f, indent=2)
PYEOF
fi

# ── 3. graphifyy setup ────────────────────────────────────────────────────────
if [ "${SKIP_GRAPHIFY:-0}" = "0" ] && [ ! -f "${STAMP_DIR}/graphifyy" ]; then
    echo "[ctfcont] Running graphify install..."
    graphify install && touch "${STAMP_DIR}/graphifyy"
fi

# ── 4. Trail of Bits skills ───────────────────────────────────────────────────
TOB_DIR="${HOME}/.pi/trailofbits-skills"
if [ ! -f "${STAMP_DIR}/trailofbits_skills" ]; then
    echo "[ctfcont] Cloning Trail of Bits skills..."
    git clone --depth=1 https://github.com/trailofbits/skills.git "${TOB_DIR}" \
        && touch "${STAMP_DIR}/trailofbits_skills"
else
    git -C "${TOB_DIR}" pull --ff-only -q 2>/dev/null || true
fi

# Register trailofbits plugins dir in pi settings
PI_SETTINGS="${PI_AGENT_DIR}/settings.json"
if ! grep -q "trailofbits-skills" "${PI_SETTINGS}" 2>/dev/null; then
    python3 - <<PYEOF
import json, os

settings_path = os.path.expanduser("~/.pi/agent/settings.json")
tob_plugins   = os.path.expanduser("~/.pi/trailofbits-skills/plugins")

try:
    with open(settings_path) as f:
        cfg = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    cfg = {}

skills = cfg.get("skills", [])
if tob_plugins not in skills:
    skills.append(tob_plugins)
cfg["skills"] = skills

with open(settings_path, "w") as f:
    json.dump(cfg, f, indent=2)
PYEOF
fi

echo "[ctfcont] Environment ready."
echo ""
echo "  /src    → target source (read-only)"
echo "  /output → findings, patches, diffs (writable)"
echo "  Run: pi"
echo ""

exec "$@"
