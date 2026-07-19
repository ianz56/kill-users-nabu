#!/system/bin/sh
# Kill Users on Switch — Magisk Module
# ======================================
# This script runs at the 'late_start' service trigger on every boot.
# It waits until the system is fully booted, then enables the
# stop-user-on-switch setting so that background users are automatically
# stopped (killed) whenever you switch to a different user.
#
# Without this module you would have to run the command manually
# after every reboot:
#   am set-stop-user-on-switch true

MODDIR="${0%/*}"
LOGFILE="$MODDIR/service.log"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') | $1" >> "$LOGFILE"
}

# --- Wait for the system to finish booting ---
# The Activity Manager isn't available until boot completes, so we poll
# the 'sys.boot_completed' property before attempting our command.
log "Module started, waiting for boot to complete..."

MAX_WAIT=120   # seconds
WAITED=0
while [ "$(getprop sys.boot_completed)" != "1" ]; do
  sleep 2
  WAITED=$((WAITED + 2))
  if [ "$WAITED" -ge "$MAX_WAIT" ]; then
    log "ERROR: Timed out waiting for boot_completed after ${MAX_WAIT}s"
    exit 1
  fi
done

log "Boot completed after ~${WAITED}s — applying setting..."

# --- Apply the setting ---
RESULT=$(am set-stop-user-on-switch true 2>&1)
log "am set-stop-user-on-switch true → $RESULT"

# --- Enable GMS components if disabled ---
log "Enabling Google Services Framework and Play Services..."
pm enable com.google.android.gsf >> "$LOGFILE" 2>&1 &
pm enable com.google.android.gms >> "$LOGFILE" 2>&1 &



enforce_familylink_permissions() {
  log "Enforcing Family Link & Supervision permissions and AppOps for all users..."
  USERS=$(pm list users 2>/dev/null | grep 'UserInfo{' | sed -n 's/.*UserInfo{\([0-9]*\):.*/\1/p')
  [ -z "$USERS" ] && USERS="0 11"

  for u in $USERS; do
    for pkg in com.google.android.apps.kids.familylink com.google.android.apps.kids.familylinkhelper com.google.android.gms.supervision com.google.android.gms; do
      for perm in \
        android.permission.SYSTEM_ALERT_WINDOW \
        android.permission.PACKAGE_USAGE_STATS \
        android.permission.GET_USAGE_STATS \
        android.permission.SYSTEM_APPLICATION_OVERLAY \
        android.permission.SCHEDULE_EXACT_ALARM \
        android.permission.POST_NOTIFICATIONS \
        android.permission.GET_ACCOUNTS \
        android.permission.READ_CONTACTS \
        android.permission.WRITE_CONTACTS \
        android.permission.ACCESS_FINE_LOCATION \
        android.permission.ACCESS_COARSE_LOCATION \
        android.permission.READ_PHONE_STATE \
        android.permission.INTERACT_ACROSS_USERS \
        android.permission.MANAGE_USERS \
        android.permission.WRITE_SECURE_SETTINGS; do
          pm grant --user "$u" "$pkg" "$perm" >/dev/null 2>&1
      done

      appops set --user "$u" "$pkg" SYSTEM_ALERT_WINDOW allow >/dev/null 2>&1
      appops set --user "$u" "$pkg" GET_USAGE_STATS allow >/dev/null 2>&1
      appops set --user "$u" "$pkg" USE_FULL_SCREEN_INTENT allow >/dev/null 2>&1
      appops set --user "$u" "$pkg" ACCESS_RESTRICTED_SETTINGS allow >/dev/null 2>&1
      appops set --user "$u" "$pkg" 10008 allow >/dev/null 2>&1
      appops set --user "$u" "$pkg" 10021 allow >/dev/null 2>&1
      appops set --user "$u" "$pkg" 10022 allow >/dev/null 2>&1
      appops set --user "$u" "$pkg" 10033 allow >/dev/null 2>&1
    done
  done
  log "Permissions & AppOps enforcement complete."
}

# --- Apply permissions & AppOps ---
enforce_familylink_permissions &

# --- Verify ---
# Small delay to let the setting take effect, then log the user list
# so we can confirm everything looks right.
sleep 3
USERS=$(pm list users 2>&1)
log "Current users after setting applied:"
echo "$USERS" | while IFS= read -r line; do
  log "  $line"
done

log "Done ✓"

# --- Start auto-switch daemon ---
# Monitors screen state and auto-switches to user 0
# when screen is off for too long on a secondary user.
if [ -f "$MODDIR/auto_switch.sh" ]; then
  log "Starting auto-switch daemon..."
  sh "$MODDIR/auto_switch.sh" &
  log "Auto-switch daemon launched (PID: $!)"
fi
