#!/bin/bash
set -e

STAMP_DIR="${HOME}/.pi/.ctfcont_installed"
PI_AGENT_DIR="${HOME}/.pi/agent"
mkdir -p "${STAMP_DIR}" "${PI_AGENT_DIR}"

# ── 1. Configure pi models.json (proxy base URL) ──────────────────────────────
MODELS_JSON="${PI_AGENT_DIR}/models.json"
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
else
    echo "[ctfcont] ANTHROPIC_BASE_URL not set — using default Anthropic endpoint"
fi

# ── 2. graphifyy setup ────────────────────────────────────────────────────────
if [ ! -f "${STAMP_DIR}/graphifyy" ]; then
    echo "[ctfcont] Running graphify install..."
    graphify install && touch "${STAMP_DIR}/graphifyy"
fi

# ── 3. Trail of Bits skills ───────────────────────────────────────────────────
TOB_DIR="${HOME}/.pi/trailofbits-skills"
if [ ! -f "${STAMP_DIR}/trailofbits_skills" ]; then
    echo "[ctfcont] Cloning Trail of Bits skills..."
    git clone --depth=1 https://github.com/trailofbits/skills.git "${TOB_DIR}" \
        && touch "${STAMP_DIR}/trailofbits_skills"
else
    git -C "${TOB_DIR}" pull --ff-only -q 2>/dev/null || true
fi

# Register trailofbits plugins dir in pi settings so skills are auto-discovered
PI_SETTINGS="${PI_AGENT_DIR}/settings.json"
if ! grep -q "trailofbits-skills" "${PI_SETTINGS}" 2>/dev/null; then
    echo "[ctfcont] Registering Trail of Bits skills in pi settings..."
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

print(f"[ctfcont] Registered: {tob_plugins}")
PYEOF
fi

# ── 4. Pi workspace context file ──────────────────────────────────────────────
AGENTS_MD="/output/AGENTS.md"
if [ ! -f "${AGENTS_MD}" ]; then
    cat > "${AGENTS_MD}" <<'EOF'
# ctfcont — workspace layout

## Directories
- `/src`    — the target source code. READ-ONLY. Never write here.
- `/output` — your writable scratch space. Write ALL output here:
              patches (.patch), diffs (.diff), findings (findings.md),
              scripts, notes, and any generated files.

## Workflow
- Analyse code from `/src`
- Save every finding, patch, and generated artifact to `/output`
- Use unified diff format (`diff -u`) for patches
- Name files descriptively: `vuln_overflow_main.patch`, `findings.md`, etc.
EOF
fi

echo "[ctfcont] Environment ready."
echo ""
echo "  /src    → target source (read-only)"
echo "  /output → findings, patches, diffs (writable)"
echo ""
echo "  Run: pi"
echo "  Tools: pi, gdb, strace, ltrace, r2, pwntools, semgrep, bandit, angr, afl++"
echo ""

exec "$@"
