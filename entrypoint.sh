#!/bin/bash
set -e

STAMP_DIR="${HOME}/.claude/.ctfcont_installed"
mkdir -p "${STAMP_DIR}"

# ── 1. graphifyy setup ────────────────────────────────────────────────────────
if [ ! -f "${STAMP_DIR}/graphifyy" ]; then
    echo "[ctfcont] Running graphify install..."
    graphify install && touch "${STAMP_DIR}/graphifyy"
fi

# ── 2. wshobson reverse-engineering plugin ────────────────────────────────────
if [ ! -f "${STAMP_DIR}/wshobson_re" ]; then
    echo "[ctfcont] Installing wshobson reverse-engineering plugin..."
    npx claudepluginhub wshobson/agents --plugin reverse-engineering \
        && touch "${STAMP_DIR}/wshobson_re"
fi

# ── 3. Trail of Bits skills marketplace ──────────────────────────────────────
TOB_DIR="${HOME}/.claude/trailofbits-skills"
if [ ! -f "${STAMP_DIR}/trailofbits_skills" ]; then
    echo "[ctfcont] Cloning Trail of Bits skills..."
    git clone --depth=1 https://github.com/trailofbits/skills.git "${TOB_DIR}" \
        && touch "${STAMP_DIR}/trailofbits_skills"
else
    # Pull updates silently on subsequent starts
    git -C "${TOB_DIR}" pull --ff-only -q 2>/dev/null || true
fi

# Wire up the ToB marketplace in Claude settings if not already present
CLAUDE_SETTINGS="${HOME}/.claude/settings.json"
if [ ! -f "${CLAUDE_SETTINGS}" ]; then
    echo '{}' > "${CLAUDE_SETTINGS}"
fi

# Inject the marketplace path if missing (jq-free, safe append approach)
if ! grep -q "trailofbits-skills" "${CLAUDE_SETTINGS}" 2>/dev/null; then
    echo "[ctfcont] Registering Trail of Bits marketplace in Claude settings..."
    python3 - <<PYEOF
import json, os

settings_path = os.path.expanduser("~/.claude/settings.json")
with open(settings_path) as f:
    settings = json.load(f)

tob_path = os.path.expanduser("~/.claude/trailofbits-skills")

marketplaces = settings.get("pluginMarketplaces", [])
if tob_path not in marketplaces:
    marketplaces.append(tob_path)
settings["pluginMarketplaces"] = marketplaces

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2)

print("[ctfcont] Trail of Bits marketplace registered.")
PYEOF
fi

# ── 4. Write CLAUDE.md into /src so Claude knows the layout ──────────────────
# /src is read-only so we write it to /output and symlink, or just inject via
# the home-level CLAUDE.md which Claude always loads.
GLOBAL_CLAUDE_MD="${HOME}/.claude/CLAUDE.md"
cat > "${GLOBAL_CLAUDE_MD}" <<'EOF'
# ctfcont — workspace layout

## Directories
- `/src`    — the target source code. READ-ONLY. Never write here.
- `/output` — your writable scratch space. Write ALL output here:
              patches (.patch), diffs (.diff), findings (findings.md),
              scripts, notes, and any generated files.

## Workflow expectations
- Analyse code from `/src`
- Save every finding, patch, and generated artifact to `/output`
- Use unified diff format (`diff -u`) for patches when possible
- Name files descriptively: `vuln_overflow_main.patch`, `findings.md`, etc.
EOF

echo "[ctfcont] Environment ready."
echo ""
echo "  /src    → target source (read-only)"
echo "  /output → your findings, patches, diffs (writable)"
echo ""
echo "  Tools: claude, gdb, strace, ltrace, r2, pwntools, semgrep, bandit, angr, afl++"
echo ""

# Hand off to CMD (default: bash)
exec "$@"
