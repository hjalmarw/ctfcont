FROM node:22-slim

# ── System packages ──────────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y \
    # core
    git curl bash ca-certificates wget \
    # Python
    python3 python3-pip python3-venv pipx \
    # build tools (needed for many pip packages)
    build-essential gcc g++ make cmake \
    # binary analysis
    binutils file xxd \
    # debugging
    gdb ltrace strace \
    # fuzzing
    afl++ \
    # network / traffic
    nmap netcat-openbsd tcpdump \
    # misc reverse engineering
    hexedit \
    && rm -rf /var/lib/apt/lists/*

# ── Python analysis tools (system-wide) ──────────────────────────────────────
RUN pip3 install --break-system-packages \
    # code analysis
    semgrep \
    bandit \
    pylint \
    # binary / RE
    pwntools \
    ropper \
    capstone \
    keystone-engine \
    angr \
    # fuzzing
    atheris \
    # general utilities
    ipython \
    rich \
    graphifyy

# ── radare2 (binary analysis framework) ──────────────────────────────────────
RUN git clone --depth=1 https://github.com/radareorg/radare2 /tmp/radare2 \
    && /tmp/radare2/sys/install.sh \
    && rm -rf /tmp/radare2

# ── Pi coding agent ──────────────────────────────────────────────────────────
RUN npm install -g @mariozechner/pi-coding-agent

# ── Non-root user + mount point ownership ────────────────────────────────────
RUN useradd -m -s /bin/bash ctf \
    && mkdir -p /src /output \
    && chown ctf:ctf /src /output

# ── Bake AGENTS.md into pi's global auto-load path ───────────────────────────
RUN mkdir -p /home/ctf/.pi/agent && chown -R ctf:ctf /home/ctf/.pi
COPY --chown=ctf:ctf AGENTS.md /home/ctf/.pi/agent/AGENTS.md

# ── Entrypoint script ─────────────────────────────────────────────────────────
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /src

USER ctf

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/bin/bash"]
