#!/system/bin/sh
# Nabu CN System & Family Link Helper — Magisk Module
# ===================================================
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

# --- Apply Play Integrity Spoofing for MEETS_DEVICE_INTEGRITY ---
resetprop -n ro.boot.verifiedbootstate green >/dev/null 2>&1
resetprop -n ro.boot.flash.locked 1 >/dev/null 2>&1
resetprop -n ro.boot.veritymode enforcing >/dev/null 2>&1
resetprop -n ro.boot.vbmeta.device_state locked >/dev/null 2>&1
resetprop -n ro.boot.warranty_bit 0 >/dev/null 2>&1
resetprop -n ro.warranty_bit 0 >/dev/null 2>&1
resetprop -n ro.is_ever_orange 0 >/dev/null 2>&1

# Dynamic Play Integrity Spoofing for Xiaomi Pad 5 (nabu) certified builds
PRODUCT_BRAND=$(getprop ro.product.brand 2>/dev/null || echo "Xiaomi")
PRODUCT_DEVICE=$(getprop ro.product.device 2>/dev/null || echo "nabu")

if [ "$PRODUCT_DEVICE" = "nabu" ]; then
  # Universal Xiaomi Pad 5 Global certified fingerprint spoofing for all nabu builds
  FINGERPRINT="Xiaomi/nabu_global/nabu:13/TKQ1.221114.001/V14.0.5.0.TKXMIXM:user/release-keys"
  resetprop -n ro.build.fingerprint "$FINGERPRINT" >/dev/null 2>&1
  resetprop -n ro.bootimage.build.fingerprint "$FINGERPRINT" >/dev/null 2>&1
  resetprop -n ro.vendor.build.fingerprint "$FINGERPRINT" >/dev/null 2>&1
  resetprop -n ro.product.build.fingerprint "$FINGERPRINT" >/dev/null 2>&1
  resetprop -n ro.odm.build.fingerprint "$FINGERPRINT" >/dev/null 2>&1
  resetprop -n ro.system.build.fingerprint "$FINGERPRINT" >/dev/null 2>&1
fi

# --- Enable GMS components if disabled ---
log "Enabling Google Services Framework and Play Services..."
pm enable com.google.android.gsf >> "$LOGFILE" 2>&1 &
pm enable com.google.android.gms >> "$LOGFILE" 2>&1 &



enforce_familylink_permissions() {
  log "Enforcing Family Link & Supervision permissions and AppOps for all users..."
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

        appops set --user "$u" "$pkg" SYSTEM_ALERT_WINDOW allow >/dev/null 2>&1
        appops set --user "$u" "$pkg" PACKAGE_USAGE_STATS allow >/dev/null 2>&1
        appops set --user "$u" "$pkg" WRITE_SETTINGS allow >/dev/null 2>&1
        appops set --user "$u" "$pkg" USE_FULL_SCREEN_INTENT allow >/dev/null 2>&1
        appops set --user "$u" "$pkg" SCHEDULE_EXACT_ALARM allow >/dev/null 2>&1
        appops set --user "$u" "$pkg" 133 allow >/dev/null 2>&1
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
