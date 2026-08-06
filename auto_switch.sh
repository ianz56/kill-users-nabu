#!/system/bin/sh
# Nabu CN System & Family Link Helper — Auto Switch Daemon
# =========================================================
# Background daemon that monitors screen state and foreground user
# changes. It aggressively re-applies a 60Hz refresh-rate lock for
# all users/current foreground user, and when the screen is off on a
# secondary user it waits for a configurable timeout and then auto-
# switches back to user 0.
# Combined with 'am set-stop-user-on-switch true', this effectively
# kills the secondary user automatically.
#
# This saves battery + RAM when you forget to switch back to your
# primary user before locking the screen.

MODDIR="${0%/*}"
LOGFILE="$MODDIR/auto_switch.log"

# ── Configuration ──────────────────────────────────────────────────
# Refresh rate to enforce.
REFRESH_RATE=60

# Native panel mode for Xiaomi Pad 5 / nabu.
# Used only as a best-effort display-service poke. If unsupported by
# the ROM, the command fails silently and settings-based locking remains.
DISPLAY_WIDTH=1600
DISPLAY_HEIGHT=2560

# Timeout in seconds before auto-switch (default: 10 minutes = 600s)
# You can change this value to suit your preference.
TIMEOUT=600

# How often to check screen state / active user (in seconds)
POLL_INTERVAL=10

# Re-apply the refresh lock periodically while the daemon is alive.
# This helps when MIUI/HyperOS rewrites refresh-rate state after user switch.
REFRESH_REAPPLY_INTERVAL=60
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

poke_display_mode() {
  # Best effort: ask Android DisplayManager to prefer the 60Hz native mode.
  # Not all ROMs expose this shell command, so failure is intentionally silent.
  if cmd display set-user-preferred-display-mode "$DISPLAY_WIDTH" "$DISPLAY_HEIGHT" "$REFRESH_RATE" >/dev/null 2>&1; then
    log "Display mode preference poked (${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}@${REFRESH_RATE})"
  fi
}

apply_global_refresh_lock() {
  # Some display state is cached globally by the framework/vendor service,
  # so write global keys too. Unknown keys are harmless on ROMs that ignore them.
  settings put global peak_refresh_rate "${REFRESH_RATE}.0" >/dev/null 2>&1
  settings put global min_refresh_rate "${REFRESH_RATE}.0" >/dev/null 2>&1
  settings put global user_refresh_rate "$REFRESH_RATE" >/dev/null 2>&1
  settings put global miui_refresh_rate "$REFRESH_RATE" >/dev/null 2>&1

  poke_display_mode
}

apply_refresh_lock() {
  USER_ID="$1"

  [ -z "$USER_ID" ] && return 1

  # AOSP-ish keys
  settings --user "$USER_ID" put system peak_refresh_rate "${REFRESH_RATE}.0" >/dev/null 2>&1
  settings --user "$USER_ID" put system min_refresh_rate "${REFRESH_RATE}.0" >/dev/null 2>&1
  settings --user "$USER_ID" put system user_refresh_rate "$REFRESH_RATE" >/dev/null 2>&1

  # MIUI/HyperOS-ish keys
  settings --user "$USER_ID" put system miui_refresh_rate "$REFRESH_RATE" >/dev/null 2>&1
  settings --user "$USER_ID" put secure user_refresh_rate "$REFRESH_RATE" >/dev/null 2>&1

  apply_global_refresh_lock

  PEAK_RATE=$(settings --user "$USER_ID" get system peak_refresh_rate 2>/dev/null)
  MIN_RATE=$(settings --user "$USER_ID" get system min_refresh_rate 2>/dev/null)
  USER_RATE=$(settings --user "$USER_ID" get system user_refresh_rate 2>/dev/null)
  MIUI_RATE=$(settings --user "$USER_ID" get system miui_refresh_rate 2>/dev/null)
  SECURE_USER_RATE=$(settings --user "$USER_ID" get secure user_refresh_rate 2>/dev/null)
  GLOBAL_PEAK=$(settings get global peak_refresh_rate 2>/dev/null)

  log "Refresh lock applied for user $USER_ID (peak=$PEAK_RATE, min=$MIN_RATE, user=$USER_RATE, miui=$MIUI_RATE, secure_user=$SECURE_USER_RATE, global_peak=$GLOBAL_PEAK)"
}

