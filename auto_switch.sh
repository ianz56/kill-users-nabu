#!/system/bin/sh
# Kill Users on Switch — Auto Switch Daemon
# ============================================
# Background daemon that monitors screen state. When the screen is off
# and the current foreground user is NOT user 0, it waits for a
# configurable timeout and then auto-switches back to user 0.
# Combined with 'am set-stop-user-on-switch true', this effectively
# kills the secondary user automatically.
#
# This saves battery + RAM when you forget to switch back to your
# primary user before locking the screen.

MODDIR="${0%/*}"
LOGFILE="$MODDIR/auto_switch.log"

# ── Configuration ──────────────────────────────────────────────────
# Timeout in seconds before auto-switch (default: 5 minutes = 300s)
# You can change this value to suit your preference.
TIMEOUT=600

# How often to check screen state (in seconds)
POLL_INTERVAL=60
# ───────────────────────────────────────────────────────────────────

log() {
  # Keep log file from growing too large (max ~50KB)
  if [ -f "$LOGFILE" ] && [ "$(wc -c < "$LOGFILE" 2>/dev/null)" -gt 51200 ]; then
    tail -n 100 "$LOGFILE" > "$LOGFILE.tmp"
    mv "$LOGFILE.tmp" "$LOGFILE"
  fi
  echo "$(date '+%Y-%m-%d %H:%M:%S') | $1" >> "$LOGFILE"
}

get_screen_state() {
  # Returns: Awake, Asleep, or Dozing
  dumpsys power 2>/dev/null | grep 'mWakefulness=' | head -1 | sed 's/.*mWakefulness=//'
}

get_current_user() {
  am get-current-user 2>/dev/null
}

log "Auto-switch daemon started (timeout=${TIMEOUT}s, poll=${POLL_INTERVAL}s)"

# Track when the screen turned off while on a secondary user
SCREEN_OFF_TIMESTAMP=0
LAST_STATE="unknown"

while true; do
  sleep "$POLL_INTERVAL"

  SCREEN_STATE=$(get_screen_state)
  CURRENT_USER=$(get_current_user)

  # Skip if we can't determine state
  [ -z "$SCREEN_STATE" ] && continue
  [ -z "$CURRENT_USER" ] && continue

  if [ "$SCREEN_STATE" = "Asleep" ] || [ "$SCREEN_STATE" = "Dozing" ]; then
    # ── Screen is OFF ──
    if [ "$CURRENT_USER" != "0" ]; then
      NOW=$(date +%s)

      if [ "$SCREEN_OFF_TIMESTAMP" -eq 0 ]; then
        # Just detected screen off on secondary user — start timer
        SCREEN_OFF_TIMESTAMP=$NOW
        log "Screen off on user $CURRENT_USER — timer started (${TIMEOUT}s)"
      fi

      ELAPSED=$((NOW - SCREEN_OFF_TIMESTAMP))

      if [ "$ELAPSED" -ge "$TIMEOUT" ]; then
        log "Timeout reached (${ELAPSED}s) — switching to user 0..."
        SWITCH_RESULT=$(am switch-user 0 2>&1)
        log "am switch-user 0 → $SWITCH_RESULT"

        # Wait a moment then verify
        sleep 5
        NEW_USER=$(get_current_user)
        log "Current user is now: $NEW_USER"

        # Reset timer
        SCREEN_OFF_TIMESTAMP=0
      fi
    else
      # Screen is off but already on user 0 — no action needed
      SCREEN_OFF_TIMESTAMP=0
    fi
  else
    # ── Screen is ON ──
    if [ "$SCREEN_OFF_TIMESTAMP" -ne 0 ]; then
      log "Screen turned on — timer cancelled (was on user $CURRENT_USER)"
      SCREEN_OFF_TIMESTAMP=0
    fi
  fi
done
