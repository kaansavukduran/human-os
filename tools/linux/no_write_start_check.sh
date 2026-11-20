#!/usr/bin/env bash
# Start check for an encrypted (APP_ENV=staging) Linux build (D-049): start
# it with a fresh, empty XDG data folder, leave it alone for <seconds>
# without unlocking, stop it, and check that it was still running and that
# the data folder is exactly as it was (no file, no folder, no change).
# Such a build starts at the vault gate and writes nothing before the vault
# is created or unlocked (F006, D-016); this proves "alive and wrote
# nothing", not what was on screen. Run it inside xvfb-run.
# Usage: no_write_start_check.sh <seconds> -- <command...>
set -u
SECS=$1; shift 2
DATA_HOME=$(mktemp -d)
LOG=$(mktemp)
# Every path under the data folder with a checksum for each file.
listing() {
  (cd "$DATA_HOME" && find . -mindepth 1 -printf '%y %p\n' | LC_ALL=C sort \
    && find . -type f -exec sha256sum {} + | LC_ALL=C sort)
}
before=$(listing)
echo "# XDG_DATA_HOME is a fresh temporary folder; before start: ${before:-<empty>}"
XDG_DATA_HOME="$DATA_HOME" "$@" > "$LOG" 2>&1 &
pid=$!
sleep "$SECS"
rc=0
if kill -0 "$pid" 2>/dev/null; then
  echo "# alive after $SECS s without unlocking"
else
  wait "$pid"; echo "# FAIL: exited early with status $?"; rc=1
fi
kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null
after=$(listing)
echo "# after stop: ${after:-<empty>}"
echo "# app output (redacted [hhos] events only):"; cat "$LOG"
if [ "$before" != "$after" ]; then
  echo "# FAIL: something was written to the data folder before any unlock:"
  diff <(echo "$before") <(echo "$after")
  rc=1
fi
if grep -q '\[hhos\] startup_failed' "$LOG"; then
  echo "# FAIL: the app reported startup_failed"; rc=1
fi
echo "# result: $([ "$rc" = 0 ] && echo PASS || echo FAIL)"
rm -rf "$DATA_HOME" "$LOG"
exit "$rc"