apply_refresh_all_users() {
  log "Applying refresh lock for all users..."

  pm list users 2>/dev/null | while IFS= read -r line; do
    case "$line" in
      *UserInfo*) ;;
      *) continue ;;
    esac

    USER_ID=$(echo "$line" | sed -n 's/.*UserInfo{\([0-9]*\):.*/\1/p')
    [ -n "$USER_ID" ] && apply_refresh_lock "$USER_ID"
  done
}

enforce_familylink_permissions() {
  USERS=$(pm list users 2>/dev/null | grep 'UserInfo{' | sed -n 's/.*UserInfo{\([0-9]*\):.*/\1/p')
  [ -z "$USERS" ] && USERS="0 11"

  # Whitelist services from Doze / Battery Optimization
  dumpsys deviceidle whitelist +com.google.android.gms.supervision >/dev/null 2>&1
  dumpsys deviceidle whitelist +com.google.android.apps.kids.familylinkhelper >/dev/null 2>&1
  dumpsys deviceidle whitelist +com.google.android.gms >/dev/null 2>&1
  dumpsys deviceidle whitelist +com.android.vending >/dev/null 2>&1
  dumpsys deviceidle whitelist +com.android.providers.downloads >/dev/null 2>&1
  dumpsys deviceidle whitelist +com.miui.packageinstaller >/dev/null 2>&1
  # Ensure DroidGuard and GSF checkin services are enabled
  pm enable com.google.android.gms/.droidguard.DroidGuardGmsService >/dev/null 2>&1
  pm enable com.google.android.gms/com.google.android.gms.droidguard.DroidGuardService >/dev/null 2>&1
  pm enable com.google.android.gms/com.google.android.gms.checkin.CheckinService >/dev/null 2>&1
  pm enable com.google.android.gsf >/dev/null 2>&1

  # Bypass Xiaomi installer captcha & account prompt settings
  settings put global miui_install_verify 0 >/dev/null 2>&1
  settings put secure miui_install_verify 0 >/dev/null 2>&1
  settings put system miui_install_verify 0 >/dev/null 2>&1
  settings put secure install_confirm_status 0 >/dev/null 2>&1
  settings put global install_verify_device_id 0 >/dev/null 2>&1
  settings put global install_silent 1 >/dev/null 2>&1
  settings put secure install_silent 1 >/dev/null 2>&1
  settings put global verify_market_app 0 >/dev/null 2>&1
  settings put global package_verifier_enable 0 >/dev/null 2>&1
  settings put global package_verifier_include_adb 0 >/dev/null 2>&1
  settings put global upload_apk_enable 0 >/dev/null 2>&1
  settings put secure upload_apk_enable 0 >/dev/null 2>&1
  setprop persist.sys.upload_apk_enable 0 >/dev/null 2>&1
  setprop persist.sys.package_verifier_enable 0 >/dev/null 2>&1

  # Enable Google Advertising ID & disable Xiaomi ad tracking limits
  settings put global limit_ad_tracking 0 >/dev/null 2>&1
  settings put secure limit_ad_tracking 0 >/dev/null 2>&1
  settings put global google_advertising_id_disabled 0 >/dev/null 2>&1
  settings put secure google_advertising_id_disabled 0 >/dev/null 2>&1

  for u in $USERS; do
    settings put --user "$u" global limit_ad_tracking 0 >/dev/null 2>&1
    settings put --user "$u" secure limit_ad_tracking 0 >/dev/null 2>&1
    settings put --user "$u" global google_advertising_id_disabled 0 >/dev/null 2>&1
    settings put --user "$u" secure google_advertising_id_disabled 0 >/dev/null 2>&1
  done

  # Generate persistent ad_id.xml for User 0 and User 11 if missing
  if [ -d "/data/data/com.google.android.gms" ]; then
    mkdir -p "/data/data/com.google.android.gms/shared_prefs" >/dev/null 2>&1
    if [ ! -f "/data/data/com.google.android.gms/shared_prefs/ad_id.xml" ]; then
      cat << 'EOF' > "/data/data/com.google.android.gms/shared_prefs/ad_id.xml"
<?xml version='1.0' encoding='utf-8' standalone='yes' ?>
<map>
    <string name="adid_key">e4d5f6a7-8b9c-4d1e-9f3a-4b5c6d7e8f9a</string>
    <boolean name="enable_limit_ad_tracking" value="false" />
    <boolean name="zero_advertising_id" value="false" />
    <boolean name="adid_settings_migrated" value="true" />
</map>
EOF
      uid_0=$(stat -c '%u:%g' /data/data/com.google.android.gms 2>/dev/null || echo "10028:10028")
      chmod 660 "/data/data/com.google.android.gms/shared_prefs/ad_id.xml" >/dev/null 2>&1
      chown $uid_0 "/data/data/com.google.android.gms/shared_prefs/ad_id.xml" >/dev/null 2>&1
    fi
  fi

  if [ -d "/data/user/11/com.google.android.gms" ]; then
    mkdir -p "/data/user/11/com.google.android.gms/shared_prefs" >/dev/null 2>&1
    if [ ! -f "/data/user/11/com.google.android.gms/shared_prefs/ad_id.xml" ]; then
      cat << 'EOF' > "/data/user/11/com.google.android.gms/shared_prefs/ad_id.xml"
<?xml version='1.0' encoding='utf-8' standalone='yes' ?>
<map>
    <string name="adid_key">e4d5f6a7-8b9c-4d1e-9f3a-4b5c6d7e8f9a</string>
    <boolean name="enable_limit_ad_tracking" value="false" />
    <boolean name="zero_advertising_id" value="false" />
    <boolean name="adid_settings_migrated" value="true" />
</map>
EOF
      uid_11=$(stat -c '%u:%g' /data/user/11/com.google.android.gms 2>/dev/null || echo "1110028:1110028")
      chmod 660 "/data/user/11/com.google.android.gms/shared_prefs/ad_id.xml" >/dev/null 2>&1
      chown $uid_11 "/data/user/11/com.google.android.gms/shared_prefs/ad_id.xml" >/dev/null 2>&1
    fi
  fi

  INSTALLER_PKGS="com.google.android.apps.kids.familylink com.google.android.apps.kids.familylinkhelper com.google.android.gms.supervision com.google.android.gms com.android.vending com.android.providers.downloads com.android.providers.downloads.ui com.miui.packageinstaller com.google.android.packageinstaller com.android.packageinstaller"

  for u in $USERS; do
    for pkg in $INSTALLER_PKGS; do
      if pm list packages --user "$u" 2>/dev/null | grep -q "$pkg"; then
        for perm in \
          android.permission.INSTALL_PACKAGES \
          android.permission.DELETE_PACKAGES \
          android.permission.REQUEST_INSTALL_PACKAGES \
          android.permission.UPDATE_PACKAGES_WITHOUT_USER_ACTION \
          android.permission.MANAGE_EXTERNAL_STORAGE; do
            pm grant --user "$u" "$pkg" "$perm" >/dev/null 2>&1
        done

        safe_appops_set() {
          u="$1"; pkg="$2"; op="$3"; mode="$4"
          curr=$(appops get --user "$u" "$pkg" "$op" 2>/dev/null)
          if ! echo "$curr" | grep -i -q "$mode"; then
            appops set --user "$u" "$pkg" "$op" "$mode" >/dev/null 2>&1
          fi
        }

        safe_appops_set "$u" "$pkg" SYSTEM_ALERT_WINDOW allow
        safe_appops_set "$u" "$pkg" GET_USAGE_STATS allow
        safe_appops_set "$u" "$pkg" WRITE_SETTINGS allow
        safe_appops_set "$u" "$pkg" USE_FULL_SCREEN_INTENT allow
        safe_appops_set "$u" "$pkg" SCHEDULE_EXACT_ALARM allow
        safe_appops_set "$u" "$pkg" 133 allow
        safe_appops_set "$u" "$pkg" RUN_IN_BACKGROUND allow
        safe_appops_set "$u" "$pkg" RUN_ANY_IN_BACKGROUND allow
        safe_appops_set "$u" "$pkg" START_FOREGROUND allow
        safe_appops_set "$u" "$pkg" FINE_LOCATION allow
        safe_appops_set "$u" "$pkg" COARSE_LOCATION allow
        safe_appops_set "$u" "$pkg" BLUETOOTH_ADVERTISE allow
        safe_appops_set "$u" "$pkg" BLUETOOTH_CONNECT allow
        safe_appops_set "$u" "$pkg" BLUETOOTH_SCAN allow
        safe_appops_set "$u" "$pkg" NEARBY_WIFI_DEVICES allow
        safe_appops_set "$u" "$pkg" USE_FULL_SCREEN_INTENT allow
        safe_appops_set "$u" "$pkg" ACCESS_RESTRICTED_SETTINGS allow
        safe_appops_set "$u" "$pkg" REQUEST_INSTALL_PACKAGES allow
        safe_appops_set "$u" "$pkg" MANAGE_EXTERNAL_STORAGE allow
        safe_appops_set "$u" "$pkg" WRITE_MEDIA_AUDIO allow
        safe_appops_set "$u" "$pkg" WRITE_MEDIA_VIDEO allow
        safe_appops_set "$u" "$pkg" WRITE_MEDIA_IMAGES allow
        safe_appops_set "$u" "$pkg" 66 allow
        safe_appops_set "$u" "$pkg" 92 allow
        safe_appops_set "$u" "$pkg" 98 allow
        safe_appops_set "$u" "$pkg" 99 allow
        safe_appops_set "$u" "$pkg" 100 allow
        safe_appops_set "$u" "$pkg" 10008 allow
        safe_appops_set "$u" "$pkg" 10021 allow
        safe_appops_set "$u" "$pkg" 10022 allow
        safe_appops_set "$u" "$pkg" 10033 allow
      fi
    done
  done
}

