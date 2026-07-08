#!/bin/bash
set -eo pipefail

# Authenticate the docker sandbox used by ralph/afk.sh.
#
# Why this is needed:
#   The docker sandbox is an isolated Linux container. It does NOT mount the
#   host ~/.claude config, and on macOS your Claude Code credentials live in the
#   login Keychain (unreadable from inside the container). So a freshly created
#   sandbox is logged out ("Not logged in · Please run /login").
#
# What this does:
#   Copies the host's Claude Code OAuth credentials into the sandbox at
#   ~/.claude/.credentials.json, which Claude Code inside the container reads
#   directly. Run this once after every `docker sandbox rm`, then run afk.sh.
#
# Usage:
#   ./ralph/auth.sh          # authenticate the sandbox for this workspace
#   ./ralph/afk.sh 5         # then run the loop as usual

# afk.sh runs `docker sandbox run claude .`, which defaults the sandbox name to
# claude-<workdir-basename>. Match that exact name here.
SANDBOX="claude-$(basename "$PWD")"

# 1. Ensure the sandbox exists and is running (create leaves it running).
if docker sandbox ls 2>/dev/null | awk 'NR>1 {print $1}' | grep -qx "$SANDBOX"; then
  if ! docker sandbox exec "$SANDBOX" true >/dev/null 2>&1; then
    echo "Sandbox '$SANDBOX' exists but isn't running; recreating..."
    docker sandbox rm "$SANDBOX" >/dev/null 2>&1 || true
    docker sandbox create --name "$SANDBOX" claude . >/dev/null
  fi
else
  echo "Creating sandbox '$SANDBOX'..."
  docker sandbox create --name "$SANDBOX" claude . >/dev/null
fi

# 2. Pull the host's Claude Code OAuth credentials from the macOS Keychain.
creds=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null || true)
if [ -z "$creds" ]; then
  echo "ERROR: No 'Claude Code-credentials' found in the host Keychain." >&2
  echo "       Run 'claude' on the host and complete /login first, then retry." >&2
  exit 1
fi

# 3. Inject them into the sandbox.
printf '%s' "$creds" | docker sandbox exec -i "$SANDBOX" bash -c \
  'mkdir -p ~/.claude && cat > ~/.claude/.credentials.json && chmod 600 ~/.claude/.credentials.json'

echo "✓ Sandbox '$SANDBOX' authenticated. You can now run: ./ralph/afk.sh <iterations>"
