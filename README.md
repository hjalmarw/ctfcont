# ctfcont

portable pi harness. point it at code. get answers.

---

## setup

```
cp .env.example .env
$EDITOR .env
```

```
SOURCE_DIR=/path/to/target   # read-only inside container
OUTPUT_DIR=/path/to/output   # where findings land
ANTHROPIC_API_KEY=sk-ant-... # or proxy key
ANTHROPIC_BASE_URL=          # optional. proxy/custom endpoint
```

## build

```
docker build -t ctfcont:latest .
```

## run

```bash
# interactive pi session
./ctfcont

# one-shot — injects AGENTS.md as system prompt, prints and exits
./ctfcont "find me a vuln in this code"
./ctfcont "what crypto is being used and is it broken"
./ctfcont "look for hardcoded secrets or backdoors"
```

reads `.env` automatically. no args = interactive. args = one-shot.

## layout

```
/src     ro   target code. don't touch.
/output  rw   your diffs, patches, notes, findings.md
```

## tools

`pi` `gdb` `strace` `ltrace` `r2` `pwntools` `angr` `semgrep` `bandit` `afl++` `ropper` `capstone`

---

swap `SOURCE_DIR` per challenge. `OUTPUT_DIR` keeps your work. rebuild never required.