log "Auto-switch daemon started (refresh=${REFRESH_RATE}Hz, timeout=${TIMEOUT}s, poll=${POLL_INTERVAL}s, reapply=${REFRESH_REAPPLY_INTERVAL}s)"

# Initial pass: lock every user once after boot/module start.
apply_refresh_all_users
enforce_familylink_permissions

# Track when the screen turned off while on a secondary user
SCREEN_OFF_TIMESTAMP=0
LAST_USER=""
LAST_REFRESH_APPLY=$(date +%s)

while true; do
  SCREEN_STATE=$(get_screen_state)
  CURRENT_USER=$(get_current_user)
  NOW=$(date +%s)

  # Skip if we can't determine state
  if [ -z "$SCREEN_STATE" ] || [ -z "$CURRENT_USER" ]; then
    sleep "$POLL_INTERVAL"
    continue
  fi

  if [ "$CURRENT_USER" != "$LAST_USER" ]; then
    log "Foreground user changed to $CURRENT_USER — enforcing ${REFRESH_RATE}Hz and Family Link permissions"
    apply_refresh_lock "$CURRENT_USER"
    enforce_familylink_permissions
    LAST_USER="$CURRENT_USER"
    LAST_REFRESH_APPLY="$NOW"
    SCREEN_OFF_TIMESTAMP=0
  elif [ $((NOW - LAST_REFRESH_APPLY)) -ge "$REFRESH_REAPPLY_INTERVAL" ]; then
    log "Periodic refresh rate re-apply for user $CURRENT_USER"
    apply_refresh_lock "$CURRENT_USER"
    LAST_REFRESH_APPLY="$NOW"
  fi

  if [ "$SCREEN_STATE" = "Asleep" ] || [ "$SCREEN_STATE" = "Dozing" ]; then
    # ── Screen is OFF ──
    if [ "$CURRENT_USER" != "0" ]; then
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
        if [ "$NEW_USER" = "0" ]; then
          apply_refresh_lock "$NEW_USER"
          LAST_USER="$NEW_USER"
          LAST_REFRESH_APPLY=$(date +%s)
        fi

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

  sleep "$POLL_INTERVAL"
done
